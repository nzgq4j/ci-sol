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
    that the required groups exist, reports the ones that do not, and refuses to plan any grant onto
    a group it could not find - an unassignable grant is reported Blocked rather than attempted.
.PARAMETER Environment
    Environment key.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER Connection
    PnP connection to the DMS SITE. Omit for offline desired-state planning.
.PARAMETER TenantAdminConnection
    PnP connection to the SharePoint ADMIN endpoint (https://<tenant>-admin.sharepoint.com).
    Required only for tenant-scoped actions: setting the site sharing capability. Site-scoped
    connections cannot perform them, so the action is reported as Blocked rather than attempted
    and failing mid-run.
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
    [Parameter()]$TenantAdminConnection = $null,
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
# Enumerate the site's role definitions once and match by name, rather than probing each name and
# inferring absence from an exception. Probing made existence depend on CSOM error behaviour, which
# reported a level as present that had never been created - and a false Compliant is worse than a
# false Create here, because Apply skips the level and every grant that references it then fails.
$existingRoleNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($isOnline) {
    foreach ($rd in @(Get-PnPRoleDefinition -Connection $Connection)) {
        [void]$existingRoleNames.Add("$($rd.Name)")
    }
    Write-DmsLog -Action 'ReadRoleDefinitions' -Target $config.Environment.dmsSiteUrl -Result 'Info' `
        -Environment $Environment -CorrelationId $plan.correlationId `
        -Message "Site has $($existingRoleNames.Count) role definition(s): $((@($existingRoleNames) | Sort-Object) -join ', ')" | Out-Null
}

foreach ($level in $config.SecurityRoles.customPermissionLevels) {
    $existing = if ($isOnline -and $existingRoleNames.Contains($level.name)) { $level.name } else { $null }
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
            }.GetNewClosure() | Out-Null
    } else {
        # Only the NAME is compared. The permissions the level actually grants are not read back, so
        # a level created by an earlier or partial run could differ from configuration and still
        # report Compliant. Say so rather than implying the level was verified against config.
        Add-DmsPlanAction -Plan $plan -ResourceType 'PermissionLevel' -Target $level.name -Change 'Compliant' `
            -Reason "A role definition with this name exists. Name match only - the granted permissions were not compared against configuration. If this level may have been created by an earlier or partial run, remove it and re-apply so it is built from config." `
            -Requirements @('SEC-002') | Out-Null
    }
}

# ---------------------------------------------------------------- role groups (verify, never create)
# Group existence is read once here and kept, because the permission loop below needs it. Reading it
# and then discarding it was why a run against a tenant that has none of the governed groups planned
# every grant as Create and failed all of them at Apply with 'Group cannot be found' - the answer was
# already in hand one loop earlier.
$existingGroupNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$unprovisionedGroups = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($role in $config.SecurityRoles.roles) {
    $groupName = $role.groupNameTemplate -replace '\{prefix\}', $prefix
    if ((Get-DmsPropertyOrDefault -InputObject $role -Name 'status' -Default '') -like 'Not provisioned*') {
        [void]$unprovisionedGroups.Add($groupName)
        continue
    }
    $exists = $false
    if ($isOnline) { try { $null = Get-PnPGroup -Identity $groupName -Connection $Connection -ErrorAction Stop; $exists = $true } catch { $exists = $false } }
    if ($exists) { [void]$existingGroupNames.Add($groupName) }
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

        $permTarget = "$($container.title) : $groupName -> $($perm.level)"

        # A grant onto a group that is known not to exist is planned Blocked, not Create. Apply would
        # otherwise raise the identical 'Group cannot be found' once per grant and bury the single
        # actionable fact - that the governed groups have not been created yet - under dozens of
        # failures. Offline the groups cannot be read, so the grant stays a desired-state Create
        # rather than being reported as blocked on evidence that was never gathered.
        if ($unprovisionedGroups.Contains($groupName)) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'ListPermission' -Target $permTarget -Change 'Blocked' `
                -Reason "Role '$($role.key)' is not provisioned: $(Get-DmsPropertyOrDefault -InputObject $role -Name 'status' -Default 'no status recorded'). Its group is deliberately absent, so this grant is not assignable." `
                -Requirements @('F-024','SEC-002') | Out-Null
            continue
        }
        if ($isOnline -and -not $existingGroupNames.Contains($groupName)) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'ListPermission' -Target $permTarget -Change 'Blocked' `
                -Reason "Group '$groupName' does not exist on the site, so this grant cannot be assigned. Create and own it through the approved identity-governance process - see the RoleGroup action for '$groupName' - then re-run. Automatic creation is refused per PRD D-006 and R-07." `
                -Requirements @('F-024','SEC-002','D-006') | Out-Null
            continue
        }

        $capturedList = $container.title; $capturedGroup = $groupName; $capturedLevel = $perm.level
        Add-DmsPlanAction -Plan $plan -ResourceType 'ListPermission' -Target $permTarget -Change 'Create' `
            -Reason (Get-DmsPropertyOrDefault -InputObject $perm -Name 'note' -Default "Grant $($perm.level) to $groupName.") `
            -Requirements @('F-024','SEC-002') `
            -ApplyScript {
                Invoke-DmsWithRetry -OperationName "Set-PnPListPermission $capturedList" -ScriptBlock {
                    Set-PnPListPermission -Identity $capturedList -Group $capturedGroup -AddRole $capturedLevel -Connection $Connection
                } | Out-Null
            }.GetNewClosure() | Out-Null
    }
}

# ---------------------------------------------------------------- external sharing verification
$sharing = Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'externalSharing' -Default 'Disabled'
if ($sharing -ne 'Disabled') {
    Add-DmsPlanAction -Plan $plan -ResourceType 'ExternalSharing' -Target $config.Environment.dmsSiteUrl -Change 'Blocked' `
        -Reason "Configured external sharing is '$sharing'. PRD F-025 and SEC-005 require Disabled on MVP controlled sites unless Security, Privacy, Legal and the information owner approve a scoped, time-bounded exception (OQ-08)." `
        -Requirements @('F-025','SEC-005') | Out-Null
} elseif ($null -eq $TenantAdminConnection) {
    # Setting sharing capability is a TENANT-scoped operation. A site connection cannot perform it.
    # Report it rather than attempting a call that would fail partway through Apply.
    Add-DmsPlanAction -Plan $plan -ResourceType 'ExternalSharing' -Target $config.Environment.dmsSiteUrl -Change 'Blocked' `
        -Reason 'Setting the site sharing capability requires a SharePoint admin connection. Re-run with -TenantAdminConnection (connect to https://<tenant>-admin.sharepoint.com), or set sharing to Disabled in the SharePoint admin centre and re-run to verify.' `
        -Requirements @('F-025','SEC-005') | Out-Null
} else {
    $capturedUrl   = $config.Environment.dmsSiteUrl
    $capturedAdmin = $TenantAdminConnection
    Add-DmsPlanAction -Plan $plan -ResourceType 'ExternalSharing' -Target $capturedUrl -Change 'Create' `
        -Reason 'Set site sharing capability to Disabled.' -Requirements @('F-025','SEC-005') `
        -ApplyScript {
            Invoke-DmsWithRetry -OperationName 'Set-PnPTenantSite sharing' -ScriptBlock {
                Set-PnPTenantSite -Identity $capturedUrl -SharingCapability Disabled -Connection $capturedAdmin
            } | Out-Null
        }.GetNewClosure() | Out-Null
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
