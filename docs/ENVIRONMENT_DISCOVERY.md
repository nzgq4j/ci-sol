# Environment Discovery

| Field | Value |
|---|---|
| Status | **Partial — read-only discovery completed; privileged discovery BLOCKED** |
| Discovery date | 25 August 2026 |
| Performed by | Automated read-only discovery via Microsoft Graph (delegated) |
| Tenant | proposal-foundry.com |
| Identity used | david.daniel@proposal-foundry.com (delegated user context, President/CEO) |
| Tenant state changed | **No.** All operations were read-only. PRD Phase 1 requires discovery not to change tenant state. |

> **Scope warning.** Everything below was gathered through a *delegated user* Graph connection with
> file/folder scopes only. It therefore reflects **what this one user can see**, not the tenant's
> full configuration. Nothing here should be treated as a complete inventory until privileged
> discovery (below) has been run.

---

## 1. Confirmed tenant values

These replace the `REQUIRES_TENANT_DISCOVERY` placeholders in `config/environments.example.json`.

| Setting | Discovered value | Confidence |
|---|---|---|
| `tenantName` | `propfound` | **Confirmed** — observed in every SharePoint URL |
| SharePoint root | `https://propfound.sharepoint.com` | **Confirmed** |
| OneDrive host | `https://propfound-my.sharepoint.com` | **Confirmed** |
| `sharePointAdminUrl` | `https://propfound-admin.sharepoint.com` | **Inferred** from the standard naming convention; not yet reachable with the current token |
| `tenantId` | Not discoverable with the current delegated scopes | **BLOCKED** |
| `contentTypeHubUrl` | Not confirmed; conventionally `https://propfound.sharepoint.com/sites/contentTypeHub` | **BLOCKED** |
| `defaultTimeZone` | Not confirmed | **BLOCKED** — affects due-date and activation scheduling (PRD A-005, OQ-16) |

## 2. Site inventory (partial)

Sites observed through delegated search. This is **not** an authoritative site list — it only
contains sites surfaced by content this user can read.

| Site URL | Apparent purpose | Observed characteristics |
|---|---|---|
| `/sites/SOLEngineering` | Active RFP and proposal production | Deep folder trees, e.g. `Shared Documents/B - RFPs/110 - DCMA Blue List/01 Drafts/01 Volume I - Technical/` |
| `/sites/Gemini` | RFP responses (Gemini Tech Services) | `Shared Documents/00 - RFP/<nn> - <opportunity>/…` numbered-folder convention |
| `/sites/LOGZONE` | Proposal responses | `Shared Documents/General/01 - Responses/00 - Proposal Responses/…` |
| `/sites/NETS-LZI` | Programme content | `Shared Documents/General/99 - Misc Files/…` |
| `/sites/ProposalFoundry-Internal` | Internal opportunity work | `Shared Documents/<nn> - <client>/…` |
| `/sites/CONSEC` | Business development | `Shared Documents/01 - Business Development/…` |
| `/sites/TEAMSNEXTFLE` | Teams-connected site | `Shared Documents/General/…` |
| `/sites/eastpoint` | Client/opportunity site | `Shared Documents/General/00 - UNLV/…` |
| `propfound-my.sharepoint.com/personal/david_daniel_…` | OneDrive | Contains a `99 - Knowledge Catalog` tree used as a de facto document library |

## 3. Current-state findings against PRD section 9

Discovery **confirms** the fragmented current state the PRD predicted. These are evidence-backed, not assumed.

| PRD section 9 condition | Status | Evidence observed |
|---|---|---|
| Folder and filename conventions carry most classification | **Confirmed** | A folder-name search for "Documents" returned **58,319** matching folders. Classification is encoded in numbered folder names (`00 - DOX`, `01 Drafts`, `99 - Misc Files`, `C - Gold`) rather than in metadata. |
| Deep folder hierarchies | **Confirmed** | Paths of 6+ levels are routine, e.g. `…/00 - RFP/23 - Hill AFB Materials/02 - Response/Review/Production/`. |
| Duplicate and conflicting versions | **Confirmed** | Revision state is carried in filenames rather than versions: `Volume-2-Technical-TeamGTS.docx`, `-1_KLS_v2`, `-2`, `-3`, `Technical-TeamGTS-MA-2/-4/-ReadyForFinal`. This is exactly the ambiguity the DMS is intended to remove. |
| Documents held across OneDrive as well as team sites | **Confirmed** | A `99 - Knowledge Catalog` tree in personal OneDrive holds what appears to be organisational reference material. |
| Lifecycle status not represented as data | **Confirmed** | Status is encoded in folder names (`C - Drafts/C - Gold`, `OBE`) and filename suffixes, not in a queryable field. No `Lifecycle Status`, `Effective Date` or `Next Review Date` column was observed anywhere. |
| Controlled documents already exist informally | **Confirmed** | SOP- and QCP-style documents exist (`SOP-13_Quality_Control_Inspection_and_Surveillance.docx`, `LZI-SOP-AST-01_Asbestos_Management_SOP.docx`, `N6230621F0024_LZI_Quality_Control_Plan_Rev0_20260731.docx`). Note `Rev0` in the filename — a business revision with no system field behind it. |

**Implication for migration (PRD C-009, R-08):** filename-encoded revision state and numbered-folder
classification mean the source has *no reliable machine-readable* owner, revision, status or approval
history. Migration mapping must therefore treat provenance as unknown-by-default and quarantine
rather than guess. This is now an evidenced finding, not a precaution.

