#Requires -Version 7.2
<#
.SYNOPSIS
    Provisions the DMS managed-metadata term groups, term sets and terms.
.DESCRIPTION
    Implements PRD F-001 taxonomy. Must run BEFORE Deploy-DmsSharePoint.ps1, because the four
    taxonomy site columns cannot be created until their term sets exist: a taxonomy field bound to a
    missing term set silently accepts nothing.

    Terms are never deleted by this script. PRD section 17.3 requires deprecated terms to stay
    resolvable so historical items keep their values, so removal is a deliberate manual act.

    Idempotent: an existing group, set or term is reported Compliant and skipped.
.PARAMETER Environment
    Environment key.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER Connection
    PnP connection to the DMS site. Omit for offline desired-state planning.
.PARAMETER ConfigPath
    Configuration directory.
.EXAMPLE
    ./Deploy-DmsTaxonomy.ps1 -Environment dev -Mode Plan
.OUTPUTS
    PSCustomObject plan summary.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode,
    [Parameter()]$Connection = $null,
    [Parameter()][string]$ConfigPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }

$config   = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$plan     = New-DmsPlan -Environment $Environment -Mode $Mode
$isOnline = ($null -ne $Connection)
$groupName = $config.Taxonomy.termGroup

# ---------------------------------------------------------------- term group
$groupExists = $false
if ($isOnline) { try { $null = Get-PnPTermGroup -Identity $groupName -Connection $Connection -ErrorAction Stop; $groupExists = $true } catch { $groupExists = $false } }

if (-not $groupExists) {
    $capturedGroup = $groupName
    $capturedConn  = $Connection
    Add-DmsPlanAction -Plan $plan -ResourceType 'TermGroup' -Target $groupName -Change 'Create' `
        -Reason $(if ($isOnline) { 'Term group does not exist.' } else { 'Desired state (actual state not read).' }) `
        -Requirements @('F-001') `
        -ApplyScript {
            Invoke-DmsWithRetry -OperationName "New-PnPTermGroup $capturedGroup" -ScriptBlock {
                New-PnPTermGroup -Name $capturedGroup -Description 'Governed DMS taxonomy. Terms are deprecated, never deleted.' -Connection $capturedConn
            } | Out-Null
        }.GetNewClosure() | Out-Null
} else {
    Add-DmsPlanAction -Plan $plan -ResourceType 'TermGroup' -Target $groupName -Change 'Compliant' -Reason 'Exists.' -Requirements @('F-001') | Out-Null
}

# ---------------------------------------------------------------- term sets and terms
foreach ($ts in $config.Taxonomy.termSets) {
    $setExists = $false
    if ($isOnline) { try { $null = Get-PnPTermSet -Identity $ts.name -TermGroup $groupName -Connection $Connection -ErrorAction Stop; $setExists = $true } catch { $setExists = $false } }

    if (-not $setExists) {
        $capturedSet   = $ts
        $capturedGroup = $groupName
        $capturedConn  = $Connection
        Add-DmsPlanAction -Plan $plan -ResourceType 'TermSet' -Target $ts.name -Change 'Create' `
            -Reason $(if ($isOnline) { 'Term set does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements @('F-001') -Detail @{ isOpen = $ts.isOpen; termCount = @($ts.terms).Count } `
            -ApplyScript {
                Invoke-DmsWithRetry -OperationName "New-PnPTermSet $($capturedSet.name)" -ScriptBlock {
                    New-PnPTermSet -Name $capturedSet.name -TermGroup $capturedGroup `
                        -Description $capturedSet.description `
                        -IsOpenForTermCreation:([bool]$capturedSet.isOpen) -Connection $capturedConn
                } | Out-Null
            }.GetNewClosure() | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'TermSet' -Target $ts.name -Change 'Compliant' -Reason 'Exists.' -Requirements @('F-001') | Out-Null
    }

    foreach ($term in $ts.terms) {
        # A placeholder awaiting a stakeholder decision must not become a real term.
        if ("$($term.name)" -like '*REQUIRES_*') {
            Add-DmsPlanAction -Plan $plan -ResourceType 'Term' -Target "$($ts.name) / $($term.name)" -Change 'Blocked' `
                -Reason 'Term value is a placeholder pending a stakeholder decision (OQ-04). Creating it would put an unusable term into the governed vocabulary, and terms are deprecated rather than deleted.' `
                -Requirements @('F-001','OQ-04') | Out-Null
            continue
        }

        $capturedTerm  = $term
        $capturedSet2  = $ts
        $capturedGroup = $groupName
        $capturedConn  = $Connection
        Add-DmsPlanAction -Plan $plan -ResourceType 'Term' -Target "$($ts.name) / $($term.name)" -Change 'Create' `
            -Reason $(if ($isOnline) { 'Term does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements @('F-001') -Detail @{ children = @(Get-DmsPropertyOrDefault -InputObject $term -Name 'children' -Default @()).Count } `
            -ApplyScript {
                $created = Invoke-DmsWithRetry -OperationName "New-PnPTerm $($capturedTerm.name)" -ScriptBlock {
                    New-PnPTerm -Name $capturedTerm.name -TermSet $capturedSet2.name -TermGroup $capturedGroup -Connection $capturedConn
                }
                foreach ($child in @(Get-DmsPropertyOrDefault -InputObject $capturedTerm -Name 'children' -Default @())) {
                    $childName = $child
                    Invoke-DmsWithRetry -OperationName "Add-PnPTermToTerm $childName" -ScriptBlock {
                        Add-PnPTermToTerm -Name $childName -ParentTermId $created.Id -Connection $capturedConn
                    } | Out-Null
                }
            }.GetNewClosure() | Out-Null
    }
}

$summary = Format-DmsPlan -Plan $plan

if ($Mode -eq 'Apply') {
    if (-not $isOnline) {
        Write-DmsLog -Action 'DeployTaxonomy' -Target $Environment -Result 'Blocked' -Level Error -Message 'Apply requires a PnP connection.' | Out-Null
        $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue 3 -Force
        return $summary
    }
    $applied = 0; $failed = 0
    foreach ($a in @($plan.actions | Where-Object { $_.change -in @('Create','Update') })) {
        if ($null -eq $a.applyScript) { continue }
        if ($PSCmdlet.ShouldProcess("$($a.resourceType) $($a.target)", $a.change)) {
            try { & $a.applyScript; $a.outcome='Succeeded'; $applied++ }
            catch { $a.outcome='Failed'; $failed++; Write-DmsLog -Action "Apply$($a.resourceType)" -Target $a.target -Result 'Failed' -Level Error -Message $_.Exception.Message | Out-Null }
        }
    }
    $summary | Add-Member -NotePropertyName appliedCount -NotePropertyValue $applied -Force
    $summary | Add-Member -NotePropertyName failedCount  -NotePropertyValue $failed  -Force
    $summary | Add-Member -NotePropertyName exitCode     -NotePropertyValue $(if ($failed) { 1 } else { 0 }) -Force
} else {
    $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue $(if ($summary.hasBlocking) { 2 } else { 0 }) -Force
}
return $summary
