#requires -Version 5.1

<#
.SYNOPSIS
Deploys the SOL DMS SPFx package and access page to SharePoint Online.

.DESCRIPTION
Uploads and publishes the SOL DMS .sppkg, uploads a validated tenant-owned
runtime manifest, creates or updates a modern page, adds the SOL Document
Control web part, and publishes the page. The script never creates credentials,
grants tenant API permissions, or supplies missing tenant configuration.

.EXAMPLE
./Install-SolDms.ps1 `
  -TargetSiteUrl 'https://tenant.sharepoint.com/sites/document-control' `
  -PnPClientId '00000000-0000-0000-0000-000000000000' `
  -RuntimeConfigurationPath './deployment/sol-dms-runtime.production.json' `
  -WhatIf

.NOTES
The script may be launched from Windows PowerShell 5.1. It automatically
relaunches itself under PowerShell 7.4 or later because PnP.PowerShell 3.4.1
does not run in Windows PowerShell. A tenant-approved Entra application is
still required for interactive PnP PowerShell authentication. Placeholder
values in examples are not deployable tenant configuration.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)]
  [ValidateScript({ $_.IsAbsoluteUri -and $_.Scheme -eq 'https' })]
  [uri]$TargetSiteUrl,

  [Parameter(Mandatory)]
  [guid]$PnPClientId,

  [ValidateSet('Interactive', 'DeviceLogin')]
  [string]$AuthenticationMode = 'Interactive',

  [ValidateRange(1, 5)]
  [int]$ConnectionAttempts = 3,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$RuntimeConfigurationPath,

  [string]$PackagePath,

  [ValidateSet('Tenant', 'Site')]
  [string]$AppCatalogScope = 'Tenant',

  [ValidateScript({ $_.IsAbsoluteUri -and $_.Scheme -eq 'https' })]
  [uri]$TenantAppCatalogUrl,

  [ValidateScript({ $_.IsAbsoluteUri -and $_.Scheme -eq 'https' })]
  [uri]$TenantAdminUrl,

  [ValidateScript({ $_ -notmatch '(^[\\/])|([\\/])\.\.([\\/]|$)|(^\.\.$)' })]
  [string]$ConfigurationFolder = 'SiteAssets/SOL-DMS',

  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*\.json$')]
  [string]$ConfigurationFileName = 'sol-dms-runtime.json',

  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
  [string]$PageName = 'SOL-Document-Control',

  [ValidateNotNullOrEmpty()]
  [string]$PageTitle = 'SOL Document Control',

  [ValidateRange(30, 600)]
  [int]$ComponentWaitSeconds = 180,

  [switch]$AllowUnconfigured,
  [switch]$EnsureSiteCollectionAppCatalog,
  [switch]$SkipPackageUpload,
  [switch]$OverwritePackage,
  [switch]$OverwriteConfiguration,
  [switch]$UpdateExistingPage,

  [string]$ReceiptPath,
  [switch]$OverwriteReceipt
)

if ($PSVersionTable.PSVersion -lt [version]'7.4') {
  $pwshCommand = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue
  if ($null -eq $pwshCommand) {
    throw 'PowerShell 7.4 or later is required but pwsh.exe was not found. Install PowerShell 7, then rerun this same command.'
  }

  $forwardedArguments = [Collections.Generic.List[string]]::new()
  $forwardedArguments.Add('-NoLogo')
  $forwardedArguments.Add('-NoProfile')
  $forwardedArguments.Add('-File')
  $forwardedArguments.Add($PSCommandPath)

  foreach ($parameterName in $PSBoundParameters.Keys) {
    $parameterValue = $PSBoundParameters[$parameterName]
    if ($parameterValue -is [Management.Automation.SwitchParameter]) {
      if ($parameterValue.IsPresent) { $forwardedArguments.Add("-$parameterName") }
      continue
    }
    if ($parameterValue -is [bool]) {
      if ($parameterValue) { $forwardedArguments.Add("-$parameterName") }
      continue
    }

    $forwardedArguments.Add("-$parameterName")
    $forwardedArguments.Add([string]$parameterValue)
  }

  $childArguments = $forwardedArguments.ToArray()
  & $pwshCommand.Source @childArguments
  if ($LASTEXITCODE -ne 0) {
    throw "The PowerShell 7 installer process exited with code $LASTEXITCODE."
  }
  return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
  $PackagePath = Join-Path $PSScriptRoot '../sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg'
}

