#Requires -Version 7.2
<#
.SYNOPSIS
    Orchestrates DMS deployment across all layers with production safeguards.
.DESCRIPTION
    The single entry point. Runs validation, then the SharePoint, security, Purview and Power
    Platform layers in dependency order, enforcing the production-protection gate before any
    production change.

    Plan mode shows intended changes without applying them. Apply mode validates prerequisites,
    confirms the environment, logs each action, skips compliant resources, updates safe differences,
    reports unsafe ones, stops safely on failed preconditions and produces a deployment summary.

    Exit codes:
      0  success, or a plan with no blocking issues
      1  one or more apply actions failed
      2  blocking issues prevent deployment (unapproved retention, missing groups, guard failure)
      3  prerequisites missing (no connection supplied for Apply)
      4  configuration validation failed
.PARAMETER Environment
    Target environment.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER Layer
    Which layers to run. Defaults to all.
.PARAMETER Connection
    PnP connection to the DMS site, used by the SharePoint and security layers.
.PARAMETER TenantAdminConnection
    Optional PnP connection to the SharePoint admin endpoint. Needed only for tenant-scoped actions
    such as setting the site sharing capability.
.PARAMETER ConfirmProductionChange
    Explicit authorisation for a production Apply. Required in addition to the environment flag.
.PARAMETER RollbackPlanReference
    Reference to the documented rollback plan. Required for a production Apply.
.PARAMETER PriorSuccessfulDeployment
    Environments with a recorded successful deployment. Required for a production Apply.
.PARAMETER LogPath
    JSON Lines log file.
.EXAMPLE
    ./Deploy-Dms.ps1 -Environment dev -Mode Plan
.EXAMPLE
    ./Deploy-Dms.ps1 -Environment dev -Mode Apply -Connection $c
.OUTPUTS
    PSCustomObject deployment summary.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode,
    [Parameter()][ValidateSet('All','SharePoint','Security','Purview','PowerPlatform')][string[]]$Layer = @('All'),
    [Parameter()]$Connection = $null,
    [Parameter()]$TenantAdminConnection = $null,
    [Parameter()][switch]$ConfirmProductionChange,
    [Parameter()][AllowEmptyString()][string]$RollbackPlanReference = '',
    [Parameter()][string[]]$PriorSuccessfulDeployment = @(),
    [Parameter()][string]$LogPath = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force

$correlationId = New-DmsCorrelationId
$configPath = Join-Path $PSScriptRoot '..' '..' 'config'
$config = Get-DmsConfiguration -ConfigPath $configPath -Environment $Environment

Write-Information "" -InformationAction Continue
Write-Information "=== DMS deployment ===============================================================" -InformationAction Continue
Write-Information ("environment   : {0}" -f $Environment) -InformationAction Continue
Write-Information ("mode          : {0}" -f $Mode) -InformationAction Continue
Write-Information ("site          : {0}" -f $config.Environment.dmsSiteUrl) -InformationAction Continue
Write-Information ("layers        : {0}" -f ($Layer -join ', ')) -InformationAction Continue
Write-Information ("correlation   : {0}" -f $correlationId) -InformationAction Continue
Write-Information ("connected     : {0}" -f ($null -ne $Connection)) -InformationAction Continue
Write-Information "==================================================================================" -InformationAction Continue

# ---------------------------------------------------------------- 1. validate before anything else
$validation = Test-DmsConfiguration -Configuration $config
if (-not $validation.IsValid) {
    foreach ($f in $validation.Failures) { Write-DmsLog -Action 'Validate' -Target 'configuration' -Result 'Failed' -Level Error -Environment $Environment -CorrelationId $correlationId -LogPath $LogPath -Message $f | Out-Null }
    Write-Information "Deployment stopped: configuration validation failed." -InformationAction Continue
    return [PSCustomObject]@{ environment=$Environment; mode=$Mode; correlationId=$correlationId; validationPassed=$false; exitCode=4 }
}
foreach ($w in $validation.Warnings) { Write-Warning $w }

