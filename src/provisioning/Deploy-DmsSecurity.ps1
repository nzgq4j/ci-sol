#Requires -Version 7.2
<#
.SYNOPSIS
    Provisions DMS permission levels and role assignments, and reports permission exceptions.
.DESCRIPTION
    Implements PRD F-024, SEC-002 and SEC-003. Security boundaries are the site and the library;
    item-level unique permissions are treated as exceptions, not as a design tool (PRD C-006).

    Entra group CREATION is deliberately out of scope for this script. Group naming, ownership and
    membership source are a governance decision (PRD D-006) and creating groups automatically would
    produce ownerless groups, which is precisely the risk PRD R-07 describes. The script verifies
    that the required groups exist and reports the ones that do not.
.PARAMETER Environment
    Environment key.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER Connection
    PnP connection. Omit for offline desired-state planning.
.PARAMETER ConfigPath
    Configuration directory.
.EXAMPLE
    ./Deploy-DmsSecurity.ps1 -Environment dev -Mode Plan
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
$prefix   = Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'entraGroupPrefix' -Default 'DMS'

# ---------------------------------------------------------------- custom permission levels
foreach ($level in $config.SecurityRoles.customPermissionLevels) {
    $existing = $null
    if ($isOnline) { try { $existing = Get-PnPRoleDefinition -Identity $level.name -Connection $Connection -ErrorAction Stop } catch { $existing = $null } }
    $captured = $level
    if ($null -eq $existing) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'PermissionLevel' -Target $level.name -Change 'Create' `
            -Reason $(if ($isOnline) { 'Permission level does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements @('SEC-002','SEC-003') `
            -ApplyScript {
                $rp = @{ RoleName = $captured.name; Clone = $captured.basedOn; Description = (Get-DmsPropertyOrDefault -InputObject $captured -Name 'rationale' -Default $captured.name); Connection = $Connection }
                $add = @(Get-DmsPropertyOrDefault -InputObject $captured -Name 'addPermissions'    -Default @())
                $rem = @(Get-DmsPropertyOrDefault -InputObject $captured -Name 'removePermissions' -Default @())
                if ($add.Count -gt 0) { $rp['Include'] = $add }
                if ($rem.Count -gt 0) { $rp['Exclude'] = $rem }
                Invoke-DmsWithRetry -OperationName "Add-PnPRoleDefinition $($captured.name)" -ScriptBlock { Add-PnPRoleDefinition @rp } | Out-Null
            } | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'PermissionLevel' -Target $level.name -Change 'Compliant' -Reason 'Exists.' -Requirements @('SEC-002') | Out-Null
    }
}

# ---------------------------------------------------------------- role groups (verify, never create)
foreach ($role in @($config.SecurityRoles.roles | Where-Object { (Get-DmsPropertyOrDefault -InputObject $_ -Name 'status' -Default '') -notlike 'Not provisioned*' })) {
    $groupName = $role.groupNameTemplate -replace '\{prefix\}', $prefix
    $exists = $false
    if ($isOnline) { try { $null = Get-PnPGroup -Identity $groupName -Connection $Connection -ErrorAction Stop; $exists = $true } catch { $exists = $false } }
    if (-not $exists) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'RoleGroup' -Target $groupName -Change 'Blocked' `
            -Reason "Entra group '$groupName' must be created and owned through the approved identity-governance process before permissions can be assigned. Automatic creation is refused because group naming, ownership and membership source are a governance decision (PRD D-006) and auto-created groups become ownerless (PRD R-07)." `
            -Requirements @('F-024','SEC-002','D-006') | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'RoleGroup' -Target $groupName -Change 'Compliant' -Reason 'Group exists.' -Requirements @('F-024') | Out-Null
    }
}

# ---------------------------------------------------------------- library and list permissions
$containers = @($config.Libraries.libraries) + @($config.Lists.lists)
foreach ($role in $config.SecurityRoles.roles) {
    $groupName = $role.groupNameTemplate -replace '\{prefix\}', $prefix
    foreach ($perm in @(Get-DmsPropertyOrDefault -InputObject $role -Name 'permissions' -Default @())) {
        if ($perm.scope -eq 'Site' -or $perm.level -eq 'None') { continue }
        $container = $containers | Where-Object key -eq $perm.scope | Select-Object -First 1
        if (-not $container) { continue }
        if (Get-DmsPropertyOrDefault -InputObject $container -Name 'provisionWhen' -Default '') { continue }

        $capturedList = $container.title; $capturedGroup = $groupName; $capturedLevel = $perm.level
        Add-DmsPlanAction -Plan $plan -ResourceType 'ListPermission' -Target "$($container.title) : $groupName -> $($perm.level)" -Change 'Create' `
            -Reason (Get-DmsPropertyOrDefault -InputObject $perm -Name 'note' -Default "Grant $($perm.level) to $groupName.") `
            -Requirements @('F-024','SEC-002') `
            -ApplyScript {
                Invoke-DmsWithRetry -OperationName "Set-PnPListPermission $capturedList" -ScriptBlock {
                    Set-PnPListPermission -Identity $capturedList -Group $capturedGroup -AddRole $capturedLevel -Connection $Connection
                } | Out-Null
            } | Out-Null
    }
}

# ---------------------------------------------------------------- external sharing verification
$sharing = Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'externalSharing' -Default 'Disabled'
if ($sharing -ne 'Disabled') {
    Add-DmsPlanAction -Plan $plan -ResourceType 'ExternalSharing' -Target $config.Environment.dmsSiteUrl -Change 'Blocked' `
        -Reason "Configured external sharing is '$sharing'. PRD F-025 and SEC-005 require Disabled on MVP controlled sites unless Security, Privacy, Legal and the information owner approve a scoped, time-bounded exception (OQ-08)." `
        -Requirements @('F-025','SEC-005') | Out-Null
} else {
    $capturedUrl = $config.Environment.dmsSiteUrl
    Add-DmsPlanAction -Plan $plan -ResourceType 'ExternalSharing' -Target $capturedUrl -Change 'Create' `
        -Reason 'Set site sharing capability to Disabled.' -Requirements @('F-025','SEC-005') `
        -ApplyScript {
            Invoke-DmsWithRetry -OperationName 'Set-PnPTenantSite sharing' -ScriptBlock {
                Set-PnPTenantSite -Identity $capturedUrl -SharingCapability Disabled -Connection $Connection
            } | Out-Null
        } | Out-Null
}

$summary = Format-DmsPlan -Plan $plan
if ($Mode -eq 'Apply' -and -not $isOnline) {
    Write-DmsLog -Action 'DeploySecurity' -Target $Environment -Result 'Blocked' -Level Error -Message 'Apply requires a PnP connection.' | Out-Null
    $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue 3 -Force
    return $summary
}
if ($Mode -eq 'Apply') {
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