$solWebPartComponentId = [guid]'772c04cc-f5af-4485-8e48-d4de27923fa0'
$solSolutionId = [guid]'6b30f157-0d3c-4988-8843-eb6e1c3b8acd'
$legacySolWebPartComponentIds = @([guid]'7c36e2e7-eba7-43e1-886f-7b7a3d848c29')
$requiredOperations = @(
  'listSites',
  'searchDocuments',
  'getDocumentDetail',
  'setFavourite',
  'listContentTypes',
  'validateMetadata',
  'currentUser',
  'searchPeople',
  'userContext',
  'groupHealth',
  'authorize',
  'listFlows',
  'startControlScan',
  'listRetentionMappings',
  'recoveryStatus',
  'listChangeRequests',
  'listApprovals',
  'recordApproval',
  'listAcknowledgements',
  'recordAcknowledgement',
  'listAudit',
  'listDeployments',
  'platformSnapshot',
  'listIntegrations',
  'setIntegration',
  'listExceptions',
  'resolveException'
)

function Write-Step {
  param([Parameter(Mandatory)][string]$Message)
  Write-Information "[SOL DMS] $Message"
}

function Get-PropertyValue {
  param(
    [Parameter(Mandatory)][object]$InputObject,
    [Parameter(Mandatory)][string]$Name
  )
  $property = $InputObject.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Connect-SolPnPOnline {
  param(
    [Parameter(Mandatory)][uri]$Url,
    [Parameter(Mandatory)][guid]$ClientId,
    [Parameter(Mandatory)][ValidateSet('Interactive', 'DeviceLogin')][string]$Mode,
    [Parameter(Mandatory)][ValidateRange(1, 5)][int]$Attempts
  )

  for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    $connectionParameters = @{
      Url = $Url.AbsoluteUri
      ClientId = $ClientId
      ReturnConnection = $true
      ValidateConnection = $true
      ErrorAction = 'Stop'
    }
    if ($Mode -eq 'DeviceLogin') {
      $connectionParameters.DeviceLogin = $true
    } else {
      $connectionParameters.Interactive = $true
    }

    try {
      return Connect-PnPOnline @connectionParameters
    } catch {
      $messages = [Collections.Generic.List[string]]::new()
      $exception = $_.Exception
      while ($null -ne $exception) {
        if (-not [string]::IsNullOrWhiteSpace($exception.Message) -and $exception.Message -notin $messages) {
          $messages.Add($exception.Message)
        }
        $exception = $exception.InnerException
      }
      $detail = $messages -join ' -> '
      if ($attempt -ge $Attempts) {
        throw "Unable to connect to $($Url.AbsoluteUri) using $Mode after $Attempts attempt(s). $detail"
      }
      $delaySeconds = [Math]::Pow(2, $attempt)
      Write-Warning "Connection attempt $attempt of $Attempts to $($Url.AbsoluteUri) failed: $detail Retrying in $delaySeconds seconds."
      Start-Sleep -Seconds $delaySeconds
    }
  }
}

function Resolve-RequiredFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$Extension
  )
  $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "$Description was not found: $resolved"
  }
  if ([IO.Path]::GetExtension($resolved) -ne $Extension) {
    throw "$Description must be a $Extension file: $resolved"
  }
  return (Resolve-Path -LiteralPath $resolved).Path
}

function Test-EndpointOrigin {
  param(
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$Auth,
    [Parameter(Mandatory)][uri]$SiteUrl,
    [Parameter(Mandatory)][string]$Operation
  )
  $absolute = $null
  if ([uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$absolute)) {
    if ($absolute.Scheme -ne 'https') {
      throw "Endpoint '$Operation' must use HTTPS."
    }
    if ($Auth -in @('browser', 'sharePoint') -and $absolute.Authority -ne $SiteUrl.Authority) {
      throw "Endpoint '$Operation' uses '$Auth' authentication but is on another origin. Use an approved Entra-protected endpoint instead."
    }
  } elseif ($Url.StartsWith('//')) {
    throw "Endpoint '$Operation' must not use a protocol-relative URL."
  }
}

