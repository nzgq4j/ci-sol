# SOL DMS SharePoint deployment handoff

Status updated: 26 August 2026 (Europe/London)

Current state: the distinct site-scoped package has been built and fully verified locally. It has not yet been deployed to DOX.

## Objective

Deploy the production SOL DMS SPFx web part to the DOX SharePoint site and publish it on:

- Target site: `https://propfound.sharepoint.com/sites/DOX`
- Intended page: `https://propfound.sharepoint.com/sites/DOX/SitePages/SOL-Document-Control.aspx`
- Entra application/client ID: `56ac1ccd-e448-42f3-8e9d-230c56f194cb`
- Tenant ID supplied by the administrator: `9fd1307f-3666-4779-b6de-0d596aaf093a`

No tenant secret or certificate is stored in this repository.

## Confirmed live state

The original package was successfully uploaded to the tenant App Catalog at `https://propfound.sharepoint.com/sites/appcatalog`.

The tenant App Catalog reports the original package as:

- Title: `sol-dms-client-side-solution`
- Package/solution ID: `ce95e19a-a3c9-4240-b156-9daca79c0872`
- Version: `1.0.0.0`
- Deployed: `True`
- Current version deployed: `True`
- Enabled: `True`
- Valid package: `True`
- Skip feature deployment: `True`
- Package error: none

The original tenant manifest exists and is enabled, but DOX does not return its web-part component ID `7c36e2e7-eba7-43e1-886f-7b7a3d848c29` from `/_api/web/GetClientSideWebParts`. DOX returns 286 other components.

The target page exists but is visually empty because the installer timed out before it could add the missing component to the page.

The SharePoint connector was used to confirm the live DOX site and these document libraries:

- Controlled Documents
- Operational Records
- Templates
- Documents

It also confirmed the tenant App Catalog site and its Client Side Assets library. The connector exposes site, drive and file operations through Microsoft Graph; it does not expose SPFx App Catalog deployment or modern page canvas editing. PnP PowerShell remains necessary for those operations.

## Disproved approaches

Do not repeat these steps:

1. Waiting longer for tenant-wide component propagation. Multiple waits of 180 and 600 seconds did not expose the component.
2. Treating `DenyAddAndCustomizePages` as the cause. The site was temporarily changed with `Set-PnPSite -NoScriptSite:$false`, but the component remained absent. The package manifest also explicitly allows the component to be returned when custom script is disabled.
3. Installing the already-deployed tenant package into DOX with `Install-PnPApp`. This completed without making the component available.
4. Re-uploading or merely re-verifying the same tenant package identity and polling again.

## Replacement strategy now implemented in the installer

`deployment/Install-SolDms.ps1` now supports a materially different recovery path:

- `-AppCatalogScope Site`
- `-EnsureSiteCollectionAppCatalog`
- `-TenantAdminUrl https://propfound-admin.sharepoint.com`

This path:

1. Connects to the SharePoint admin site.
2. Idempotently enables a site-collection App Catalog on DOX.
3. Uploads and publishes the reviewed SPFx package into the DOX-scoped App Catalog.
4. Resolves the web part from DOX's own component registry.
5. Updates the existing `SOL-Document-Control.aspx` page and publishes it.

The PowerShell parser/command-presence test passed after this site-catalog implementation. A `-WhatIf` run also produced the correct site-scoped deployment plan.

## Distinct replacement package

There is already an original `1.0.0.0` package with the old identities in the tenant App Catalog. To avoid SharePoint resolving the site-scoped upload back to that exact tenant package, the local source has just been changed to a distinct, stable package identity and higher version:

- New solution ID: `6b30f157-0d3c-4988-8843-eb6e1c3b8acd`
- New web-part component ID: `772c04cc-f5af-4485-8e48-d4de27923fa0`
- New feature ID: `407c47af-65fa-4015-afef-bf750d7481f2`
- New package version: `1.0.1.0`
- New npm project version: `1.0.1`

The replacement package was built after changing these source files:

- `deployment/Install-SolDms.ps1`
- `sharepoint/sol-dms/config/package-solution.json`
- `sharepoint/sol-dms/src/webparts/solDms/SolDmsWebPart.manifest.json`
- `sharepoint/sol-dms/package.json`
- `sharepoint/sol-dms/package-lock.json`
- `sharepoint/sol-dms/teams/772c04cc-f5af-4485-8e48-d4de27923fa0_color.png`
- `sharepoint/sol-dms/teams/772c04cc-f5af-4485-8e48-d4de27923fa0_outline.png`

The current artifact is `sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg`, SHA-256 `FF711A1C3A992D331A4F8D052C0797719613E7B1B95676C85F7ED14CC4E7AD49`.

## Verification completed

- TypeScript type-check passed.
- 10 unit/integration tests passed across three test files.
- Production Vite build passed.
- SPFx Heft production build and package validation passed.
- The `.sppkg` contains the new solution, feature and component identities and version `1.0.1.0`.
- All 20 end-user, team-administrator and platform-administrator navigation views rendered.
- Search, document detail, acknowledgement, approval, exception resolution and integration-change interactions passed.
- Drawer focus containment/restoration and the 390px no-overflow/inert-navigation checks passed.
- Visual comparison completed with no reported verification issues.

The machine currently reports Node `24.17.0`, while the repository declares Node `>=22.14.0 <23`. The build passed on Node 24, but the declared portable toolchain remains Node 22 and should be used for reproducible builds.

## Exact next steps

Resume from the repository root, then:

1. Re-run `deployment/Test-InstallSolDmsScript.ps1` and `git diff --check` after any future source changes.
2. Run one real site-scoped install. Remove stale keys from the existing `$installParameters` hashtable before invoking the installer:

   ```powershell
   $installParameters.Remove('WhatIf')
   $installParameters.Remove('RepairTargetSiteAvailability')
   $installParameters.Remove('TenantAppCatalogUrl')
   $installParameters.Remove('SkipPackageUpload')
   $installParameters.Remove('OverwritePackage')

   $installParameters['AppCatalogScope'] = 'Site'
   $installParameters['TenantAdminUrl'] = 'https' + '://' + 'propfound-admin.sharepoint.com'
   $installParameters['EnsureSiteCollectionAppCatalog'] = $true
   $installParameters['UpdateExistingPage'] = $true
   $installParameters['ComponentWaitSeconds'] = 600

   & '.\deployment\Install-SolDms.ps1' @installParameters
   ```

3. Open the intended page and confirm that the SOL DMS shell renders.
4. Restore `DenyAddAndCustomizePages` to its tenant-managed/default state if the earlier manual no-script change has not already reverted. The new deployment does not depend on custom script being enabled.

## Known tenant configuration still outstanding

The current `deployment/runtime-config.example.json` leaves all 27 production operations unconfigured. `-AllowUnconfigured` permits deployment of the shell only; it does not create a production data integration. Real endpoint/configuration values are still required for SharePoint, Graph, Entra ID, Power Automate and Purview service boundaries. These values cannot be derived from the repository and must not be invented.

The deployment should therefore be considered a host/package repair first. Production business operations will remain unavailable until a reviewed production runtime configuration is supplied.
