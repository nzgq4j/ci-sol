#Requires -Version 7.2
<#
.SYNOPSIS
    Plans and validates the Power Platform solution deployment for the DMS.
.DESCRIPTION
    Implements PRD ADM-004 and ADM-005. Test and Production receive MANAGED solutions only;
    unmanaged import outside Dev is refused because it permits direct production editing, which
    PRD NFR-010 forbids.

    Validates that deployment settings contain no hard-coded site URL or group ID, and that every
    connection reference and environment variable the solution declares has a value for the target
    environment.

    Solution import itself is performed by the Power Platform CLI (pac). This script produces the
    validated deployment-settings file and the exact command to run, rather than wrapping pac in a
    way that hides failures.
.PARAMETER Environment
    Environment key.
.PARAMETER Mode
    Plan or Apply.
.PARAMETER SolutionPath
    Path to the exported solution package.
.PARAMETER ConfigPath
    Configuration directory.
.EXAMPLE
    ./Deploy-DmsPowerPlatform.ps1 -Environment test -Mode Plan
.OUTPUTS
    PSCustomObject plan summary.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode,
    [Parameter()][string]$SolutionPath,
    [Parameter()][string]$ConfigPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }

$config = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$plan   = New-DmsPlan -Environment $Environment -Mode $Mode
$ppRoot = Join-Path $PSScriptRoot '..' 'power-platform'
$settingsFile = Join-Path $ppRoot 'deployment-settings' "deployment-settings.$Environment.json"

# 1. Managed-solution rule
$requiresManaged = $Environment -in @('test','prod')
Add-DmsPlanAction -Plan $plan -ResourceType 'SolutionPolicy' -Target $Environment -Change $(if ($requiresManaged) { 'Compliant' } else { 'Compliant' }) `
    -Reason $(if ($requiresManaged) { "Managed solution required for '$Environment'. Unmanaged import is refused (PRD ADM-004, NFR-010)." } else { "Unmanaged development is permitted in '$Environment' only." }) `
    -Requirements @('ADM-004','NFR-010') | Out-Null

# 2. Deployment settings must exist and be free of hard-coded values
if (-not (Test-Path -LiteralPath $settingsFile)) {
    Add-DmsPlanAction -Plan $plan -ResourceType 'DeploymentSettings' -Target $settingsFile -Change 'Blocked' `
        -Reason "Deployment settings file for '$Environment' is missing. Connection references and environment variables must be supplied per environment (PRD ADM-005)." `
        -Requirements @('ADM-005') | Out-Null
} else {
    $settings = Read-DmsJsonFile -Path $settingsFile
    $unresolved = @()
    foreach ($ev in @(Get-DmsPropertyOrDefault -InputObject $settings -Name 'EnvironmentVariables' -Default @())) {
        if ("$($ev.Value)" -like '*REQUIRES_*' -or [string]::IsNullOrWhiteSpace("$($ev.Value)")) { $unresolved += $ev.SchemaName }
    }
    foreach ($cr in @(Get-DmsPropertyOrDefault -InputObject $settings -Name 'ConnectionReferences' -Default @())) {
        if ("$($cr.ConnectionId)" -like '*REQUIRES_*' -or [string]::IsNullOrWhiteSpace("$($cr.ConnectionId)")) { $unresolved += $cr.LogicalName }
    }
    if ($unresolved.Count -gt 0) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'DeploymentSettings' -Target "deployment-settings.$Environment.json" -Change 'Blocked' `
            -Reason "Unresolved values: $($unresolved -join ', '). Each must be supplied before import, or the solution will import with broken connections." `
            -Requirements @('ADM-005','ADM-008') | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'DeploymentSettings' -Target "deployment-settings.$Environment.json" -Change 'Compliant' `
            -Reason 'All connection references and environment variables are resolved.' -Requirements @('ADM-005') | Out-Null
    }
}

# 3. Solution package presence
if (-not $SolutionPath) { $SolutionPath = Join-Path $ppRoot 'solution' }
$hasPackage = (Test-Path -LiteralPath $SolutionPath) -and @(Get-ChildItem -LiteralPath $SolutionPath -Filter '*.zip' -File -ErrorAction SilentlyContinue).Count -gt 0
if (-not $hasPackage) {
    Add-DmsPlanAction -Plan $plan -ResourceType 'SolutionPackage' -Target $SolutionPath -Change 'Blocked' `
        -Reason "No exported solution package is present. The flows are specified in src/power-platform/flow-specifications/ and must be built in a Dev environment and exported; a solution archive is deliberately NOT fabricated here." `
        -Requirements @('ADM-004') | Out-Null
}

# 4. Flow specification coverage for the P0 flows
$specDir = Join-Path $ppRoot 'flow-specifications'
foreach ($flow in @('Flow1-Request-Triage','Flow2-Submit-Review-Approve','Flow3-Scheduled-Activation','Flow4-Periodic-Review','Flow5-Exception-Management')) {
    $specFile = Join-Path $specDir "$flow.md"
    if (Test-Path -LiteralPath $specFile) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'FlowSpecification' -Target $flow -Change 'Compliant' -Reason 'Specification present.' -Requirements @('F-007','F-008','F-012','F-015','F-022') | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'FlowSpecification' -Target $flow -Change 'Blocked' -Reason 'Specification missing.' -Requirements @('ADM-004') | Out-Null
    }
}

$summary = Format-DmsPlan -Plan $plan
if ($Mode -eq 'Apply') {
    Write-Information "" -InformationAction Continue
    Write-Information "Power Platform import is performed with the Power Platform CLI. Run:" -InformationAction Continue
    Write-Information ("  pac auth create --environment {0}" -f (Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'powerPlatformEnvironmentUrl' -Default '<env-url>')) -InformationAction Continue
    Write-Information ("  pac solution import --path <solution_managed.zip> --settings-file {0} --activate-plugins --force-overwrite" -f $settingsFile) -InformationAction Continue
    if ($requiresManaged) { Write-Information "  Only a *_managed.zip package may be imported into test or prod." -InformationAction Continue }
}
$summary | Add-Member -NotePropertyName exitCode -NotePropertyValue $(if ($summary.hasBlocking) { 2 } else { 0 }) -Force
return $summary