function Read-RuntimeConfiguration {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][uri]$SiteUrl,
    [Parameter(Mandatory)][bool]$PermitMissingOperations
  )
  $text = Get-Content -LiteralPath $Path -Raw
  if ($text -match '(?i)"(authorization|cookie|client[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|password)"\s*:') {
    throw 'The runtime manifest appears to contain a credential or secret field. Store credentials in the tenant service, never in SharePoint configuration.'
  }
  if ($text -match '(?i)[?&](sig|signature|token|code|key|secret)=') {
    throw 'The runtime manifest appears to contain a signed or secret-bearing URL. Configure an authenticated service boundary instead.'
  }

  try {
    $configuration = $text | ConvertFrom-Json -Depth 20
  } catch {
    throw "Runtime configuration is not valid JSON: $($_.Exception.Message)"
  }

  if ((Get-PropertyValue -InputObject $configuration -Name 'mode') -ne 'http') {
    throw 'Runtime configuration must declare mode "http".'
  }
  $endpoints = Get-PropertyValue -InputObject $configuration -Name 'endpoints'
  if ($null -eq $endpoints -or $endpoints -isnot [pscustomobject]) {
    throw 'Runtime configuration must contain an endpoints object.'
  }

  $unconfigured = [Collections.Generic.List[string]]::new()
  foreach ($operation in $requiredOperations) {
    $definition = Get-PropertyValue -InputObject $endpoints -Name $operation
    if ($null -eq $definition) {
      $unconfigured.Add($operation)
      continue
    }

    $url = $null
    $auth = 'browser'
    if ($definition -is [string]) {
      $url = $definition.Trim()
    } elseif ($definition -is [pscustomobject]) {
      $urlValue = Get-PropertyValue -InputObject $definition -Name 'url'
      if ($urlValue -is [string]) { $url = $urlValue.Trim() }
      $authValue = Get-PropertyValue -InputObject $definition -Name 'auth'
      if ($authValue -is [string] -and -not [string]::IsNullOrWhiteSpace($authValue)) { $auth = $authValue }
      if ($auth -notin @('browser', 'sharePoint', 'entra')) {
        throw "Endpoint '$operation' has unsupported authentication '$auth'."
      }
      if ($auth -eq 'entra') {
        $resource = Get-PropertyValue -InputObject $definition -Name 'resource'
        if ($resource -isnot [string] -or [string]::IsNullOrWhiteSpace($resource)) {
          throw "Entra endpoint '$operation' must declare its approved application resource URI."
        }
      }
    } else {
      throw "Endpoint '$operation' must be a URL string or an endpoint object."
    }

    if ([string]::IsNullOrWhiteSpace($url)) {
      $unconfigured.Add($operation)
      continue
    }
    Test-EndpointOrigin -Url $url -Auth $auth -SiteUrl $SiteUrl -Operation $operation
  }

  if ($unconfigured.Count -gt 0) {
    $message = "Runtime configuration has $($unconfigured.Count) unconfigured operations: $($unconfigured -join ', ')."
    if (-not $PermitMissingOperations) { throw "$message Use -AllowUnconfigured only for a staged, non-production installation." }
    Write-Warning $message
  }
  return $configuration
}

function Test-ComponentIdentity {
  param(
    [Parameter(Mandatory)][object]$Component,
    [Parameter(Mandatory)][guid]$ComponentId
  )
  foreach ($propertyName in @('WebPartId', 'ComponentId', 'Id')) {
    $value = Get-PropertyValue -InputObject $Component -Name $propertyName
    if ($null -ne $value -and [string]$value -eq [string]$ComponentId) { return $true }
  }
  return $false
}

function Get-ComponentInstanceId {
  param([Parameter(Mandatory)][object]$Component)
  foreach ($propertyName in @('InstanceId', 'Id')) {
    $value = Get-PropertyValue -InputObject $Component -Name $propertyName
    if ($null -ne $value) { return $value }
  }
  throw 'The existing SOL web-part instance does not expose an instance identifier.'
}

function Get-PackagedClientScriptNames {
  param([Parameter(Mandatory)][string]$Path)

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($Path)
  try {
    return @(
      $archive.Entries |
        Where-Object { $_.FullName -like 'ClientSideAssets/*.js' -and -not $_.FullName.EndsWith('/') } |
        ForEach-Object { [IO.Path]::GetFileName($_.FullName) }
    )
  } finally {
    $archive.Dispose()
  }
}

function Get-PackagedSolutionVersion {
  param([Parameter(Mandatory)][string]$Path)

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $manifestEntry = $archive.GetEntry('AppManifest.xml')
    if ($null -eq $manifestEntry) {
      throw 'The reviewed SPFx package does not contain AppManifest.xml.'
    }
    $reader = [IO.StreamReader]::new($manifestEntry.Open())
    try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    return [version]$manifest.App.Version
  } finally {
    $archive.Dispose()
  }
}

