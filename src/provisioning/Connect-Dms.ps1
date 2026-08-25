#Requires -Version 7.2
<#
.SYNOPSIS
    Opens the PnP connections a DMS deployment needs, using values from configuration.
.DESCRIPTION
    Provisioning needs two connections against different endpoints:

      * the DMS SITE, for columns, content types, libraries, lists and views, and
      * the SharePoint ADMIN endpoint, for tenant-scoped settings such as the site sharing
        capability and site creation.

    Passing a site connection where an admin connection is required fails with
    "The provided connection through -Connection holds no SharePoint context", which does not
    obviously point at the cause. This script opens both correctly and returns them together.

    Tenant ID, site URL and Entra client ID are read from config/environments.json rather than typed,
    so a deployment cannot silently target the wrong tenant (PRD ADM-005).

    No credential is handled here. Authentication is interactive: PnP opens a browser and the signed-in
    user's own permissions apply.
.PARAMETER Environment
    Environment key to connect to.
.PARAMETER ConfigPath
    Configuration directory.
.PARAMETER SiteOnly
    Open only the site connection. Tenant-scoped actions will be reported as Blocked.
.EXAMPLE
    $conn = ./Connect-Dms.ps1 -Environment dev
    ./Deploy-Dms.ps1 -Environment dev -Mode Plan -Connection $conn.Site -TenantAdminConnection $conn.Admin
.OUTPUTS
    PSCustomObject with Site and Admin connections and the resolved settings used.
#>
[CmdletBinding()]
param(
    [Parameter()][ValidateSet('dev','test','prod')][string]$Environment = 'dev',
    [Parameter()][string]$ConfigPath,
    [Parameter()][switch]$SiteOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }

$config   = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$tenantId = $config.Tenant.tenantId
$siteUrl  = $config.Environment.dmsSiteUrl
$adminUrl = $config.Tenant.sharePointAdminUrl
$clientId = Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'entraClientId' -Default ''

# Fail with the specific missing value rather than letting PnP report a generic auth error.
$missing = @()
if ("$tenantId" -like '*REQUIRES_*' -or [string]::IsNullOrWhiteSpace("$tenantId")) { $missing += 'tenant.tenantId' }
if ("$siteUrl"  -like '*REQUIRES_*' -or [string]::IsNullOrWhiteSpace("$siteUrl"))  { $missing += "environments.$Environment.dmsSiteUrl" }
if ("$clientId" -like '*REQUIRES_*' -or [string]::IsNullOrWhiteSpace("$clientId")) { $missing += "environments.$Environment.entraClientId" }
if ($missing.Count -gt 0) {
    throw @"
Cannot connect: $($missing -join ', ') is not set in config/environments.json.

Register an app for interactive login and record its client id:

  Register-PnPEntraIDAppForInteractiveLogin ``
    -ApplicationName 'PnP-DMS-Interactive' ``
    -Tenant $tenantId ``
    -SharePointDelegatePermissions AllSites.FullControl ``
    -GraphDelegatePermissions Group.Read.All

See docs/DEPLOYMENT_RUNBOOK.md section 2.
"@
}

if (-not (Get-Module -ListAvailable -Name 'PnP.PowerShell')) {
    throw "PnP.PowerShell is not installed. Run: Install-Module PnP.PowerShell -MinimumVersion 2.12.0 -Scope CurrentUser"
}

Write-Information ("Connecting to {0} as the signed-in user (interactive)" -f $siteUrl) -InformationAction Continue
$site = Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -Tenant $tenantId -ReturnConnection

$admin = $null
if (-not $SiteOnly) {
    Write-Information ("Connecting to {0}" -f $adminUrl) -InformationAction Continue
    try {
        $admin = Connect-PnPOnline -Url $adminUrl -Interactive -ClientId $clientId -Tenant $tenantId -ReturnConnection
    } catch {
        # A missing admin connection is not fatal: tenant-scoped actions are reported as Blocked
        # rather than attempted, so the rest of the deployment still runs.
        Write-Warning ("Could not connect to the admin endpoint: {0}" -f (Protect-DmsSensitiveText -Text $_.Exception.Message))
        Write-Warning "Tenant-scoped actions (site sharing capability) will be reported as Blocked. This needs the SharePoint Administrator role."
    }
}

Write-Information "" -InformationAction Continue
Write-Information ("site  : {0}" -f $(if ($site)  { $site.Url }  else { '(failed)' })) -InformationAction Continue
Write-Information ("admin : {0}" -f $(if ($admin) { $admin.Url } else { '(not connected)' })) -InformationAction Continue
Write-Information "" -InformationAction Continue
Write-Information "Next:" -InformationAction Continue
Write-Information ('  $conn = ./src/provisioning/Connect-Dms.ps1 -Environment {0}' -f $Environment) -InformationAction Continue
Write-Information ('  ./src/provisioning/Deploy-Dms.ps1 -Environment {0} -Mode Plan -Connection $conn.Site -TenantAdminConnection $conn.Admin' -f $Environment) -InformationAction Continue

return [PSCustomObject]@{
    Site        = $site
    Admin       = $admin
    Environment = $Environment
    SiteUrl     = $siteUrl
    AdminUrl    = $adminUrl
    TenantId    = $tenantId
    ClientId    = $clientId
}
