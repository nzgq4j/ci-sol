# Flow 4 — Periodic review

| Field | Value |
|---|---|
| Workflow | WF-04 |
| PRD requirements | F-015, F-016, MET-004, MET-005 |
| Trigger | Recurrence, daily, `ReviewSweepScheduleCron` |
| Idempotency key | `DocumentId + BusinessRevision + ReminderOffset` |

## Steps

### 1. Find upcoming and overdue reviews
```
DmsCurrentEffective eq 1 and DmsNextReviewDate le '<today + max reminder offset>'
```
Both columns indexed.

### 2. Determine which reminder is due
Reminder offsets come from the Review Frequencies list (default `90,30,7`). Fire a reminder only when
`daysUntilDue` equals an offset exactly, and only once per offset — the idempotency key prevents a
repeat if the sweep runs twice in a day.

### 3. Check owner is still active
`Get user profile (V2)` on `DmsDocumentOwner`.
A disabled or missing account raises an `OwnerlessDocument` exception assigned to Document Control and
escalates immediately rather than waiting for the review to lapse (PRD MET-005 target: zero).

### 4. Notify the owner
Task with four explicit outcomes: **Continue Valid**, **Revise**, **Withdraw**, **Emergency Suspend**.

### 5. Apply the outcome

| Outcome | Actions |
|---|---|
| **Continue Valid** | Evidence row (`ReviewDecision`). Recalculate `DmsNextReviewDate` with basis `PeriodicReviewDecision` and the decision reference. Document stays Effective. |
| **Revise** | Create a linked Change Request (`Revision`). Document **stays Effective** until the new revision activates. |
| **Withdraw** | Route to an authorised approver. On approval, lifecycle `Effective → Withdrawn` (T-15). |
| **Emergency Suspend** | Immediate `Effective → Withdrawn` (T-15) with mandatory rationale, plus a post-hoc review task for Document Control. Suspension is the one path that acts before approval, because leaving a known-unsafe instruction effective is the greater risk. |

### 6. The critical control — no silent roll-forward

`DmsNextReviewDate` is updated **only** inside the Continue Valid branch, and only with an evidence
row already written. There is no path in this flow that advances the review date without an
attributable decision. PRD F-015 states the date "cannot roll forward without a recorded decision",
and this is the mechanism.

A common shortcut — advancing the date when a reminder is sent, to stop repeat notifications — is
specifically **not** implemented. Repeat reminders are suppressed by the idempotency key instead.

### 7. Escalate non-response
When `daysOverdue >= EscalateAfterDaysOverdue`, notify the escalation contact from Review Frequencies
and raise a Medium exception. The document remains Effective and overdue; it is **not** withdrawn
automatically, because an overdue review is not evidence that the content is wrong.

## Error handling
| Condition | Type | Severity | Blocking |
|---|---|---|---|
| Owner departed | `OwnerlessDocument` | High | No |
| No response past escalation | `FlowFailure` | Medium | No |
| Withdrawal approval failure | `FlowFailure` | High | Yes |
