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
  return (Get-PropertyValue -InputObject $Component -Name 'Name') -eq 'SolDms' -or
    (Get-PropertyValue -InputObject $Component -Name 'Title') -eq 'SOL Document Control'
}

function Get-ComponentInstanceId {
  param([Parameter(Mandatory)][object]$Component)
  foreach ($propertyName in @('InstanceId', 'Id')) {
    $value = Get-PropertyValue -InputObject $Component -Name $propertyName
    if ($null -ne $value) { return $value }
  }
  throw 'The existing SOL web-part instance does not expose an instance identifier.'
}

$resolvedPackagePath = Resolve-RequiredFile -Path $PackagePath -Description 'SPFx package' -Extension '.sppkg'
$resolvedConfigurationPath = Resolve-RequiredFile -Path $RuntimeConfigurationPath -Description 'Runtime configuration' -Extension '.json'
$null = Read-RuntimeConfiguration -Path $resolvedConfigurationPath -SiteUrl $TargetSiteUrl -PermitMissingOperations $AllowUnconfigured.IsPresent

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

Write-Step "Connecting interactively to $($TargetSiteUrl.AbsoluteUri)."
$connection = Connect-PnPOnline -Url $TargetSiteUrl.AbsoluteUri -Interactive -ClientId $PnPClientId -ReturnConnection -ValidateConnection
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
  $appCatalogConnection = Connect-PnPOnline -Url $resolvedAppCatalogUrl.AbsoluteUri -Interactive -ClientId $PnPClientId -ReturnConnection -ValidateConnection
}

$adminConnection = $null
if ($EnsureSiteCollectionAppCatalog) {
  Write-Step "Connecting directly to the tenant administration site at $($TenantAdminUrl.AbsoluteUri)."
  $adminConnection = Connect-PnPOnline -Url $TenantAdminUrl.AbsoluteUri -Interactive -ClientId $PnPClientId -ReturnConnection -ValidateConnection

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
  Write-Step "Verifying the existing package in the $AppCatalogScope App Catalog."
  $catalogApp = Get-PnPApp -Identity $solSolutionId -Scope $AppCatalogScope -Connection $appCatalogConnection -ErrorAction Stop
  if ($null -eq $catalogApp -or -not $catalogApp.Deployed) {
    throw "SOL DMS package $solSolutionId is not deployed in the $AppCatalogScope App Catalog. Remove -SkipPackageUpload and deploy the reviewed package."
  }
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
  Write-Step "Updating the reviewed existing page SitePages/$pageNameValue.aspx."
  $page = $existingPage
}

Write-Step 'Waiting for the SOL web part to become available in the target site.'
$deadline = [DateTimeOffset]::UtcNow.AddSeconds($ComponentWaitSeconds)
$nextWaitUpdate = [DateTimeOffset]::UtcNow.AddSeconds(30)
$availableComponent = $null
do {
  # Reload the page on every poll. PnP page objects cache the available-component
  # collection, so polling one instance can otherwise miss a newly propagated app.
  $page = Get-PnPPage -Identity $pageNameValue -Connection $connection -ErrorAction Stop
  $availableComponents = if ($null -ne (Get-Command -Name 'Get-PnPAvailablePageComponents' -ErrorAction SilentlyContinue)) {
    Get-PnPAvailablePageComponents -Page $page -Connection $connection
  } else {
    Get-PnPPageComponent -Page $page -ListAvailable -Connection $connection
  }
  $availableComponent = $availableComponents |
    Where-Object { Test-ComponentIdentity -Component $_ -ComponentId $solWebPartComponentId } |
    Select-Object -First 1
  if ($null -eq $availableComponent) {
    if ([DateTimeOffset]::UtcNow -ge $nextWaitUpdate) {
      $remainingSeconds = [Math]::Max(0, [Math]::Ceiling(($deadline - [DateTimeOffset]::UtcNow).TotalSeconds))
      Write-Step "The component is still propagating; waiting for up to $remainingSeconds more seconds."
      $nextWaitUpdate = [DateTimeOffset]::UtcNow.AddSeconds(30)
    }
    Start-Sleep -Seconds 5
  }
} while ($null -eq $availableComponent -and [DateTimeOffset]::UtcNow -lt $deadline)
if ($null -eq $availableComponent) {
  throw "SOL Document Control component $solWebPartComponentId was not available after $ComponentWaitSeconds seconds. Check App Catalog deployment and rerun with the appropriate overwrite/update switches."
}

Write-Step "Uploading the runtime configuration to $configurationSiteRelativeUrl."
$fileParameters = @{
  Path = $resolvedConfigurationPath
  Folder = $configurationFolderValue
  NewFileName = $ConfigurationFileName
  Publish = $true
  Connection = $connection
  ErrorAction = 'Stop'
}
$null = Add-PnPFile @fileParameters

$existingSolComponent = Get-PnPPageComponent -Page $page -Connection $connection |
  Where-Object { Test-ComponentIdentity -Component $_ -ComponentId $solWebPartComponentId } |
  Select-Object -First 1
if ($null -ne $existingSolComponent) {
  Write-Step 'Updating the existing SOL web-part configuration.'
  $instanceId = Get-ComponentInstanceId -Component $existingSolComponent
  $null = Set-PnPPageWebPart -Page $page -Identity $instanceId -PropertiesJson $propertiesJson -Connection $connection
} else {
  Write-Step 'Adding the SOL Document Control web part.'
  $null = Add-PnPPageWebPart -Page $page -Component $availableComponent -WebPartProperties $propertiesJson -Order 1 -Connection $connection
}

Write-Step 'Publishing the SharePoint page.'
$null = Set-PnPPage -Identity $page -Title $PageTitle -CommentsEnabled:$false -Publish -Connection $connection

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