$resolvedPackagePath = Resolve-RequiredFile -Path $PackagePath -Description 'SPFx package' -Extension '.sppkg'
$resolvedConfigurationPath = Resolve-RequiredFile -Path $RuntimeConfigurationPath -Description 'Runtime configuration' -Extension '.json'
$null = Read-RuntimeConfiguration -Path $resolvedConfigurationPath -SiteUrl $TargetSiteUrl -PermitMissingOperations $AllowUnconfigured.IsPresent
$expectedClientScripts = @(Get-PackagedClientScriptNames -Path $resolvedPackagePath)
$expectedPackageVersion = Get-PackagedSolutionVersion -Path $resolvedPackagePath
if ($expectedClientScripts.Count -eq 0) {
  throw 'The reviewed SPFx package does not contain a packaged client-side JavaScript asset.'
}

if ($AppCatalogScope -eq 'Site' -and $null -ne $TenantAppCatalogUrl) {
  throw 'TenantAppCatalogUrl can only be used with -AppCatalogScope Tenant.'
}
if ($SkipPackageUpload -and $OverwritePackage) {
  throw 'SkipPackageUpload and OverwritePackage cannot be used together.'
}
if ($EnsureSiteCollectionAppCatalog -and $AppCatalogScope -ne 'Site') {
  throw 'EnsureSiteCollectionAppCatalog requires -AppCatalogScope Site.'
}
if ($EnsureSiteCollectionAppCatalog -and $null -eq $TenantAdminUrl) {
  throw 'TenantAdminUrl is required with -EnsureSiteCollectionAppCatalog.'
}

$configurationFolderValue = $ConfigurationFolder.Replace('\', '/').Trim('/')
if ([string]::IsNullOrWhiteSpace($configurationFolderValue)) { throw 'ConfigurationFolder cannot be empty.' }
$pageNameValue = [IO.Path]::GetFileNameWithoutExtension($PageName)
$configurationSiteRelativeUrl = "$configurationFolderValue/$ConfigurationFileName"
$propertiesJson = @{ configurationUrl = $configurationSiteRelativeUrl } | ConvertTo-Json -Compress
$packageHash = (Get-FileHash -LiteralPath $resolvedPackagePath -Algorithm SHA256).Hash

if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
  $resolvedReceiptPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReceiptPath)
  if ((Test-Path -LiteralPath $resolvedReceiptPath) -and -not $OverwriteReceipt) {
    throw "Receipt already exists. Use -OverwriteReceipt to replace it: $resolvedReceiptPath"
  }
}

$packagePlan = if ($SkipPackageUpload) { "reuse deployed SOL DMS package $packageHash" } else { "deploy SOL DMS package $packageHash" }
if ($EnsureSiteCollectionAppCatalog) { $packagePlan = "$packagePlan through the target site-collection App Catalog" }
$plan = "$packagePlan, upload configuration, and publish SitePages/$pageNameValue.aspx"
if (-not $PSCmdlet.ShouldProcess($TargetSiteUrl.AbsoluteUri, $plan)) { return }

$availableModule = Get-Module -ListAvailable -Name PnP.PowerShell |
  Where-Object Version -ge ([version]'3.4.1') |
  Sort-Object Version -Descending |
  Select-Object -First 1
if ($null -eq $availableModule) {
  throw 'PnP.PowerShell 3.4.1 or later is required. Review and run: Install-Module PnP.PowerShell -RequiredVersion 3.4.1 -Scope CurrentUser'
}
Import-Module $availableModule.Path -Force

Write-Step "Connecting to $($TargetSiteUrl.AbsoluteUri) using $AuthenticationMode authentication."
$connection = Connect-SolPnPOnline -Url $TargetSiteUrl -ClientId $PnPClientId -Mode $AuthenticationMode -Attempts $ConnectionAttempts
$web = Get-PnPWeb -Connection $connection -Includes Url, ServerRelativeUrl

