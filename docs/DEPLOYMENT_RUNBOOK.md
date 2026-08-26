# Deployment Runbook

## 0. Current status

**Nothing has been deployed to any tenant.** No site, library, list, column, content type, group,
label or flow has been created. This runbook is the procedure to do so once access exists.

Target test bed: `https://propfound.sharepoint.com/sites/DOX` (configured in `config/environments.json`).

## 1. Prerequisites

| # | Prerequisite | Status |
|---|---|---|
| 1 | PowerShell 7.2+ | Available |
| 2 | `PnP.PowerShell` ≥ 2.12.0 | **Required on the deploying workstation** |
| 3 | Entra tenant ID in `config/environments.json` | **Outstanding — blocks Apply** |
| 4 | SharePoint Administrator role | **Outstanding** |
| 5 | PnP Entra application consented in the tenant | **Outstanding** |
| 6 | Entra role groups created through identity governance | **Outstanding** (deliberately not automated) |
| 7 | Offline validation passing | Passing |
| 8 | Rollback plan reference | `docs/BACKUP_RECOVERY_PLAN.md#rollback` |

## 2. One-time tenant setup

PnP.PowerShell 2.x removed the built-in multi-tenant application, so **every** connection needs a
`-ClientId` belonging to an app registered in your own tenant. Register one first.

There are two registration cmdlets and they are not interchangeable:

| Cmdlet | Creates | Use for | Privilege needed |
|---|---|---|---|
| `Register-PnPEntraIDAppForInteractiveLogin` | Delegated app, redirect URI `http://localhost`, **no certificate** | Interactive deployment by a person | Tenant permits user app registration, **or** Application Developer / Application Administrator / Cloud Application Administrator / Global Administrator |
| `Register-PnPEntraIDApp` | App-only registration **plus a certificate** | Unattended CI/CD | Global Administrator (application permissions need admin consent) |

For a pilot deployment run by a person, use the first.

```powershell
Install-Module PnP.PowerShell -MinimumVersion 2.12.0 -Scope CurrentUser

Register-PnPEntraIDAppForInteractiveLogin `
  -ApplicationName "PnP-DMS-Interactive" `
  -Tenant 9fd1307f-3666-4779-b6de-0d596aaf093a `
  -SharePointDelegatePermissions AllSites.FullControl `
  -GraphDelegatePermissions Group.Read.All
```

Note the **AzureAppId / ClientId** it returns; every later command needs it.

> **Pass `-Tenant` the tenant GUID, not a domain name.** PnP inserts the value directly into the
> authentication URL (`{endpoint}/{Tenant}/v2.0/adminconsent?...`). A verified custom domain usually
> resolves, but a mismatch produces `AADSTS90013: Invalid input received from the user`, which reads
> like a sign-in problem rather than a parameter problem. The GUID is unambiguous.

> `Register-PnPEntraIDApp` has no `-Interactive` parameter. Authentication is a browser popup by
> default, or `-DeviceLogin` for a machine without a browser. Its certificate is a credential and
> must be written outside the repository.

Store the client ID for reuse. It is an identifier, not a credential:

```powershell
[Environment]::SetEnvironmentVariable("DMS_CLIENT_ID", "<AzureAppId>", "User")
```

Find the tenant ID (already recorded in `config/environments.json` for this tenant):

```powershell
$clientId = $env:DMS_CLIENT_ID
Connect-PnPOnline -Url https://propfound.sharepoint.com/sites/DOX `
  -Interactive -ClientId $clientId -Tenant 9fd1307f-3666-4779-b6de-0d596aaf093a
Get-PnPTenantId
```

## 3. Create the test-bed site

Only if it does not already exist. **Additive — touches no existing content.**

```powershell
Connect-PnPOnline -Url https://propfound-admin.sharepoint.com -Interactive -ClientId $clientId -Tenant 9fd1307f-3666-4779-b6de-0d596aaf093a
New-PnPSite -Type CommunicationSite -Title "DMS Dev" -Url https://propfound.sharepoint.com/sites/dms-dev
```

> **Do not deploy into `SOLEngineering`, `Gemini`, `LOGZONE` or any existing site.** Those hold live
> client proposal material. Applying DMS content types, permission changes or retention labels there
> would be a production change to live commercial content and is out of scope for a test bed.

> **Note on the supplied `/sites/DOX` site:** it appears to be Teams-connected, which carries an
> associated Microsoft 365 group whose Members hold Edit by default. Verify that membership before
> treating the library as the security boundary (F-024, R-07).

## 4. Validate before connecting

```powershell
./src/provisioning/Test-DmsConfiguration.ps1 -Environment dev
```

Exit 0 required. This runs schema conformance, referential integrity, lifecycle and routing rule
conformance, and the PnP cmdlet-usage check. Do not proceed on a failure.

## 5. Connect and run read-only discovery

`Connect-Dms.ps1` reads the tenant ID, site URL and client ID from `config/environments.json` and
opens both endpoints, so no GUID is retyped and the deployment cannot target the wrong tenant.

```powershell
$conn = ./src/provisioning/Connect-Dms.ps1 -Environment dev

