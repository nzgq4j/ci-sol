# Install SOL DMS in another SharePoint environment

## Supported target

This deployment package targets **SharePoint Online**. It is not compatible with on-premises SharePoint Server without a separate implementation against the much older SPFx versions supported by those products.

## Prerequisites

- a SharePoint Online App Catalog and permission to upload/deploy an `.sppkg`
- a modern page or full-page host in the target site
- Node.js 22.14.x through 22.x to rebuild the package
- tenant-owned production services implementing the operation contracts in `src/services/contracts.ts`
- approved Entra API permissions for each endpoint using the `entra` transport
- approved SharePoint sites, lists/libraries, content types, groups, workflows, retention labels and evidence stores

## Build once

From the repository root:

```powershell
npm install
npm run sync:sharepoint
npm --prefix sharepoint/sol-dms install
npm --prefix sharepoint/sol-dms run build
```

Upload `sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg` to the target tenant's App Catalog and deploy it. Because tenant-wide availability is enabled, a tenant administrator decides which sites may add the component.

## Configure each target environment

1. Copy `deployment/runtime-config.example.json` to a protected, readable location such as a governed Site Assets library in the target site.
2. Replace each empty operation with the environment's real service endpoint. Empty values intentionally yield an **unconfigured** state.
3. For each endpoint, use one of these shapes:

```json
{ "url": "/sites/target/_api/tenant-owned-route", "auth": "sharePoint" }
```

```json
{ "url": "https://api.organisation.example/sol/documents", "auth": "entra", "resource": "api://tenant-approved-application-id-uri" }
```

The strings above are illustrative shapes, not deployable tenant values. Never place bearer tokens, client secrets, Power Automate signed trigger URLs, cookies, or API keys in the manifest.

4. Add the **SOL Document Control** web part to a page.
5. In its property pane, set **Runtime configuration URL** to the site-relative or same-origin URL of the JSON manifest.
6. Have the target tenant administrator grant the SharePoint Online Client Extensibility principal only the scopes required by each configured Entra-protected resource. These permission names and scopes are tenant inputs and are intentionally not predeclared in the generic package. Use the tenant's approved API-access/consent process and retain the approval evidence before enabling an `entra` endpoint.
7. Validate every role with representative accounts. Hiding a route is not authorisation: production services and SharePoint permissions must deny unauthorised calls.

## Automated PowerShell installation

The repository includes [Install-SolDms.ps1](Install-SolDms.ps1), which performs the App Catalog upload, runtime-manifest upload, page creation, web-part configuration and page publication.

PnP.PowerShell requires PowerShell 7.4 or later. The installer can nevertheless be launched from Windows PowerShell 5.1: it detects the older host and relaunches itself with `pwsh.exe`, preserving the supplied parameters. PowerShell 7.4+, PnP.PowerShell 3.4.1+ and a tenant-approved Entra application client ID must be installed:

```powershell
Install-Module PnP.PowerShell -RequiredVersion 3.4.1 -Scope CurrentUser
```

First run a non-mutating preview with real tenant inputs:

```powershell
& ./deployment/Install-SolDms.ps1 `
  -TargetSiteUrl 'https://<tenant>.sharepoint.com/sites/<target-site>' `
  -TenantAppCatalogUrl 'https://<tenant>.sharepoint.com/sites/<app-catalog>' `
  -PnPClientId '<tenant-approved-pnp-client-id>' `
  -RuntimeConfigurationPath './deployment/sol-dms-runtime.production.json' `
  -ReceiptPath './deployment-receipts/sol-dms-production.json' `
  -WhatIf
```

Then rerun without `-WhatIf`. The example strings are placeholders, not tenant values. By default the script stops rather than overwrite an existing package, configuration file, page or receipt. Reviewed upgrades must explicitly use the applicable `-OverwritePackage`, `-OverwriteConfiguration`, `-UpdateExistingPage` or `-OverwriteReceipt` switches.

For tenant-scoped deployment, the installer uses a dedicated connection to the tenant App Catalog so that PnP does not attempt package operations through the target site's no-script context. `-TenantAppCatalogUrl` is optional when the signed-in account can discover the catalog, but supplying the reviewed URL makes the deployment target explicit. Site-scoped deployments continue to use the target-site connection and must not supply this parameter.

If an earlier run deployed the reviewed package but stopped before the web part was added, resume with `-SkipPackageUpload -UpdateExistingPage`. The installer verifies that the package is deployed, reloads the page during every component-availability poll to avoid stale PnP component caches, and then completes configuration and publication. Do not combine `-SkipPackageUpload` with `-OverwritePackage`.

When tenant-wide deployment is healthy in the App Catalog but SharePoint does not expose the component on the target site, use a site-scoped deployment instead of repeatedly polling the tenant registry. Add `-AppCatalogScope Site -EnsureSiteCollectionAppCatalog -TenantAdminUrl 'https://<tenant>-admin.sharepoint.com'`. The installer idempotently enables a site-collection App Catalog, uploads the reviewed package there, and registers the component directly for that site collection. This requires SharePoint Administrator access plus site-collection administrator rights on the tenant App Catalog and target site.

The installer rejects empty operations and obvious secret-bearing fields or signed URLs. `-AllowUnconfigured` permits a staged installation that displays the application's unconfigured state; it is not a production-ready deployment.

The script does not grant API permissions, provision the tenant service APIs, decide group membership, create the controlled-document information architecture, publish Power Automate solutions or create Purview labels. Those remain approved tenant prerequisites.

## Upgrade and rollback

Use the same solution ID for upgrades. Increment the solution version in `sharepoint/sol-dms/config/package-solution.json`, rebuild, upload the new package, and preserve the prior `.sppkg` plus runtime manifest for rollback. Treat the runtime manifest as controlled configuration and record its change evidence.

## Configuration still required

The repository cannot determine the target tenant's business and security decisions. [docs/tenant-configuration.md](../docs/tenant-configuration.md) is the installation gate; do not infer those values from the demo adapter.