$appCatalogConnection = $connection
$resolvedAppCatalogUrl = $null
if ($AppCatalogScope -eq 'Tenant') {
  if ($null -ne $TenantAppCatalogUrl) {
    $resolvedAppCatalogUrl = $TenantAppCatalogUrl
  } else {
    Write-Step 'Discovering the tenant App Catalog URL.'
    $discoveredAppCatalogUrl = Get-PnPTenantAppCatalogUrl -Connection $connection
    if ([string]::IsNullOrWhiteSpace([string]$discoveredAppCatalogUrl)) {
      throw 'No tenant App Catalog URL was returned. Supply -TenantAppCatalogUrl or ask a SharePoint administrator to configure the tenant App Catalog.'
    }
    $resolvedAppCatalogUrl = [uri]$discoveredAppCatalogUrl
  }

  Write-Step "Connecting directly to the tenant App Catalog at $($resolvedAppCatalogUrl.AbsoluteUri)."
    $appCatalogConnection = Connect-SolPnPOnline -Url $resolvedAppCatalogUrl -ClientId $PnPClientId -Mode $AuthenticationMode -Attempts $ConnectionAttempts
}

$adminConnection = $null
if ($EnsureSiteCollectionAppCatalog) {
  Write-Step "Connecting directly to the tenant administration site at $($TenantAdminUrl.AbsoluteUri)."
  $adminConnection = Connect-SolPnPOnline -Url $TenantAdminUrl -ClientId $PnPClientId -Mode $AuthenticationMode -Attempts $ConnectionAttempts

  $siteCollectionAppCatalog = Get-PnPSiteCollectionAppCatalog -CurrentSite -Connection $connection
  if ($null -eq $siteCollectionAppCatalog) {
    Write-Step 'Enabling the site-collection App Catalog for the target site.'
    Add-PnPSiteCollectionAppCatalog -Site $TargetSiteUrl.AbsoluteUri -Connection $adminConnection

    $siteCatalogDeadline = [DateTimeOffset]::UtcNow.AddSeconds(180)
    do {
      Start-Sleep -Seconds 5
      $siteCollectionAppCatalog = Get-PnPSiteCollectionAppCatalog -CurrentSite -Connection $connection
    } while ($null -eq $siteCollectionAppCatalog -and [DateTimeOffset]::UtcNow -lt $siteCatalogDeadline)
    if ($null -eq $siteCollectionAppCatalog) {
      throw 'SharePoint did not expose the target site-collection App Catalog within 180 seconds.'
    }
  } else {
    Write-Step 'The target site-collection App Catalog is already enabled.'
  }
}

$receipt = $null
$existingPageFile = Get-PnPFile -Url "SitePages/$pageNameValue.aspx" -AsListItem -Connection $connection -ErrorAction Stop
$existingPage = if ($null -ne $existingPageFile) {
  Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
} else {
  $null
}
if ($null -ne $existingPage -and -not $UpdateExistingPage) {
  throw "Page SitePages/$pageNameValue.aspx already exists. Use -UpdateExistingPage only after reviewing the existing page."
}

$existingConfiguration = Get-PnPFile -Url $configurationSiteRelativeUrl -AsListItem -Connection $connection -ErrorAction Stop
if ($null -ne $existingConfiguration -and -not $OverwriteConfiguration) {
  throw "Runtime configuration already exists at $configurationSiteRelativeUrl. Use -OverwriteConfiguration only after reviewing the existing file."
}

