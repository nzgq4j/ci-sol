# Open Decisions

Decisions that are not the implementation team's to make. Each entry states who owns it, what is
blocked, what safe default is in place, and what happens if the default turns out to be wrong.

**No organisational answer has been invented for any of these.** Where work had to continue, a
provisional configuration default was set, marked as provisional, and wired so that unsafe production
deployment is prevented until the decision is made.

## How the safe defaults are enforced

| Enforcement | Mechanism |
|---|---|
| Production changes blocked | `Test-DmsProductionGuard` — 7 conditions, deny by default |
| Retention configuration blocked | `Deploy-DmsPurview.ps1` refuses Apply while any class is `REQUIRES_RECORDS_APPROVAL` |
| Irreversible Purview controls blocked | `allowIrreversiblePurviewChanges: false` + explicit flag + signed decision reference |
| Decision-gated resources not provisioned | Feature flags; plan reports them as `Blocked` naming the ADR |
| Provisional settings surfaced | `Test-DmsConfiguration` emits a warning listing every provisional value |

---

## Blocking decisions

### OQ-01 — Which legal, regulatory and quality regimes apply?
**Owner:** Legal, Quality, Security, Privacy · **Blocks:** architecture approval, SEC-*, NFR-012/016

The PRD assumes a corporate/ISO-oriented system, **not** validated GxP, 21 CFR Part 11, defence
classified, FedRAMP, or qualified electronic signature. That assumption is load-bearing: if it is
wrong, validation evidence, signature technology and possibly the platform choice all change.

**Default in place:** Corporate/ISO alignment. No compliance or certification claim is made anywhere
in this repository.
**If wrong:** Significant rework. Confirm before build completion, not after.

### OQ-02 — What Microsoft 365 licences and add-ons are owned?
**Owner:** IT / Procurement · **Blocks:** Purview retention, Power Apps, Power BI, Backup, SAM

Tenant discovery could not read licensing. Purview retention labels, premium Power Platform
connectors, Power BI and Microsoft 365 Backup each carry a licence dependency.

**Default in place:** No capability is assumed. Power BI is recorded as *planned*, not implemented.
ADR-003 chose SharePoint Lists over Dataverse specifically to avoid an unconfirmed premium dependency.
**If wrong:** Features become unavailable late. This is PRD risk R-02.

### OQ-03 — What is the approved retention schedule and file plan?
**Owner:** Records Management, Legal · **Blocks:** F-018, F-019, F-020, all record capture

**No retention period has been invented.** Every class in `config/retention-map.example.json` carries
`REQUIRES_RECORDS_APPROVAL` for both authority and period. A Pester test asserts this and fails if any
period is ever populated without approval.

**Default in place:** Retention Apply refused entirely. Five classes await approval.
**If wrong / delayed:** Operational record capture cannot go to production. This is PRD risk R-03 —
labels configured before the schedule is approved cause over-retention, premature disposal or
permanently inaccessible content.

### OQ-04 — Which business function pilots the MVP?
**Owner:** Sponsor, Product Owner · **Blocks:** taxonomy values, routing assignees, pilot scope

**Default in place:** `REQUIRES_STAKEHOLDER_DECISION_OQ-04`. Term-set *structure* is complete and not
provisional; only the term *values* await confirmation.
**Observation from discovery:** Quality / proposal document control looks like the natural candidate —
SOPs and Quality Control Plans already exist in the tenant, uncontrolled.

### OQ-05 — One controlled library, or a separate immutable Published Revisions library?
**Owner:** Quality, Legal, Records, Architecture · **Blocks:** F-012, F-013, F-014 · See **ADR-001**

**Default in place:** Option A (single library). Option B is fully modelled behind a feature flag, so
switching is a configuration change rather than a redesign. Every deployment plan reports the
Published Revisions library as `Blocked` naming this decision, so the gate stays visible.
**If wrong:** Change the flag before production content is created. After content exists, migration
between patterns is expensive.

### OQ-06 — What RPO, RTO and recovery scope apply?
**Owner:** Continuity, IT, Business owner · **Blocks:** NFR-013, backup procurement, launch · See **ADR-012**

**Default in place:** Interim planning assumption of 24-hour RPO and 8-business-hour RTO, explicitly
labelled as an assumption. No backup product selected.
**Stated plainly:** version history and recycle bins are not a backup service.

### OQ-07 — What audit-evidence retention period is required?
**Owner:** Compliance, Legal, IT · **Blocks:** F-010, F-021, NFR-012

**Default in place:** `auditRetentionDays: 180`, marked provisional. The architecture does not depend
on native audit retention being sufficient — the Approval Evidence register exists precisely so that
evidence survives independently (ADR-005). Its own retention class is itself pending OQ-03.
**If wrong:** Adjust the evidence retention class; no architectural change needed. This design already
mitigates PRD risk R-12.

### OQ-08 — What external sharing and offline access is permitted?
**Owner:** Security, Privacy, Business owner · **Blocks:** F-025, SEC-005, SEC-006

**Default in place:** `externalSharing: "Disabled"` in every environment. The External Partners role
is defined but **not provisioned**. Tests assert the default in all three environments.
**Note:** discovery could not read the tenant's current sharing configuration, so F-025 is designed
but **not yet verified** against the tenant.

### OQ-09 — Acknowledgement, LMS training, or legally binding e-signature?
**Owner:** Quality, HR, Legal · **Blocks:** F-029, F-036