## 4. Discovery that could NOT be performed

Each item below is blocked by missing privileged access, **not** by missing implementation.

| Discovery item (PRD Phase 1) | Blocked by | Needed for |
|---|---|---|
| Tenant ID and tenant-level SharePoint configuration | No SharePoint Admin / Graph tenant scope | `config/environments.json` |
| Existing content-type gallery and term store | No `Sites.FullControl.All` or term-store read | F-001 conflict detection |
| Existing site columns and content types | Same | Drift baseline |
| External-sharing configuration (tenant and per site) | No SPO admin access | **F-025, SEC-005** — cannot yet confirm sharing is disabled |
| Sensitivity and retention labels in Purview | No Security & Compliance PowerShell access | F-018 to F-020 |
| Entra groups, group owners, membership | No `Group.Read.All` | F-024, SEC-002 |
| Power Platform environments and DLP policies | No Power Platform admin access | ADM-004, D-008 |
| Existing flows, owners, connections, solutions | Same | R-09 (personal flow ownership) |
| Licence-dependent capability inventory | No licence read scope | **OQ-02 (blocking)** — gates Purview, Power Apps, Power BI, Backup |
| Power BI workspaces | No Power BI admin scope | INT-008 |
| Existing backup service | Not discoverable via Graph | NFR-013, OQ-06 |
| Authoritative full site inventory | Delegated search only returns what this user can read | Migration scoping, OQ-10 |

## 5. Why the DMS could not be provisioned in this session

The connected Microsoft 365 tooling exposes **Graph file and folder operations only**:
search, read, create folder, upload/update file, copy, move, rename, delete.

Provisioning the DMS requires operations that are not in that set:

| Required to build the DMS | Available via connected tooling? |
|---|---|
| Create a site | No |
| Create a document library or list | No |
| Create site columns / content types / publish from the Content Type Hub | No |
| Configure versioning, content approval, draft visibility, forced check-out | No |
| Create views with CAML filters | No |
| Create custom permission levels; break inheritance | No |
| Create Entra security groups | No |
| Create Purview retention labels and policies | No |
| Create or import Power Automate flows | No |

Creating folders and uploading files **would** have been possible — and was deliberately **not**
done. A folder tree with uploaded documents would reproduce the exact network-drive pattern the PRD
forbids (operating principle "metadata before folders"), would carry no content types, versioning,
draft security, approval, lifecycle state or retention, and would *look* like a delivered DMS while
providing none of its controls. Shipping that would have been worse than shipping nothing.

## 6. What unblocks provisioning

Either route works. Route A is faster for a test bed; Route B is required for CI/CD.

### Route A — interactive PnP connection (fastest for a pilot test bed)

Run from a workstation with a browser, signed in as a SharePoint Administrator:

```powershell
Install-Module PnP.PowerShell -MinimumVersion 2.12.0 -Scope CurrentUser

# One-time: register an Entra application in the tenant (Global Administrator).
# PnP 2.x has no built-in multi-tenant app, so every connection needs its ClientId.
# The certificate it creates is a credential: write it OUTSIDE the repository.
Register-PnPEntraIDApp -ApplicationName "PnP-DMS-Provisioning" `
  -Tenant proposal-foundry.com -OutPath $HOME\.dms-certs -DeviceLogin

# Create the isolated test-bed site FIRST (additive; touches no existing content)
$clientId = "<AzureAppId from the previous step>"
Connect-PnPOnline -Url https://propfound-admin.sharepoint.com -Interactive -ClientId $clientId -Tenant proposal-foundry.com
New-PnPSite -Type CommunicationSite -Title "DMS Dev" -Url https://propfound.sharepoint.com/sites/dms-dev

# Then plan, review, and only then apply
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Apply
```

### Route B — app-only certificate authentication (required for pipelines)

Register an Entra application with certificate credentials and grant admin consent to the
permissions listed in `docs/SECURITY_MODEL.md`. No secret is ever stored in this repository
(PRD SEC-004).

### Recommended target for the test bed

Provision a **new, isolated site**: `https://propfound.sharepoint.com/sites/dms-dev`.

Do **not** deploy the DMS into `SOLEngineering`, `Gemini`, `LOGZONE` or any other existing site.
Those sites hold live client proposal material (DCMA, NASPO, EAGLE II BOA, USMC, USAF, Navy).
Applying DMS content types, permission changes or retention labels to them would be a production
change to live commercial content, is out of scope for a test bed, and is explicitly gated by the
production-protection rules in `CLAUDE.md`.

## 7. Blocking questions this discovery raises

| ID | Question | Why it matters now |
|---|---|---|
| OQ-02 | Which Microsoft 365 licences and add-ons are owned? | Cannot confirm Purview retention labels, Power Apps, Power BI or Backup are available. Gates F-018 to F-020 and NFR-013. |
| OQ-04 | Which business function pilots the MVP? | Discovery suggests **Quality / proposal document control** is the natural candidate given the existing SOP and Quality Control Plan content. |
| OQ-08 | What external sharing is permitted? | Sharing configuration could not be read, so F-025 cannot yet be verified. |
| OQ-10 | Which repositories migrate? | 58,319 "Documents" folders were observed for one search term alone. Migration scope needs bounding before any pilot import. |
