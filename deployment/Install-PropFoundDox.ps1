#requires -Version 5.1

<#
.SYNOPSIS
Launches the reviewed SOL DMS installation for the PropFound DOX site.

.DESCRIPTION
Supplies the known, non-secret DOX deployment coordinates to the portable SOL
DMS installer. Install-SolDms.ps1 handles the transition from Windows
PowerShell 5.1 to PowerShell 7.4 or later.
#>

[CmdletBinding()]
param(
  [switch]$WhatIf
)

$installerPath = Join-Path $PSScriptRoot 'Install-SolDms.ps1'
$runtimeConfigurationPath = Join-Path $PSScriptRoot 'runtime-config.example.json'
$receiptPath = Join-Path $PSScriptRoot '../deployment-receipts/sol-dms-production.json'

$parameters = @{
  TargetSiteUrl = [uri]'https://propfound.sharepoint.com/sites/DOX'
  TenantAdminUrl = [uri]'https://propfound-admin.sharepoint.com'
  PnPClientId = [guid]'56ac1ccd-e448-42f3-8e9d-230c56f194cb'
  RuntimeConfigurationPath = $runtimeConfigurationPath
  AppCatalogScope = 'Site'
  EnsureSiteCollectionAppCatalog = $true
  AllowUnconfigured = $true
  UpdateExistingPage = $true
  OverwritePackage = $true
  ComponentWaitSeconds = 600
  ReceiptPath = $receiptPath
  WhatIf = $WhatIf
}

& $installerPath @parameters
