# Migration Plan

Implements PRD F-037, DATA-012, INT-010, C-009, R-08. See **ADR-014**.

> **Pilot only, and gated.** Enterprise migration is explicitly out of MVP scope and is not
> authorised by the existence of these scripts.

## 1. What discovery already tells us

Read-only discovery of the actual tenant (`docs/ENVIRONMENT_DISCOVERY.md`) found:

- **58,319 folders** matching a single search term.
- Revision state encoded in **filenames**: `-1_KLS_v2`, `-2`, `-3`, `Rev0`, `ReadyForFinal`.
- Lifecycle state encoded in **folder names**: `01 Drafts`, `C - Gold`, `OBE`, `02 Production`.
- Classification encoded in **numbered folders**: `00 - DOX`, `99 - Misc Files`.
- Controlled-document-like content already present: SOPs, Quality Control Plans.

**Implication:** the source has no reliable machine-readable owner, revision, approval status or
approval history. This is not a pessimistic assumption; it is an observation.

## 2. Core principle — provenance unknown by default

Where owner, revision, lifecycle status or approval history cannot be established from source data,
the item is **quarantined**, not assigned a plausible value.

Inferring "revision 2, approved" from a filename would manufacture control evidence that does not
exist. That is worse than an empty field, because it looks like evidence and would pass a
completeness check while being fiction.

**A large quarantine list is a successful pilot outcome.** It makes the true data-quality position
visible before anyone authorises an enterprise wave.

## 3. Phases

| Phase | Output | Gate |
|---|---|---|
| 1 Inventory | Full source listing: path, size, dates, owner where available, hash where required | Read-only |
| 2 Analysis | Duplicates, invalid names, excessive path length, unknown ownership, unmapped metadata | — |
| 3 Mapping | Source-to-target mapping template completed by the business | **Business sign-off required** |
| 4 Dry run | Simulated import; full reconciliation report; no writes | Must reconcile |
| 5 Pilot import | Controlled batches; failures quarantined | Batch-level acceptance |
| 6 Reconciliation | Counts, sizes, metadata, permissions, sample hashes | Must pass tolerance |
| 7 Acceptance | Pilot acceptance report signed | **Gates any enterprise proposal** |

## 4. Rules that are not negotiable

1. **The source is never modified or deleted.** Not during, not after import. Source retirement is a
   separate, separately authorised decision made after acceptance.
2. **Every imported item carries provenance** — `DmsSourceProvenance` and `DmsMigrationBatchId`.
3. **Failures quarantine, never guess.**
4. **Reconciliation before acceptance**, not after.
5. **No destructive cutover** before acceptance.

## 5. Reconciliation criteria

| Check | Tolerance |
|---|---|
| Item count | Exact |
| Total size | Exact |
| Required metadata populated | 100% for non-quarantined items |
| Permissions mapped to role groups | 100%, no direct user permissions |
| Sample hash match | 100% of the sampled set where chain of custody requires it |
| Duplicate Document IDs | Zero |
| Effective-revision uniqueness | Zero violations |

Hashes are computed only where chain of custody requires them — hashing 58,000 files to prove
something nobody asked to be proven is waste (DATA-012).

## 6. Handling what discovery found

| Source condition | Treatment |
|---|---|
| Revision in filename (`-v2`, `Rev0`) | **Do not parse into `DmsBusinessRevision`.** Record verbatim in provenance; quarantine for business assignment |
| Status in folder (`C - Gold`, `OBE`) | Same. Never map a folder name to `DmsLifecycleStatus` |
| Duplicate near-identical files | Flag as a duplicate set; business chooses the authoritative one |
| No identifiable owner | Quarantine. An effective document with no owner is an MET-005 violation on day one |
| Path exceeds SharePoint limits | Flag; the flattening decision is the business's |
| Completed forms mixed with blank templates | Split by content type — the PRD F-003 distinction |

## 7. Artefacts

| Artefact | Location | Status |
|---|---|---|
| Inventory script | `src/migration/Get-DmsSourceInventory.ps1` | Implemented |
| Mapping template | `src/migration/mapping-template.csv` | Implemented |
| Import script | `src/migration/Import-DmsContent.ps1` | Specified — requires tenant |
| Reconciliation script | `src/migration/Compare-DmsMigration.ps1` | Implemented |
| Migration Evidence list | `config/lists.json` | Configured, feature-flagged |
| Acceptance report template | `src/migration/ACCEPTANCE_REPORT_TEMPLATE.md` | Implemented |

## 8. What would stop the pilot

- Reconciliation variance outside tolerance
- Any duplicate Document ID reaching the target
- Any effective-revision uniqueness violation
- Quarantine rate so high that the source is not fit to migrate — a legitimate finding, and a
  legitimate reason to stop and cleanse first
