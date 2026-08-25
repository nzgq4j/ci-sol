#Requires -Version 7.2
<#
.SYNOPSIS
    Validates DMS configuration offline. The pre-deployment and CI gate.
.DESCRIPTION
    Runs schema conformance, cross-file referential integrity, lifecycle and routing rule
    conformance, PnP cmdlet-usage verification and the retention safety gate. Requires no tenant
    access, so it runs in CI and on a developer machine.
.PARAMETER Environment
    Environment key to resolve.
.PARAMETER ConfigPath
    Configuration directory.
.PARAMETER SkipPnPUsage
    Skip the PnP cmdlet-usage check.
.PARAMETER AsJson
    Emit machine-readable output.
.EXAMPLE
    ./Test-DmsConfiguration.ps1 -Environment dev
.OUTPUTS
    PSCustomObject. Exit code 0 pass, 1 failure.
#>
[CmdletBinding()]
param(
    [Parameter()][ValidateSet('dev','test','prod')][string]$Environment = 'dev',
    [Parameter()][string]$ConfigPath,
    [Parameter()][switch]$SkipPnPUsage,
    [Parameter()][switch]$AsJson
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }

$config = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$cfgResult = Test-DmsConfiguration -Configuration $config

$pnpResult = $null
if (-not $SkipPnPUsage) {
    $pnpResult = Test-DmsPnPCmdletUsage -Path @((Join-Path $PSScriptRoot '..'))
}

$isValid = $cfgResult.IsValid -and (($null -eq $pnpResult) -or $pnpResult.IsValid)

$result = [PSCustomObject]@{
    environment      = $Environment
    isValid          = $isValid
    checkCount       = $cfgResult.CheckCount
    passedCount      = $cfgResult.PassedCount
    failedCount      = $cfgResult.FailedCount
    warningCount     = $cfgResult.WarningCount
    failures         = $cfgResult.Failures
    warnings         = $cfgResult.Warnings
    pnpCmdletUsages  = if ($pnpResult) { $pnpResult.CmdletUsages } else { $null }
    pnpFindings      = if ($pnpResult) { $pnpResult.Findings }     else { @() }
    pnpIndexCommit   = if ($pnpResult) { $pnpResult.IndexCommit }  else { $null }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Information "" -InformationAction Continue
    Write-Information "DMS configuration validation  environment=$Environment" -InformationAction Continue
    Write-Information ('-' * 100) -InformationAction Continue
    foreach ($c in $cfgResult.Checks) {
        $mark = if ($c.Passed) { 'PASS' } else { 'FAIL' }
        Write-Information ("{0}  {1,-52} {2}" -f $mark, $c.Name, $(if ($c.Passed) { '' } else { $c.Detail })) -InformationAction Continue
    }
    if ($pnpResult) {
        $mark = if ($pnpResult.IsValid) { 'PASS' } else { 'FAIL' }
        Write-Information ("{0}  {1,-52} {2} PnP invocation(s) verified against source {3}" -f $mark, 'PnPCmdletUsage', $pnpResult.CmdletUsages, $pnpResult.IndexCommit.Substring(0,8)) -InformationAction Continue
        foreach ($f in $pnpResult.Findings) { Write-Information ("      {0}: {1}" -f $f.File, $f.Detail) -InformationAction Continue }
    }
    Write-Information ('-' * 100) -InformationAction Continue
    foreach ($w in $cfgResult.Warnings) { Write-Warning $w }
    Write-Information ("result: {0}   checks={1} passed={2} failed={3} warnings={4}" -f $(if ($isValid) { 'VALID' } else { 'INVALID' }), $cfgResult.CheckCount, $cfgResult.PassedCount, $cfgResult.FailedCount, $cfgResult.WarningCount) -InformationAction Continue
}

if (-not $isValid) { exit 1 }
exit 0
