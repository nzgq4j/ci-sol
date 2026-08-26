# SOL DMS SharePoint deployment handoff

Status updated: 26 August 2026 (Europe/London)

Current state: site-scoped version `1.0.2.0` is deployed in DOX and its exact packaged JavaScript is present in Client Side Assets. Live inspection subsequently showed that `SOL-Document-Control.aspx` was published with an empty standard-page canvas: the previous installer reused a stale page object during publication and overwrote the component/layout it had just saved. Version `1.0.3.0` is built locally with a fail-fast page verification and a safe SharePoint identity bootstrap; it has not yet been deployed. Production tenant-service configuration remains outstanding.

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

The original target page exists. A separate standard page, `SOL-Document-Control-Page.aspx`, was also manually created and contains SOL web-part content inside the normal SharePoint site shell. The standard page is not the intended production host.

The DOX web-part toolbox currently shows two entries with the same title because the original tenant-wide package and the replacement site-scoped package use different component identities. They are not two role experiences. The tenant-wide package remains installed for other sites; do not retract it until its usage has been reviewed.

The last live site-scoped package deployment reports:

- Package version: `1.0.2.0`
- Package SHA-256: `89B01D960E63F9DA9DE8CFCD771463E9DDB152D52D9A9B2C879BC260C79349F3`
- Component ID: `772c04cc-f5af-4485-8e48-d4de27923fa0`
- Client asset: `sol-dms-web-part_2edf98442435994ca350.js`
- Runtime manifest: `SiteAssets/SOL-DMS/sol-dms-runtime.json`
- Intended page: `https://propfound.sharepoint.com/sites/DOX/SitePages/SOL-Document-Control.aspx` (currently published empty; repair pending)
- Receipt: `deployment-receipts/sol-dms-production.json`
- Staged/unconfigured: `True`

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
4. Adds the exact reviewed component ID directly to the dedicated application page, avoiding stale page-component discovery caches.
5. Updates the existing `SOL-Document-Control.aspx` page and publishes it.

The PowerShell parser/command-presence test passed after this site-catalog implementation. A `-WhatIf` run also produced the correct site-scoped deployment plan.

## Distinct replacement package

There is already an original `1.0.0.0` package with the old identities in the tenant App Catalog. To avoid SharePoint resolving the site-scoped upload back to that exact tenant package, the local source has just been changed to a distinct, stable package identity and higher version:

- New solution ID: `6b30f157-0d3c-4988-8843-eb6e1c3b8acd`
- New web-part component ID: `772c04cc-f5af-4485-8e48-d4de27923fa0`
- New feature ID: `407c47af-65fa-4015-afef-bf750d7481f2`
- Current corrected package version: `1.0.3.0`
- Current corrected npm project version: `1.0.3`

The replacement package was built after changing these source files:

- `deployment/Install-SolDms.ps1`
- `sharepoint/sol-dms/config/package-solution.json`
- `sharepoint/sol-dms/src/webparts/solDms/SolDmsWebPart.manifest.json`
- `sharepoint/sol-dms/package.json`
- `sharepoint/sol-dms/package-lock.json`
- `sharepoint/sol-dms/teams/772c04cc-f5af-4485-8e48-d4de27923fa0_color.png`
- `sharepoint/sol-dms/teams/772c04cc-f5af-4485-8e48-d4de27923fa0_outline.png`

The current artifact is `sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg`, SHA-256 `878CCAD655DF9ACDA91EC0765EC121CC67CDA06010B30A1B5B7147DD9B7E3EB1`.

Version `1.0.2.0` fixes the SharePoint-only styling regression by exporting the shared design stylesheet through an explicit SPFx global-style module. The package-integrity test now rejects builds that rename `.app-shell` as a CSS-module selector. Closed drawers also use the native `hidden` state, so a missing stylesheet cannot expose inactive “Loading document evidence…” content again.

The upgrade gate also now requires SharePoint to report the exact packaged version before publishing it. This prevents an existing `1.0.1.0` catalog record from satisfying the validation poll for `1.0.2.0`. Client asset verification searches the full Client Side Assets library recursively instead of assuming that SharePoint materialises files at its root.

The installer now creates or converts `SOL-Document-Control.aspx` to `SingleWebPartAppPage`, disables its header and comments, and publishes exactly that full-page host. SharePoint can retain the Microsoft 365 suite bar, but the DOX site header, left navigation, page authoring surface and comments are not part of the published SOL workspace.

Version `1.0.3.0` corrects the page publication sequence. It reloads the server page after component insertion, verifies the exact SOL component before publication, publishes by filename without resaving a stale canvas, and then verifies both the component and `SingleWebPartAppPage` layout after publication. The installer now refuses to report success for an empty or standard-layout page.

The SPFx host also supplies the signed-in SharePoint identity as a fail-closed end-user baseline. Blank optional service operations no longer blank the entire application; they produce explicit setup issues while governed writes remain unavailable. Team-administrator and platform-administrator roles are not inferred from site ownership and still require approved Entra role mappings.

## Verification completed

- TypeScript type-check passed.
- 12 unit/integration tests passed across four test files.
- Production Vite build passed.
- SPFx Heft production build and package validation passed.
- The `.sppkg` contains the replacement solution, feature and component identities and version `1.0.3.0`.
- The packaged JavaScript contains the global `.app-shell` and `.sidebar` design selectors and contains no hashed `.app-shell_*` selector.
- All 20 end-user, team-administrator and platform-administrator navigation views rendered.
- Search, document detail, acknowledgement, approval, exception resolution and integration-change interactions passed.
- Drawer focus containment/restoration and the 390px no-overflow/inert-navigation checks passed.
- Visual comparison completed with no reported verification issues.

The machine currently reports Node `24.17.0`, while the repository declares Node `>=22.14.0 <23`. The build passed on Node 24, but the declared portable toolchain remains Node 22 and should be used for reproducible builds.

## Exact next steps

Resume from the repository root, then:

1. Deploy version `1.0.3.0` with `pwsh -NoProfile -File '.\deployment\Install-PropFoundDox.ps1'`. Do not use `-ResumePageProvisioning` for this upgrade because the new package must be uploaded.
2. Require the new `Verified published full-page host` message before accepting success.
3. Open `https://propfound.sharepoint.com/sites/DOX/SitePages/SOL-Document-Control.aspx` and use `Ctrl+F5` once to bypass cached assets. Do not use `SOL-Document-Control-Page.aspx`; it is the manually created standard page.
4. Supply and approve the production tenant configuration described in `docs/tenant-configuration.md`, replace the staged runtime manifest, and validate each role with representative accounts.
5. Restore `DenyAddAndCustomizePages` to its tenant-managed/default state if the earlier manual no-script change has not already reverted. The deployment does not depend on custom script being enabled.

## Known tenant configuration still outstanding

The current `deployment/runtime-config.example.json` leaves all 27 production operations unconfigured. Version `1.0.3.0` uses the signed-in SharePoint identity to keep the safe end-user shell available, but it does not fabricate document, evidence, role, workflow, retention or assurance data. Real endpoint/configuration values are still required for SharePoint, Graph, Entra ID, Power Automate and Purview service boundaries. These values cannot be derived from the repository and must not be invented.

The deployment should therefore be considered a host/package repair first. Production business operations will remain unavailable until a reviewed production runtime configuration is supplied.
