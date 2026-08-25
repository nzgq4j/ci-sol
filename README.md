# Microsoft 365 Document Management System

Implementation of `SharePoint_DMS_PRD.md`: a governed DMS on SharePoint Online, Power Platform,
Microsoft Purview and Microsoft Entra ID.

## Status

**Nothing has been deployed to any tenant.** No site, library, list, column, content type, group,
label or flow exists in Microsoft 365. Everything here is configuration, code, specification, tests
and documentation, ready to deploy once access and the outstanding decisions exist.

What runs today, offline, with no tenant:

```
Configuration validation   16 checks passing
Test suite                 Pester 5.7.1
Deployment plan            104 create actions, 25 correctly blocked
PnP cmdlet verification    34 invocations checked against PnP source
Requirements traceability  167 IDs extracted from the PRD, 27 P0, 0 unreferenced
```

See `docs/BUILD_STATUS.md` for the authoritative position.

## Quick start

```bash
# 1. Validate everything offline (no tenant needed)
./src/provisioning/Test-DmsConfiguration.ps1 -Environment dev

# 2. See exactly what would be created
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan

# 3. Run the tests
pwsh -c 'Invoke-Pester ./tests/pester'
```

Applying to a tenant requires PnP PowerShell, a connection, and the prerequisites in
`docs/DEPLOYMENT_RUNBOOK.md`.

## What the system does

Controlled documents move through a governed lifecycle:

```
Requested → Triaged → Authoring → In Review → Rework
                                      ↓
                        Approved Pending Effective → Effective → Superseded
                                                         ↓            ↓
                                                     Withdrawn → Obsolete
```

The properties that make it a DMS rather than a document library:

- **One current revision.** At most one effective revision per document and applicability context,
  checked at activation and continuously.
- **Approval binds to content.** The file's ETag is captured at submission and re-checked before
  approval *and* again before publication. A file edited after review cannot be published under that
  approval.
- **Evidence outlives the automation.** Decisions live in a register only the automation identity can
  write to, not in flow run history that expires.
- **Future effective dates work.** A daily scheduled sweep activates approved revisions, revalidates
  first, and is safe to replay.
- **Drafts stay invisible.** Draft visibility is set to Approver, so readers cannot see work in
  progress even by direct query.
- **Blank forms and completed records are different things**, with different lifecycles and different
  retention.

## Repository layout

| Path | Contents |
|---|---|
| `config/` | 12 configuration files + 6 JSON schemas — the single source of truth |
| `src/modules/DmsProvisioning/` | Rule engine and provisioning module (24 exported functions) |
| `src/provisioning/` | Plan/Apply deployment, discovery, validation, export |
| `src/power-platform/` | Flow specifications, deployment settings |
| `src/migration/` | Pilot migration inventory, mapping, reconciliation |
| `src/reporting/` | Metrics export, documentation and traceability generators |
| `src/list-formatting/`, `src/site-scripts/` | Native formatting and site baseline |
| `tests/` | Pester suites and fixtures |
| `docs/` | Architecture, decisions, runbooks, user guides |
| `templates/` | Controlled document templates |
| `pipelines/` | CI and deployment examples |

## Documentation

**Start here:** [`docs/BUILD_STATUS.md`](docs/BUILD_STATUS.md) — what is done, tested, blocked and next.

| Document | Purpose |
|---|---|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | System design and the reasoning behind it |
| [ARCHITECTURE_DECISIONS](docs/ARCHITECTURE_DECISIONS.md) | 15 ADRs including what was rejected |
| [OPEN_DECISIONS](docs/OPEN_DECISIONS.md) | What is blocked, on whom, and the safe default in place |
| [REQUIREMENTS_TRACEABILITY](docs/REQUIREMENTS_TRACEABILITY.md) | Generated from the PRD |
| [SECURITY_MODEL](docs/SECURITY_MODEL.md) | Roles, permissions, API permissions |
| [PURVIEW_DESIGN](docs/PURVIEW_DESIGN.md) | Retention — planning only, gated |
| [DEPLOYMENT_RUNBOOK](docs/DEPLOYMENT_RUNBOOK.md) | How to deploy |
| [OPERATIONS_RUNBOOK](docs/OPERATIONS_RUNBOOK.md) | How to run it |
| [USER_GUIDES](docs/USER_GUIDES/) | Reader, author, reviewer, controller, records manager |

## Safety posture

Defaults that are deliberately restrictive:

| Control | Default |
|---|---|
| `allowProductionChanges` | `false` — seven conditions required, none bypassable |
| `allowIrreversiblePurviewChanges` | `false` — regulatory records and Preservation Lock prohibited |
| External sharing | `Disabled` in every environment |
| Retention Apply | Refused while any class is unapproved |
| Entra group creation | Not automated — governance owns it |
| Migration provenance | Unknown by default; quarantine rather than guess |

## Licence and dependencies

PnP PowerShell is **community-led, not Microsoft product support**. It is pinned, its cmdlet surface
is verified against source, and organisational support ownership is defined in
`docs/SUPPORT_MODEL.md`.
