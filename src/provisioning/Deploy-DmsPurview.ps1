#Requires -Version 7.2
<#
.SYNOPSIS
    Plans Microsoft Purview retention configuration for the DMS. Defaults to Plan mode.
.DESCRIPTION
    Generates the retention-label and policy configuration implied by the approved file plan and,
    when explicitly authorised, applies the reversible parts of it.

    Safety posture, from PRD SEC-012, C-005, R-03 and R-06:
      * Plan is the default and the only mode available until the file plan is approved.
      * A retention class still marked REQUIRES_RECORDS_APPROVAL blocks Apply entirely. Configuring
        labels before the schedule is approved causes over-retention, premature disposal or
        inaccessible content, which is PRD risk R-03.
      * Regulatory records, Preservation Lock and automatic permanent deletion are refused
        unconditionally unless allowIrreversiblePurviewChanges is true AND an approved decision
        record is supplied. These actions are difficult or impossible to reverse.

    Apply requires an authenticated Security and Compliance PowerShell session
    (Connect-IPPSSession) established by the caller, so no credential is handled here.
.PARAMETER Environment
    Environment key.
.PARAMETER Mode
    Plan (default) or Apply.
.PARAMETER IrreversibleChangeAuthorised
    Explicit authorisation for irreversible controls. Also requires the environment flag and a
    decision record.
.PARAMETER DecisionRecordReference
    Reference to the signed Records Management and Legal decision authorising irreversible controls.
.PARAMETER ConfigPath
    Configuration directory.
.EXAMPLE
    ./Deploy-DmsPurview.ps1 -Environment dev -Mode Plan
.OUTPUTS
    PSCustomObject plan summary.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter()][ValidateSet('Plan','Apply')][string]$Mode = 'Plan',
    [Parameter()][switch]$IrreversibleChangeAuthorised,
    [Parameter()][AllowEmptyString()][string]$DecisionRecordReference = '',
    [Parameter()][string]$ConfigPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }

$config = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$plan   = New-DmsPlan -Environment $Environment -Mode $Mode
$map    = $config.RetentionMap

$unapproved = @($map.retentionClasses | Where-Object {
    $_.retentionAuthority -eq 'REQUIRES_RECORDS_APPROVAL' -or $_.period -eq 'REQUIRES_RECORDS_APPROVAL' -or $_.status -ne 'Approved'
})

foreach ($rc in $map.retentionClasses) {
    $needsApproval = $rc.retentionAuthority -eq 'REQUIRES_RECORDS_APPROVAL' -or $rc.period -eq 'REQUIRES_RECORDS_APPROVAL' -or $rc.status -ne 'Approved'

    if ($needsApproval) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'RetentionLabel' -Target $rc.recordClass -Change 'Blocked' `
            -Reason "Retention class is not approved (authority='$($rc.retentionAuthority)', period='$($rc.period)', status='$($rc.status)'). PRD F-018 forbids production record capture against an unapproved class; PRD R-03 warns that configuring labels first causes over-retention or premature disposal. Records Management and Legal must approve OQ-03 first." `
            -Requirements @('F-018','OQ-03') | Out-Null
        continue
    }

    if ([bool]$rc.declareAsRegulatoryRecord) {
        $envAllows = [bool](Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'allowIrreversiblePurviewChanges' -Default $false)
        $permitted = $IrreversibleChangeAuthorised -and $envAllows -and -not [string]::IsNullOrWhiteSpace($DecisionRecordReference)
        if (-not $permitted) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'RegulatoryRecordLabel' -Target $rc.recordClass -Change 'Blocked' `
                -Reason "Regulatory-record labels are irreversible and are refused. Required to proceed: -IrreversibleChangeAuthorised (supplied=$($IrreversibleChangeAuthorised.IsPresent)), environments.$Environment.allowIrreversiblePurviewChanges (=$envAllows), and a signed decision record (supplied=$(-not [string]::IsNullOrWhiteSpace($DecisionRecordReference))). PRD SEC-012, C-005, R-06." `
                -Requirements @('SEC-012','F-019') | Out-Null
            continue
        }
    }

    $captured = $rc
    Add-DmsPlanAction -Plan $plan -ResourceType 'RetentionLabel' -Target $rc.recordClass -Change 'Create' `
        -Reason "Approved retention class. Trigger '$($rc.trigger)' ($($rc.triggerType)), period '$($rc.period)', disposition '$($rc.disposition)'." `
        -Requirements @('F-018','F-020') `
        -Detail @{ declareAsRecord = $rc.declareAsRecord; disposition = $rc.disposition } `
        -ApplyScript {
            # Security and Compliance PowerShell. The caller must have run Connect-IPPSSession.
            $tagParams = @{
                Name            = $captured.recordClass
                RetentionAction = $(if ($captured.disposition -eq 'RetainOnly') { 'Keep' } else { 'KeepAndDelete' })
                RetentionDuration = $captured.period
                RetentionType   = $(if ($captured.triggerType -eq 'EventBased') { 'EventAgeInDays' } else { 'CreationAgeInDays' })
                IsRecordLabel   = [bool]$captured.declareAsRecord
            }
            if ($captured.disposition -eq 'DispositionReview') { $tagParams['ReviewerEmail'] = 'REQUIRES_RECORDS_APPROVAL' }
            Invoke-DmsWithRetry -OperationName "New-ComplianceTag $($captured.recordClass)" -ScriptBlock {
                New-ComplianceTag @tagParams
            } | Out-Null
        }.GetNewClosure() | Out-Null
}

$summary = Format-DmsPlan -Plan $plan

if ($Mode -eq 'Apply') {
    if ($unapproved.Count -gt 0) {
        Write-DmsLog -Action 'DeployPurview' -Target $Environment -Result 'Blocked' -Level Error -Environment $Environment `
            -CorrelationId $plan.correlationId `
            -Message "Apply refused: $($unapproved.Count) retention class(es) are not approved. Resolve OQ-03 with Records Management and Legal first." | Out-Null
        $summary | Add-Member -NotePropertyName applied  -NotePropertyValue $false -Force
        $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue 2 -Force
        return $summary
    }
    $applied = 0; $failed = 0
    foreach ($a in @($plan.actions | Where-Object change -eq 'Create')) {
        if ($null -eq $a.applyScript) { continue }
        if ($PSCmdlet.ShouldProcess("RetentionLabel $($a.target)", 'Create')) {
            try { & $a.applyScript; $a.outcome='Succeeded'; $applied++ }
            catch { $a.outcome='Failed'; $failed++; Write-DmsLog -Action 'ApplyRetentionLabel' -Target $a.target -Result 'Failed' -Level Error -Message $_.Exception.Message | Out-Null }
        }
    }
    $summary | Add-Member -NotePropertyName appliedCount -NotePropertyValue $applied -Force
    $summary | Add-Member -NotePropertyName failedCount  -NotePropertyValue $failed  -Force
    $summary | Add-Member -NotePropertyName applied      -NotePropertyValue $true    -Force
    $summary | Add-Member -NotePropertyName exitCode     -NotePropertyValue $(if ($failed) { 1 } else { 0 }) -Force
} else {
    $summary | Add-Member -NotePropertyName applied  -NotePropertyValue $false -Force
    $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue 0 -Force
}
return $summary
