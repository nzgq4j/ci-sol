#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Install-SolDms.ps1'
$tokens = $null
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_.Message }
  throw "Install-SolDms.ps1 contains $($errors.Count) PowerShell parser error(s)."
}

$requiredCommands = @(
  'Connect-PnPOnline',
  'Get-PnPTenantAppCatalogUrl',
  'Get-PnPSiteCollectionAppCatalog',
  'Add-PnPSiteCollectionAppCatalog',
  'Get-PnPApp',
  'Add-PnPApp',
  'Add-PnPFile',
  'Add-PnPPage',
  'Get-PnPPage',
  'Get-PnPPageComponent',
  'Add-PnPPageWebPart',
  'Set-PnPPageWebPart',
  'Set-PnPPage'
)
$content = Get-Content -LiteralPath $scriptPath -Raw
foreach ($command in $requiredCommands) {
  if ($content -notmatch [regex]::Escape($command)) {
    throw "Install-SolDms.ps1 does not reference required command $command."
  }
}

Write-Output "Install-SolDms.ps1 parsed successfully and contains all required deployment commands."