**Default in place:** Acknowledgement only, behind a feature flag, explicitly labelled "not competence
certification" in the data model and the user guides. No e-signature capability is implied anywhere.

### OQ-10 — Which repositories migrate, and what is their data quality?
**Owner:** Migration lead, Business owner · **Blocks:** F-037, migration scope · See **ADR-014**

**Default in place:** Pilot-only framework; provenance unknown by default; source preserved.
**Evidence from discovery:** 58,319 folders matched one search term; revision state is encoded in
filenames. Migration scope needs bounding before any import.

### OQ-11 — What Document ID and business revision convention is required?
**Owner:** Document Control, Quality · **Blocks:** F-002, F-031, content type build · See **ADR-006**

**Default in place:** Provisional patterns `^[A-Z]{2,5}-[A-Z]{2,4}-[0-9]{3,5}$` for the ID and
`^[0-9]{1,3}(\.[0-9]{1,2})?$` for the revision, held in configuration.
**If wrong:** Configuration edit. Changing it *after* IDs are issued is not safe — IDs are persistent
by design — so this must be answered before the first document is created.

### OQ-12 — Which metadata fields are globally mandatory versus conditional?
**Owner:** Document Control, Records, Security · **Blocks:** F-001, schema approval

**Default in place:** The required/optional split in `config/site-columns.json` and
`config/content-types.json`, derived from PRD section 17.3 validation rules.
**If wrong:** Field requiredness is a configuration change and is low risk to adjust before content
exists.

### OQ-13 — What approval authorities, delegation, quorum and escalation apply by document class?
**Owner:** Business, Quality, Legal · **Blocks:** F-009, workflow build

**Default in place:** Route *structure* is complete and tested — five rule sets, specificity
resolution, serial/parallel, quorum, escalation, separation of duties. Every **assignee** is
`REQUIRES_STAKEHOLDER_DECISION_OQ-13`.
**Deliberate behaviour:** a Highly Confidential SOP currently resolves as *ambiguous* and raises a
blocking exception, because two rules tie on specificity. The system refuses to guess an approval
route. Document Control resolves it by adding an explicit combined rule.

### OQ-17 — What baseline values exist for the metric targets?
**Owner:** Product Owner, Data · **Blocks:** final metric targets

**Default in place:** PRD proposed targets carried into `config/metrics.json`, each labelled a
hypothesis pending baseline.

### OQ-18 — What operating hours, business calendar and support severity model apply?
**Owner:** Business owner, IT · **Blocks:** ADM-002, NFR-003/014, due-date arithmetic

**Default in place:** Monday–Friday business days with a supplied holiday list; stale check-out
threshold 3 business days; aged blocking exception threshold 24 hours.
**Note:** `Get-DmsBusinessDayOffset` accepts an explicit holiday list rather than assuming one.

---

## Non-blocking decisions

| ID | Question | Default in place |
|---|---|---|
| OQ-14 | Are emergency change and suspension required in MVP? | Implemented — Emergency Suspend is a Flow 4 outcome with mandatory rationale and post-hoc review |
| OQ-15 | Power Apps, or native forms? | Native forms (ADR-004). Power Apps P1, contingent on usability evidence |
| OQ-16 | Which languages, regions and data residency? | `en-GB`, single time zone, Site/Region term set present but optional |

---

## Conflicts and gaps identified in the PRD

Recorded as required, rather than silently resolved.

| # | Observation | Resolution taken |
|---|---|---|
| 1 | PRD section 12.4 lists Acknowledgement among required MVP entities, while section 10.2 and F-029 mark it P1. | Implemented behind a feature flag, provisioned only when the pilot requires it. Flagged here rather than choosing silently. |
| 2 | PRD section 20.1 requires a Document Control Work Queue refreshed "near real time or at least every 15 minutes", but section 15 provides no P0 requirement for a dashboard refresh mechanism. | Delivered as a live SharePoint list view (inherently current) rather than a refreshed report, satisfying the intent without a Power BI licence dependency. |
| 3 | PRD F-013 requires one effective revision "within an applicability context", but the applicability term set is not specified. | Applicability modelled as a controlled multi-value term set and made part of the uniqueness key. Term *values* await OQ-04. Noted because a different applicability model changes the uniqueness boundary. |
| 4 | PRD NFR-017 sets a 60-minute search-freshness target, while F-026 requires exact-ID search to work. Search indexing latency is outside the product's control. | Two independent paths (metadata view + direct link from the register) so findability never depends solely on the index. Index delay is a non-blocking exception. |
| 5 | The PRD requires audit evidence for "the longer of the document's approved evidence period or applicable audit policy" (NFR-012) while noting standard audit retention is 180 days (OQ-07). | Approval Evidence register carries its own retention class independent of audit licensing. |

---

## Environment access still required

| Requirement | Needed for | Status |
|---|---|---|
| Entra tenant ID | Completing `config/environments.json`; production guard | **Outstanding** — blocks Apply |
| PnP connection (interactive or app-only certificate) | Any provisioning at all | **Outstanding** |
| SharePoint Administrator role | Site creation, tenant sharing configuration | **Outstanding** |
| Security & Compliance access | Purview retention (after OQ-03) | **Outstanding** |
| Power Platform environments (Dev/Test/Prod) | Flow build and managed-solution ALM | **Outstanding** |
| Entra group creation through identity governance | Role assignment | **Outstanding** — deliberately not automated (ADR: see `Deploy-DmsSecurity.ps1`) |
