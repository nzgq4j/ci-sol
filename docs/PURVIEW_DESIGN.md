# Microsoft Purview Design

Implements PRD F-018 to F-021, SEC-006, SEC-010, SEC-012 and section 8 of the build brief.

> **Status: PLANNING ONLY.** No Purview configuration has been created. `Deploy-DmsPurview.ps1`
> defaults to Plan mode and refuses Apply while any retention class is unapproved. All five defined
> classes are currently blocked.

## 1. The central safety rule

**No retention period in this repository is authoritative.** Every class in
`config/retention-map.example.json` carries `REQUIRES_RECORDS_APPROVAL` for both authority and
period. A Pester test asserts that no period has been invented and fails the build if one appears
without approval.

This exists because PRD risk **R-03** is that labels configured before the file plan is approved
cause over-retention, premature disposal, or content that cannot be deleted when it should be.

## 2. Retention policies versus item-level labels (ADR-009)

| Mechanism | Use for | Why |
|---|---|---|
| **Retention policy** (container scope) | A library where every item shares one treatment | Simple, no per-item action |
| **Retention label** (item scope) | Record classes with distinct triggers and periods | A policy cannot express mixed schedules in one library; labels support event-based triggers and disposition review |

The Operational Records library holds multiple record classes, so labels are required there.

## 3. File plan mapping

Five classes defined, all provisional.

| Record class | Applies to | Trigger | Type | Period | Disposition | Record? |
|---|---|---|---|---|---|:--:|
| Completed Inspection Record | Operational Record | `DmsEventDate` | Event-based | **REQUIRES_RECORDS_APPROVAL** | Disposition review | No |
| Controlled Document — Superseded Revision | Controlled Document, status Superseded | Effective date of superseding revision | Event-based | **REQUIRES_RECORDS_APPROVAL** | Disposition review | No |
| Approval Evidence | Approval Evidence list | `DmsDecisionTimestampUtc` | Event-based | **REQUIRES_RECORDS_APPROVAL** | Disposition review | No |
| Change Request | Change Requests list | `DmsTriageDecisionDate` | Event-based | **REQUIRES_RECORDS_APPROVAL** | Disposition review | No |
| Acknowledgement Response | Acknowledgements list | `DmsAckRespondedUtc` | Event-based | **REQUIRES_RECORDS_APPROVAL** | Disposition review | No — contains personal data |

Retaining superseded revisions is what allows an auditor to establish what was effective on a past
date (PRD NFR-012). Approval Evidence carries its own class precisely so evidence does not depend on
audit-log licensing (PRD R-12).

## 4. Record versus regulatory record

| | Record label | **Regulatory record** |
|---|---|---|
| Edit | Restricted | Blocked |
| Delete | Restricted | Blocked |
| Label removal | Possible by an authorised role | **Not possible** |
| Reversible | Yes, with authority | **No** |
| MVP status | Available after OQ-03 | **PROHIBITED** |

A regulatory record cannot be undone by anyone, including a Global Administrator. Applying one to the
wrong content class permanently prevents legitimate revision and disposal.

**Gate:** three conditions must all hold — `allowIrreversiblePurviewChanges: true` in the environment,
the `-IrreversibleChangeAuthorised` switch, and a signed decision-record reference. Missing any one
produces a `Blocked` plan action naming exactly what is absent. Preservation Lock and automatic
permanent deletion are gated identically.

A regulatory label also **cannot be applied to a checked-out file** — relevant because the Templates
library uses forced check-out.

## 5. Legal hold interaction

A legal or eDiscovery hold overrides disposition. Held items are excluded from disposition processing
and reported separately. Disposition must never silently skip a held item without recording why
(PRD F-020).

## 6. Proof of disposition

Disposition outcomes must be exportable as evidence: item, class, reviewer, outcome, rationale, date
and reference. **No user-interface delete substitutes for disposition** (PRD F-020) — this is why the
`DMS Contribute No Delete` permission level exists.

## 7. Sensitivity labels and DLP

`DmsSensitivityClassification` is a **business** classification field. It does **not** itself apply a
Purview sensitivity label — the mapping is a separate decision requiring the OQ-01 applicability
assessment.

If encryption-bearing sensitivity labels are adopted, test before rollout: co-authoring behaviour,
search indexing of encrypted content, Power Automate access to encrypted files, and download
behaviour. Encrypted files can become unreadable to automation, which would break the lifecycle
flows.

## 8. Audit retention

Purview Audit Standard retains audit records for a documented default period; longer retention needs
licence confirmation (OQ-07). The architecture does not depend on this: durable approval evidence
lives in the Approval Evidence register with its own retention class.

## 9. Licensing dependency

Retention labels, disposition review, records management and extended audit retention each carry a
licensing dependency that discovery **could not confirm** (OQ-02). No capability is assumed.

## 10. Pilot test plan (post-approval)

Executed in dev/test only, never first in production.

1. Create labels in a non-production compliance scope.
2. Apply to sample content; verify with `Get-PnPFileRetentionLabel`.
3. Confirm a labelled record cannot be deleted by a business user.
4. Confirm an authorised Records Manager can unlock, and that the unlock is logged with actor and reason.
5. Simulate a legal hold; confirm disposition is suppressed.
6. Run a disposition review; export proof.
7. Attempt to label a checked-out file; record the behaviour.
8. Verify label conformance sampling reports 100% (MET-010).

## 11. Roles

| Purview role group | Assigned to | Purpose |
|---|---|---|
| Records Management | Records Managers | File plan, labels, record state |
| Disposition Management | Records Managers | Disposition review |
| Compliance Administrator | **Not assigned to the DMS team** | Tenant-wide; outside this product's scope |

Purview role assignment happens in the compliance portal and is **not** a SharePoint permission.
