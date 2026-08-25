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

```powershell
Install-Module PnP.PowerShell -MinimumVersion 2.12.0 -Scope CurrentUser

# Once per tenant, as a Global Administrator.
# This creates an Entra app registration AND a certificate. Write the certificate OUTSIDE the
# repository - it is a credential and must never be committed (PRD SEC-004).
New-Item -ItemType Directory -Path $HOME\.dms-certs -Force | Out-Null

Register-PnPEntraIDApp `
  -ApplicationName "PnP-DMS-Provisioning" `
  -Tenant proposal-foundry.com `
  -OutPath $HOME\.dms-certs `
  -DeviceLogin
```

Note the **AzureAppId / ClientId** it returns; every later command needs it.

> `Register-PnPEntraIDApp` has no `-Interactive` parameter. Authentication is either a browser popup
> (default) or `-DeviceLogin`, which prints a code to enter at microsoft.com/devicelogin.

Find the tenant ID and complete `config/environments.json`:

```powershell
$clientId = "<AzureAppId from the previous step>"

Connect-PnPOnline -Url https://propfound.sharepoint.com/sites/DOX `
  -Interactive -ClientId $clientId -Tenant proposal-foundry.com
Get-PnPTenantId
```

## 3. Create the test-bed site

Only if it does not already exist. **Additive — touches no existing content.**

```powershell
Connect-PnPOnline -Url https://propfound-admin.sharepoint.com -Interactive -ClientId $clientId -Tenant proposal-foundry.com
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

## 5. Read-only discovery

```powershell
$clientId = "<AzureAppId>"
$c     = Connect-PnPOnline -Url https://propfound.sharepoint.com/sites/DOX `
           -Interactive -ClientId $clientId -Tenant proposal-foundry.com -ReturnConnection
$admin = Connect-PnPOnline -Url https://propfound-admin.sharepoint.com `
           -Interactive -ClientId $clientId -Tenant proposal-foundry.com -ReturnConnection

./src/provisioning/Invoke-DmsDiscovery.ps1 -Connection $c -TenantAdminConnection $admin
```

Changes nothing. Output goes to `artifacts/discovery/` (git-ignored). Review before planning.

## 6. Plan

```powershell
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan -Connection $c -TenantAdminConnection $admin
```

Read every line. Expect roughly 104 create actions and around 25 blocked. Blocked is normal and
correct — it means feature flags, decision gates and governance-owned resources.

Confirm before applying: no unexpected `Update` on an existing resource; no `Blocked` you did not
expect; the site URL is the test bed, not a production site.

## 7. Apply (dev)

```powershell
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Apply -Connection $c -TenantAdminConnection $admin
```

Exit codes: `0` success · `1` an action failed · `2` blocking issues · `3` prerequisites missing ·
`4` configuration validation failed.

Apply skips compliant resources, updates safe differences, and reports unsafe ones without forcing
them. It is safe to rerun.

## 8. Verify

```powershell
./src/provisioning/Export-DmsConfiguration.ps1 -Environment dev -Connection $c -CompareToBaseline
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan -Connection $c -TenantAdminConnection $admin
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
./src/provisioning/Deploy-Dms.ps1 -Environment prod -Mode Apply -Connection $prodConn `
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