$conn.Site.Url    # https://propfound.sharepoint.com/sites/DOX
$conn.Admin.Url   # https://propfound-admin.sharepoint.com
```

Two connections are needed because they are different endpoints: site-scoped operations (columns,
content types, libraries, views) go to the site, and tenant-scoped operations (sharing capability,
site creation) go to the admin endpoint. Passing one where the other is required fails with
"The provided connection through -Connection holds no SharePoint context".

If the admin connection fails you can still proceed; tenant-scoped actions are reported as `Blocked`
rather than attempted.

```powershell
./src/provisioning/Invoke-DmsDiscovery.ps1 -Connection $conn.Site -TenantAdminConnection $conn.Admin
```

Changes nothing. Output goes to `artifacts/discovery/` (git-ignored). Review before planning.

## 6. Plan

```powershell
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan -Connection $conn.Site -TenantAdminConnection $conn.Admin
```

Read every line. Expect roughly 104 create actions and around 25 blocked. Blocked is normal and
correct — it means feature flags, decision gates and governance-owned resources.

Confirm before applying: no unexpected `Update` on an existing resource; no `Blocked` you did not
expect; the site URL is the test bed, not a production site.

## 7. Apply (dev)

```powershell
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Apply -Connection $conn.Site -TenantAdminConnection $conn.Admin
```

Exit codes: `0` success · `1` an action failed · `2` blocking issues · `3` prerequisites missing ·
`4` configuration validation failed.

Apply skips compliant resources, updates safe differences, and reports unsafe ones without forcing
them. It is safe to rerun.

## 8. Verify

```powershell
./src/provisioning/Export-DmsConfiguration.ps1 -Environment dev -Connection $c -CompareToBaseline
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan -Connection $conn.Site -TenantAdminConnection $conn.Admin
```

A second plan should report everything `Compliant` with zero creates. That is the idempotency proof.
The drift report must show zero High-severity drift — draft visibility and moderation drift are High
because they are the controls keeping drafts away from readers.

## 9. Purview (only after OQ-03)

```powershell
./src/provisioning/Deploy-DmsPurview.ps1 -Environment dev -Mode Plan
```

Currently blocks all five classes. Apply refuses until Records Management and Legal approve the file
plan and `config/retention-map.json` replaces the example with approved values.

**Regulatory records, Preservation Lock and automatic permanent deletion remain prohibited** without
separate written authorisation.

## 10. Power Platform

```powershell
./src/provisioning/Deploy-DmsPowerPlatform.ps1 -Environment dev -Mode Plan
pac auth create --environment <env-url>
pac solution import --path <solution_managed.zip> --settings-file src/power-platform/deployment-settings/deployment-settings.dev.json
```

Only `*_managed.zip` may be imported into test or prod.

## 11. Production

Production Apply requires **all seven** conditions. Any missing condition is reported; none can be
bypassed.

```powershell
./src/provisioning/Deploy-Dms.ps1 -Environment prod -Mode Apply -Connection $conn.Site -TenantAdminConnection $conn.Admin `
  -ConfirmProductionChange `
  -PriorSuccessfulDeployment @('dev','test') `
  -RollbackPlanReference 'docs/BACKUP_RECOVERY_PLAN.md#rollback'
```

Plus `allowProductionChanges: true` in `config/environments.json`, which defaults to false and must
be set deliberately.

## 12. Rollback

| Failure | Action |
|---|---|
| Apply failed partway | Rerun Apply. Idempotent; completed actions report Compliant. |
| Wrong configuration applied | Correct config, rerun Plan, review, Apply. |
| Site must be removed (dev only) | `Remove-PnPTenantSite`. **Never in production without change approval.** |
| Solution import failed | Import the previous managed solution version. |
| Data loss | `docs/BACKUP_RECOVERY_PLAN.md` |

## 13. Regenerating the PnP cmdlet index

When the pinned PnP version changes:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/pnp/powershell.git
cd powershell && git sparse-checkout set src/Commands
# regenerate tests/fixtures/pnp-cmdlet-index.json, recording commit and date in _provenance
```

Then rerun `Test-DmsConfiguration.ps1`; a renamed or removed cmdlet fails the build.
