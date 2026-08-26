# Flow 5 — Exception and stale check-out management

| Field | Value |
|---|---|
| Workflow | WF-06 |
| PRD requirements | F-022, F-023, NFR-006, NFR-014, MET-007, MET-008 |
| Trigger | Recurrence, four-hourly, `ExceptionSweepScheduleCron` |
| Idempotency key | `ExceptionType + AffectedItemId + DetectedDate` |

This flow is the system's self-check. Everything it detects is a condition that would otherwise fail
silently.

## Detections

### 1. Stale check-outs (F-023, MET-008)
```
Get items where CheckoutUser ne null
daysCheckedOut = business days since Modified
threshold = Workflow Configuration StaleCheckOutThresholdBusinessDays (default 3)
```
- At threshold: remind the check-out owner.
- At 2× threshold: escalate to Document Control with ageing.
- **Never discard checked-out content automatically.** A controller override requires a recorded
  justification and produces evidence (PRD F-023: "no automatic discard of content occurs without
  approved rule").

### 2. Failed or suspended flow runs
Query run history for the DMS solution flows. Any terminal failure without a matching Exception
Register row gets one — this catches failures that occurred *before* a flow's own error handler could
run, which is exactly the silent-failure class PRD F-022 targets.

### 3. Zero or multiple effective revisions (F-013)
Group current-effective items by `DmsDocumentId + Applicability`.

| Condition | Type | Severity | Blocking |
|---|---|---|---|
| count > 1 | `DuplicateCurrentRevision` | High | Yes |
| count = 0 but the register expects one | `MissingCurrentRevision` | High | Yes |

Both are Critical-adjacent: they are the direct source of PRD MET-014 incidents.

### 4. Missing approval evidence (F-010)
Every `Effective` revision must have an Approval Evidence row with outcome `Approved` for its exact
business revision. A gap means a revision became effective without traceable approval, which is a
control failure, not a data-quality nit.

### 5. Retention-label mismatch (F-018, MET-010)
Compare the applied label with the mapped retention class. Mismatch or absence raises a High
exception for Records Management.

### 6. Permission and sharing exceptions (F-024, F-025, SEC-002)
Detect direct user permissions (not via group), unexpected guests, and any sharing setting other than
Disabled. Each is an exception by definition in this design.

### 7. Expired or failing connections (ADM-008)
Test each connection reference. An expired connection is High and blocking, because every lifecycle
flow depends on it.

## Safe retry

Retry is attempted **only** where the operation is idempotent and the retry count is below
`MaxSafeRetries` (default 3):

| Type | Safe to retry? | Why |
|---|---|---|
| `NotificationFailure` | Yes | Resend is harmless |
| `RetentionLabelFailure` | Yes | Label application is idempotent |
| `DuplicateCurrentRevision` | Yes — repair step only | Clearing the flag on the older revision is idempotent |
| `VersionIntegrity` | **No** | Requires a human decision; retrying cannot make changed content approved |
| `MissingRoute` | **No** | Requires a configuration change |
| `MissingApprovalEvidence` | **No** | Evidence cannot be manufactured after the fact |

Retries never re-run a whole flow — only the specific idempotent repair step.

## Prevent unsafe publication
While any **blocking** exception is open for a document, Flow 3 skips it. This is the mechanism
behind PRD F-022: "blocking exceptions keep content non-effective".

## Escalate aged exceptions (MET-007)
Any blocking exception open longer than `AgedBlockingExceptionHours` (default 24) is escalated to
Document Control and the Product Owner. Target is zero.

## Closure
Closing an exception requires `DmsResolutionReason`. The flow never auto-closes a blocking exception;
it may auto-close a non-blocking one whose condition it re-tests as resolved.