if ($config.IsExample -and $Mode -eq 'Apply') {
    Write-DmsLog -Action 'Validate' -Target 'configuration' -Result 'Blocked' -Level Error -Environment $Environment -CorrelationId $correlationId -LogPath $LogPath `
        -Message 'Apply is refused against example configuration. Copy config/environments.example.json to config/environments.json and complete discovery first.' | Out-Null
    return [PSCustomObject]@{ environment=$Environment; mode=$Mode; correlationId=$correlationId; validationPassed=$true; exitCode=2 }
}

# ---------------------------------------------------------------- 2. production guard
$guard = Test-DmsProductionGuard -Environment $Environment -EnvironmentConfig $config.Environment -TenantConfig $config.Tenant `
    -Mode $Mode -ProductionChangeAuthorised:$ConfirmProductionChange `
    -PriorSuccessfulDeploymentEnvironment $PriorSuccessfulDeployment `
    -PreDeploymentTestsPassed $validation.IsValid -RollbackPlanReference $RollbackPlanReference -ChangeDisplayed:$true

if (-not $guard.IsPermitted) {
    Write-Information "" -InformationAction Continue
    Write-Information "Deployment BLOCKED by the production guard:" -InformationAction Continue
    foreach ($b in $guard.Blockers) { Write-Information ("  - {0}" -f $b) -InformationAction Continue }
    return [PSCustomObject]@{ environment=$Environment; mode=$Mode; correlationId=$correlationId; validationPassed=$true; guardPassed=$false; blockers=$guard.Blockers; exitCode=2 }
}

# ---------------------------------------------------------------- 3. run layers in dependency order
$runAll = ($Layer -contains 'All')
$results = [ordered]@{}
$common = @{ Environment = $Environment; Mode = $Mode }

if ($runAll -or $Layer -contains 'SharePoint') {
    $results['SharePoint'] = & (Join-Path $PSScriptRoot 'Deploy-DmsSharePoint.ps1') @common -Connection $Connection -LogPath $LogPath
}
if ($runAll -or $Layer -contains 'Security') {
    $results['Security'] = & (Join-Path $PSScriptRoot 'Deploy-DmsSecurity.ps1') @common -Connection $Connection -TenantAdminConnection $TenantAdminConnection
}
if ($runAll -or $Layer -contains 'Purview') {
    # Purview always defaults to Plan; it is never applied implicitly by the orchestrator.
    $results['Purview'] = & (Join-Path $PSScriptRoot 'Deploy-DmsPurview.ps1') -Environment $Environment -Mode Plan
}
if ($runAll -or $Layer -contains 'PowerPlatform') {
    $results['PowerPlatform'] = & (Join-Path $PSScriptRoot 'Deploy-DmsPowerPlatform.ps1') @common
}

# ---------------------------------------------------------------- 4. summary
$totalBlocked = 0; $totalFailed = 0; $totalCreate = 0; $totalUpdate = 0; $totalCompliant = 0
foreach ($k in $results.Keys) {
    $r = $results[$k]
    if ($null -eq $r) { continue }
    $totalBlocked   += [int](Get-DmsPropertyOrDefault -InputObject $r -Name 'blockedCount'   -Default 0)
    $totalFailed    += [int](Get-DmsPropertyOrDefault -InputObject $r -Name 'failedCount'    -Default 0)
    $totalCreate    += [int](Get-DmsPropertyOrDefault -InputObject $r -Name 'createCount'    -Default 0)
    $totalUpdate    += [int](Get-DmsPropertyOrDefault -InputObject $r -Name 'updateCount'    -Default 0)
    $totalCompliant += [int](Get-DmsPropertyOrDefault -InputObject $r -Name 'compliantCount' -Default 0)
}

$exitCode = if ($totalFailed -gt 0) { 1 } elseif ($totalBlocked -gt 0) { 2 } else { 0 }

Write-Information "" -InformationAction Continue
Write-Information "=== deployment summary ===========================================================" -InformationAction Continue
foreach ($k in $results.Keys) {
    $r = $results[$k]
    Write-Information ("{0,-14} create={1,-4} update={2,-4} compliant={3,-4} blocked={4,-4} exit={5}" -f `
        $k, (Get-DmsPropertyOrDefault -InputObject $r -Name 'createCount' -Default 0),
            (Get-DmsPropertyOrDefault -InputObject $r -Name 'updateCount' -Default 0),
            (Get-DmsPropertyOrDefault -InputObject $r -Name 'compliantCount' -Default 0),
            (Get-DmsPropertyOrDefault -InputObject $r -Name 'blockedCount' -Default 0),
            (Get-DmsPropertyOrDefault -InputObject $r -Name 'exitCode' -Default 0)) -InformationAction Continue
}
Write-Information ("TOTAL          create={0,-4} update={1,-4} compliant={2,-4} blocked={3,-4} failed={4}" -f $totalCreate, $totalUpdate, $totalCompliant, $totalBlocked, $totalFailed) -InformationAction Continue
Write-Information ("exit code      {0}" -f $exitCode) -InformationAction Continue
Write-Information "==================================================================================" -InformationAction Continue

return [PSCustomObject]@{
    environment=$Environment; mode=$Mode; correlationId=$correlationId
    validationPassed=$true; guardPassed=$true
    createCount=$totalCreate; updateCount=$totalUpdate; compliantCount=$totalCompliant
    blockedCount=$totalBlocked; failedCount=$totalFailed
    layers=$results; exitCode=$exitCode
}
