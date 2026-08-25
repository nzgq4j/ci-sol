# Site scripts

`dms-site-script.json` applies site-level settings that a site design can enforce at creation:
external sharing disabled (F-025), regional settings, and role-based navigation (UX-001, UX-002).

**Site scripts are not the primary provisioning mechanism.** They cannot create content types with
specific IDs, set draft visibility, create custom permission levels or configure moderation — all of
which the DMS requires. `Deploy-DmsSharePoint.ps1` does that work. The site script exists so a newly
created site starts from a safe baseline rather than a default one.

`timeZone: 2` is UTC/GMT and `locale: 2057` is en-GB, matching `defaultLanguage`. Both are provisional
pending OQ-16.

Register with:

```powershell
$content = Get-Content ./dms-site-script.json -Raw
Add-PnPSiteScript -Title "DMS baseline" -Description "DMS site baseline settings" -Content $content
```