if ($SkipPackageUpload) {
  Write-Step "Verifying exact packaged version $expectedPackageVersion in the $AppCatalogScope App Catalog."
  $catalogApp = Get-PnPApp -Identity $solSolutionId -Scope $AppCatalogScope -Connection $appCatalogConnection -ErrorAction Stop
  if ($null -eq $catalogApp -or -not $catalogApp.Deployed) {
    throw "SOL DMS package $solSolutionId is not deployed in the $AppCatalogScope App Catalog. Remove -SkipPackageUpload and deploy the reviewed package."
  }
  $catalogVersionValue = Get-PropertyValue -InputObject $catalogApp -Name 'AppCatalogVersion'
  $catalogVersion = $null
  if ($null -eq $catalogVersionValue -or
    -not [version]::TryParse([string]$catalogVersionValue, [ref]$catalogVersion) -or
    $catalogVersion -ne $expectedPackageVersion) {
    $reportedVersion = if ($null -eq $catalogVersion) { 'none' } else { [string]$catalogVersion }
    throw "The deployed $AppCatalogScope App Catalog package is version $reportedVersion, but this installer contains version $expectedPackageVersion. Remove -SkipPackageUpload to deploy the reviewed package."
  }
  Write-Step "Verified deployed package version $catalogVersion; package upload is safely skipped."
} elseif ($AppCatalogScope -eq 'Site') {
  $packageFileName = [IO.Path]::GetFileName($resolvedPackagePath)
  $catalogPackageUrl = "AppCatalog/$packageFileName"
  $existingCatalogPackage = Get-PnPFile -Url $catalogPackageUrl -AsListItem -Connection $connection -ErrorAction SilentlyContinue
  if ($null -ne $existingCatalogPackage -and -not $OverwritePackage) {
    throw "The site App Catalog already contains $packageFileName. Use -OverwritePackage only after reviewing the replacement package."
  }

  Write-Step 'Stage 1/4: Uploading the package file directly to the DOX Apps for SharePoint library.'
  $null = Add-PnPFile -Path $resolvedPackagePath -Folder 'AppCatalog' -Connection $connection -ErrorAction Stop
  $catalogPackageFile = Get-PnPFile -Url $catalogPackageUrl -AsListItem -Connection $connection -ErrorAction SilentlyContinue
  if ($null -eq $catalogPackageFile) {
    throw "SharePoint returned from the upload but $catalogPackageUrl does not exist. The package was not delivered; no propagation wait was started."
  }

  Write-Step 'Stage 2/4: Waiting up to 60 seconds for SharePoint to validate the uploaded package.'
  $validationDeadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
  $catalogApp = $null
  $registeredPackageVersion = $null
  do {
    $catalogApp = Get-PnPApp -Identity $solSolutionId -Scope Site -Connection $connection -ErrorAction SilentlyContinue
    $catalogVersionValue = if ($null -ne $catalogApp) { Get-PropertyValue -InputObject $catalogApp -Name 'AppCatalogVersion' } else { $null }
    if ($null -ne $catalogVersionValue) {
      $candidateVersion = $null
      if ([version]::TryParse([string]$catalogVersionValue, [ref]$candidateVersion)) {
        $registeredPackageVersion = $candidateVersion
      }
    }
    if ($null -eq $catalogApp -or $registeredPackageVersion -ne $expectedPackageVersion) { Start-Sleep -Seconds 3 }
  } while (($null -eq $catalogApp -or $registeredPackageVersion -ne $expectedPackageVersion) -and [DateTimeOffset]::UtcNow -lt $validationDeadline)
  if ($null -eq $catalogApp -or $registeredPackageVersion -ne $expectedPackageVersion) {
    $reportedVersion = if ($null -eq $registeredPackageVersion) { 'none' } else { [string]$registeredPackageVersion }
    throw "The file $catalogPackageUrl exists, but SharePoint reports catalog version $reportedVersion instead of packaged version $expectedPackageVersion after 60 seconds. Review that file's App Package Error Message in Apps for SharePoint; an older catalog record must not be published as the new build."
  }
  Write-Step "SharePoint validated exact catalog version $registeredPackageVersion."

  $packageError = Get-PropertyValue -InputObject $catalogApp -Name 'AppPackageErrorMessage'
  $isValidPackage = Get-PropertyValue -InputObject $catalogApp -Name 'IsValidAppPackage'
  if ($isValidPackage -eq $false -or -not [string]::IsNullOrWhiteSpace([string]$packageError)) {
    throw "SharePoint rejected the uploaded package. App Package Error Message: $packageError"
  }

  Write-Step 'Stage 3/4: Publishing the validated package as a DOX-scoped solution.'
  $null = Publish-PnPApp -Identity $solSolutionId -Scope Site -SkipFeatureDeployment -Force -Connection $connection
  $deploymentDeadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
  $deploymentReady = $false
  do {
    $catalogApp = Get-PnPApp -Identity $solSolutionId -Scope Site -Connection $connection -ErrorAction SilentlyContinue
    if ($null -ne $catalogApp) {
      $deployedVersionValue = Get-PropertyValue -InputObject $catalogApp -Name 'AppCatalogVersion'
      $deployedVersion = $null
      $hasExpectedVersion = $null -ne $deployedVersionValue -and
        [version]::TryParse([string]$deployedVersionValue, [ref]$deployedVersion) -and
        $deployedVersion -eq $expectedPackageVersion
      $currentVersionDeployed = Get-PropertyValue -InputObject $catalogApp -Name 'CurrentVersionDeployed'
      $deploymentReady = $catalogApp.Deployed -and $hasExpectedVersion -and $currentVersionDeployed -ne $false
    }
    if (-not $deploymentReady) { Start-Sleep -Seconds 3 }
  } while (-not $deploymentReady -and [DateTimeOffset]::UtcNow -lt $deploymentDeadline)
  if (-not $deploymentReady) {
    throw "SharePoint validated solution $solSolutionId version $expectedPackageVersion but did not mark that exact version as deployed within 60 seconds."
  }
  Write-Step "SharePoint reports exact version $expectedPackageVersion as deployed."

  Write-Step 'Stage 4/4: Waiting up to 60 seconds for the packaged JavaScript to reach DOX Client Side Assets.'
  $assetDeadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
  $missingClientScripts = @($expectedClientScripts)
  do {
    $missingClientScripts = @(
      $expectedClientScripts | Where-Object {
        $asset = Get-PnPFileInFolder -List 'Client Side Assets' -ItemName $_ -Connection $connection -ErrorAction SilentlyContinue
        $null -eq $asset
      }
    )
    if ($missingClientScripts.Count -gt 0) { Start-Sleep -Seconds 3 }
  } while ($missingClientScripts.Count -gt 0 -and [DateTimeOffset]::UtcNow -lt $assetDeadline)
  if ($missingClientScripts.Count -gt 0) {
    throw "The package is present and marked deployed, but SharePoint did not materialise these client assets: $($missingClientScripts -join ', '). The failure is in App Catalog asset deployment, not page propagation."
  }
  Write-Step "Verified packaged JavaScript in DOX Client Side Assets: $($expectedClientScripts -join ', ')."
} else {
  Write-Step "Uploading and publishing the package in the $AppCatalogScope App Catalog."
  $appParameters = @{
    Path = $resolvedPackagePath
    Scope = $AppCatalogScope
    Publish = $true
    SkipFeatureDeployment = $true
    Connection = $appCatalogConnection
    ErrorAction = 'Stop'
    Force = $true
  }
  if ($OverwritePackage) { $appParameters.Overwrite = $true }
  $null = Add-PnPApp @appParameters
  $catalogApp = Get-PnPApp -Identity $solSolutionId -Scope $AppCatalogScope -Connection $appCatalogConnection -ErrorAction Stop
}

