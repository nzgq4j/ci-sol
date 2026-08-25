# Power Automate Design

Implements PRD F-007 to F-017, F-022, F-023, ADM-004/005/008, NFR-005/006/010/015.

Detailed per-flow specifications: `src/power-platform/flow-specifications/`.

> **No solution package is included, and none was fabricated.** A Power Platform solution `.zip` is a
> build artefact exported from a real Dev environment. `Deploy-DmsPowerPlatform.ps1` reports the
> missing package as a blocking action. A test asserts that no `.zip` exists under
> `src/power-platform/`.

## 1. Environment and ALM model

| Environment | Solution type | Direct editing | Purpose |
|---|---|---|---|
| Dev | Unmanaged | Permitted | Build |
| Test | **Managed** | Refused | Validation and UAT |
| Prod | **Managed** | Refused | Live |

Managed solutions in Test and Prod are what make "no direct production editing" (NFR-010) an
enforced property rather than a policy. `Deploy-DmsPowerPlatform.ps1` refuses an unmanaged import
outside Dev.

Connection references and environment variables carry every environment-specific value. The
deployment-settings validator blocks import while any value is unresolved, because a solution that
imports with broken connections fails silently at first run.

## 2. Flow inventory

| # | Flow | Trigger | PRD | Idempotency key |
|---|---|---|---|---|
| 1 | Request and triage | Item created (Change Requests) | F-002, F-007 | `RequestId + TriageDecision` |
| 2 | Submit, review, approve | Explicit submission | F-008–F-011, NFR-011 | `ApprovalCorrelationId` |
| 3 | Scheduled activation | Daily recurrence | F-012–F-014, F-017 | `DocumentId + Revision + Activated` |
| 4 | Periodic review | Daily recurrence | F-015, F-016 | `DocumentId + Revision + ReminderOffset` |
| 5 | Exception management | Four-hourly recurrence | F-022, F-023 | `Type + ItemId + DetectedDate` |

## 3. Design rules applied to every flow

**Never trigger on every file modification.** Lifecycle flows start on explicit submission or a
schedule. A blanket modification trigger fires on the flow's own metadata writes, causing recursion,
and starts approvals nobody requested. Where a flow writes back to its trigger item, the trigger
condition excludes items last modified by the automation identity.

**Scheduled, never waiting.** Future effective dates are handled by a daily sweep. A flow waiting
months does not survive connection expiry, solution reimport or owner offboarding — and its failure
is silent.

**Idempotent side effects.** Every create, publish, supersede, label, notify and evidence write is
guarded by the key above. Replay must not produce a duplicate effective revision, decision,
assignment or notification (NFR-006). Flow 3's first check is "already activated?", which makes
replay a no-op.

**Durable evidence.** Decisions go to the Approval Evidence list, never left only in run history.

**Configuration over logic.** Thresholds and schedules come from the Workflow Configuration list, so
ordinary operational changes need no flow edit (F-028).

**Errors surface.** Every terminal failure writes an Exception Register item with type, severity,
owner and correlation ID. Error text is redacted; no token, secret or document content is ever
written (SEC-004).

**Bounded retry.** Exponential, 4 attempts, honouring `Retry-After` (NFR-015).

## 4. Version-integrity control

The single most important behaviour in the workflow layer.

1. Flow 2 captures ETag and version at submission, **before any task exists**.
2. Flow 2 re-checks before recording each decision. Mismatch → evidence `Invalidated`, High blocking
   exception, lifecycle to Rework, tasks cancelled, approval never applied.
3. Flow 3 re-checks again immediately before publishing, because the file can change between
   approval and a future effective date.

Implemented once in `Test-DmsApprovalIntegrity` and covered by five tests.

## 5. Routing resolution

Configuration-driven (F-028). Highest specificity wins; a tie is **ambiguous** and raises a blocking
`MissingRoute` exception rather than an arbitrary choice. No match is also blocking (F-009).

The system deliberately refuses to guess an approval route. A seeded example demonstrates this: a
Highly Confidential SOP currently matches two rules at equal specificity and blocks until Document
Control adds an explicit combined rule.

## 6. Exception model

| Type | Severity | Blocking | Safe to retry |
|---|---|:--:|:--:|
| `VersionIntegrity` | High | Yes | **No** — needs a human decision |
| `MissingRoute` | High | Yes | **No** — needs configuration |
| `DuplicateCurrentRevision` | High | Yes | Yes — the repair step only |
| `MissingCurrentRevision` | High | Yes | Yes |
| `MissingApprovalEvidence` | High | Yes | **No** — evidence cannot be manufactured later |
| `RetentionLabelFailure` | High | Yes | Yes |
| `StaleCheckOut` | Medium | No | n/a |
| `OwnerlessDocument` | High | No | n/a |
| `ConnectionExpired` | High | Yes | **No** |
| `NotificationFailure` | Low | No | Yes |
| `SearchFreshness` | Low | No | Yes |

While any blocking exception is open for a document, Flow 3 skips it. That is the mechanism behind
"blocking exceptions keep content non-effective" (F-022).

## 7. Notifications

Link-based only. Every notification carries Document ID, title, revision, effective date,
applicability, action, due date and a direct link. **No workflow email attaches the controlled file**
(F-017) — an attachment becomes an uncontrolled copy the moment it is sent, which is PRD risk R-11.

Notification failure never reverses publication; it raises a Low exception.

## 8. Ownership and offboarding

At least two administrative co-owners on every production flow (ADM-008). Connection reauthentication
and owner-departure procedures are in `docs/OPERATIONS_RUNBOOK.md`. An offboarding simulation is a
PRD acceptance criterion (28.8).

## 9. Build order

1. Create Dev/Test/Prod environments with the approved DLP policy (D-008).
2. Create the service identity and connections; add co-owners.
3. Build flows in Dev from the specifications, inside one solution.
4. Add environment variables and connection references — no hard-coded values.
5. Export managed; commit the unpacked source for review.
6. Import to Test with `deployment-settings.test.json`; run workflow tests.
7. Promote to Prod only after the production guard passes.
