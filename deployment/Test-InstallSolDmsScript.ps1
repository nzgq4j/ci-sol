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
  'Publish-PnPApp',
  'Get-PnPFileInFolder',
  'Add-PnPFile',
  'Get-PnPList',
  'Add-PnPPage',
  'Get-PnPPage',
  'Get-PnPPageComponent',
  'Remove-PnPPageComponent',
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

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageSolutionPath = Join-Path $repositoryRoot 'sharepoint/sol-dms/config/package-solution.json'
$webPartManifestPath = Join-Path $repositoryRoot 'sharepoint/sol-dms/src/webparts/solDms/SolDmsWebPart.manifest.json'
$packagePath = Join-Path $repositoryRoot 'sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg'

$packageSolution = Get-Content -LiteralPath $packageSolutionPath -Raw | ConvertFrom-Json -Depth 20
$webPartManifest = Get-Content -LiteralPath $webPartManifestPath -Raw | ConvertFrom-Json -Depth 20
$solutionId = [guid]$packageSolution.solution.id
$componentId = [guid]$webPartManifest.id
$featureId = [guid]$packageSolution.solution.features[0].id
$packageVersion = [version]$packageSolution.solution.version

foreach ($identity in @($solutionId, $componentId)) {
  if ($content -notmatch [regex]::Escape([string]$identity)) {
    throw "Install-SolDms.ps1 is not bound to package identity $identity."
  }
}

if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
  throw "The built SPFx package is missing: $packagePath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($packagePath)
try {
  $appManifestEntry = $archive.GetEntry('AppManifest.xml')
  if ($null -eq $appManifestEntry) { throw 'The SPFx package does not contain AppManifest.xml.' }
  $reader = [IO.StreamReader]::new($appManifestEntry.Open())
  try { [xml]$appManifest = $reader.ReadToEnd() } finally { $reader.Dispose() }

  if ([guid]$appManifest.App.ProductID -ne $solutionId) {
    throw "The built package solution ID does not match package-solution.json ($solutionId)."
  }
  if ([version]$appManifest.App.Version -ne $packageVersion) {
    throw "The built package version does not match package-solution.json ($packageVersion)."
  }

  $webPartEntry = "$featureId/WebPart_$componentId.xml"
  if ($null -eq $archive.GetEntry($webPartEntry)) {
    throw "The built package does not contain expected component definition $webPartEntry."
  }

  $clientScriptEntry = $archive.Entries |
    Where-Object { $_.FullName -match '^ClientSideAssets/sol-dms-web-part_[a-f0-9]+\.js$' } |
    Select-Object -First 1
  if ($null -eq $clientScriptEntry) {
    throw 'The built package does not contain the SOL DMS client-side JavaScript asset.'
  }
  $clientScriptReader = [IO.StreamReader]::new($clientScriptEntry.Open())
  try { $clientScript = $clientScriptReader.ReadToEnd() } finally { $clientScriptReader.Dispose() }
  if (-not $clientScript.Contains('.app-shell{')) {
    throw 'The packaged client asset does not contain the global SOL application stylesheet.'
  }
  if ($clientScript -match '\.app-shell_[A-Za-z0-9_-]+') {
    throw 'The packaged client asset renamed SOL application selectors as CSS modules; the SharePoint UI would render unstyled.'
  }
} finally {
  $archive.Dispose()
}

Write-Output "Install-SolDms.ps1 and sol-dms.sppkg validated: solution $solutionId, component $componentId, version $packageVersion."