if ($null -eq $existingPage) {
  Write-Step "Creating the single-web-part page SitePages/$pageNameValue.aspx."
  $page = Add-PnPPage -Name $pageNameValue -Title $PageTitle -LayoutType SingleWebPartAppPage -Connection $connection
} else {
  Write-Step "Converting the reviewed existing page SitePages/$pageNameValue.aspx to the full-page application layout."
  $null = Set-PnPPage -Identity $existingPage -LayoutType SingleWebPartAppPage -HeaderType None -CommentsEnabled:$false -Connection $connection
  $page = Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
}

Write-Step "Uploading the runtime configuration to $configurationSiteRelativeUrl."
$configurationLibraryIdentity = $configurationFolderValue.Split('/')[0]
$configurationLibrary = Get-PnPList -Identity $configurationLibraryIdentity -Includes 'EnableMinorVersions', 'EnableModeration', 'ForceCheckout' -Connection $connection -ErrorAction Stop
$fileParameters = @{
  Path = $resolvedConfigurationPath
  Folder = $configurationFolderValue
  NewFileName = $ConfigurationFileName
  Connection = $connection
  ErrorAction = 'Stop'
}
if ($configurationLibrary.ForceCheckout) {
  $fileParameters.Checkout = $true
  $fileParameters.CheckInComment = 'SOL DMS controlled runtime configuration deployment'
  $fileParameters.CheckinType = if ($configurationLibrary.EnableMinorVersions) { 'MinorCheckIn' } else { 'MajorCheckIn' }
}
if ($configurationLibrary.EnableMinorVersions) {
  $fileParameters.Publish = $true
  $fileParameters.PublishComment = 'SOL DMS controlled runtime configuration deployment'
} else {
  Write-Step "The $configurationLibraryIdentity library uses major versions only; uploading the configuration without the inapplicable Publish operation."
}
if ($configurationLibrary.EnableModeration) {
  $fileParameters.Approve = $true
  $fileParameters.ApproveComment = 'SOL DMS controlled runtime configuration deployment'
}
$null = Add-PnPFile @fileParameters

$pageComponents = @(Get-PnPPageComponent -Page $page -Connection $connection)
foreach ($legacyComponentId in $legacySolWebPartComponentIds) {
  $legacyComponents = @($pageComponents | Where-Object { Test-ComponentIdentity -Component $_ -ComponentId $legacyComponentId })
  foreach ($legacyComponent in $legacyComponents) {
    Write-Step "Removing legacy SOL web-part instance $legacyComponentId from the dedicated application page."
    $legacyInstanceId = Get-ComponentInstanceId -Component $legacyComponent
    $null = Remove-PnPPageComponent -Page $page -InstanceId $legacyInstanceId -Force -Connection $connection
  }
}
if ($legacySolWebPartComponentIds.Count -gt 0) {
  $page = Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
}

$existingSolComponent = Get-PnPPageComponent -Page $page -Connection $connection |
  Where-Object { Test-ComponentIdentity -Component $_ -ComponentId $solWebPartComponentId } |
  Select-Object -First 1
if ($null -ne $existingSolComponent) {
  Write-Step 'Updating the existing SOL web-part configuration.'
  $instanceId = Get-ComponentInstanceId -Component $existingSolComponent
  $null = Set-PnPPageWebPart -Page $page -Identity $instanceId -PropertiesJson $propertiesJson -Connection $connection
} else {
  Write-Step "Adding SOL Document Control directly by component ID $solWebPartComponentId."
  $componentDeadline = [DateTimeOffset]::UtcNow.AddSeconds($ComponentWaitSeconds)
  $nextComponentUpdate = [DateTimeOffset]::UtcNow.AddSeconds(30)
  $componentAdded = $false
  $lastComponentError = $null
  do {
    try {
      $page = Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
      $null = Add-PnPPageWebPart -Page $page -Component ([string]$solWebPartComponentId) -WebPartProperties $propertiesJson -Order 1 -Connection $connection -ErrorAction Stop
      $componentAdded = $true
    } catch {
      $lastComponentError = $_.Exception.Message
      $page = Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
      $componentAdded = $null -ne (
        Get-PnPPageComponent -Page $page -Connection $connection |
          Where-Object { Test-ComponentIdentity -Component $_ -ComponentId $solWebPartComponentId } |
          Select-Object -First 1
      )
      if (-not $componentAdded) {
        if ([DateTimeOffset]::UtcNow -ge $nextComponentUpdate) {
          $remainingSeconds = [Math]::Max(0, [Math]::Ceiling(($componentDeadline - [DateTimeOffset]::UtcNow).TotalSeconds))
          Write-Step "Direct component insertion is not ready; retrying for up to $remainingSeconds more seconds. Last SharePoint response: $lastComponentError"
          $nextComponentUpdate = [DateTimeOffset]::UtcNow.AddSeconds(30)
        }
        Start-Sleep -Seconds 5
      }
    }
  } while (-not $componentAdded -and [DateTimeOffset]::UtcNow -lt $componentDeadline)
  if (-not $componentAdded) {
    throw "SharePoint deployed package $solSolutionId version $expectedPackageVersion and its client asset, but rejected direct insertion of component $solWebPartComponentId for $ComponentWaitSeconds seconds. Last SharePoint response: $lastComponentError"
  }
  Write-Step "Added exact component $solWebPartComponentId to the full-page host."
}

Write-Step 'Publishing the SharePoint page.'
$null = Set-PnPPage -Identity $page -Title $PageTitle -LayoutType SingleWebPartAppPage -HeaderType None -CommentsEnabled:$false -Publish -Connection $connection

$pageUrl = "$($web.Url.TrimEnd('/'))/SitePages/$pageNameValue.aspx"
$receipt = [ordered]@{
  product = 'SOL Document Control'
  installedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  targetSiteUrl = $web.Url
  pageUrl = $pageUrl
  appCatalogScope = $AppCatalogScope
  appCatalogUrl = if ($null -ne $resolvedAppCatalogUrl) { $resolvedAppCatalogUrl.AbsoluteUri } else { $web.Url }
  packageSha256 = $packageHash
  componentId = [string]$solWebPartComponentId
  runtimeConfigurationUrl = $configurationSiteRelativeUrl
  stagedUnconfigured = $AllowUnconfigured.IsPresent
}

if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
  $receiptDirectory = Split-Path -Parent $resolvedReceiptPath
  if (-not [string]::IsNullOrWhiteSpace($receiptDirectory) -and -not (Test-Path -LiteralPath $receiptDirectory)) {
    $null = New-Item -ItemType Directory -Path $receiptDirectory
  }
  $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resolvedReceiptPath -Encoding utf8NoBOM
  Write-Step "Wrote the local deployment receipt to $resolvedReceiptPath."
}

Write-Step "Deployment complete. Open $pageUrl"
[pscustomobject]$receipt
