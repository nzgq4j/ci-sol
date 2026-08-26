# Flow 3 — Scheduled activation and supersession

| Field | Value |
|---|---|
| Workflow | WF-03 |
| PRD requirements | F-012, F-013, F-014, F-017, F-018, NFR-006, NFR-017 |
| Risk mitigated | **R-20**, **MET-014** — more than one revision presented as current |
| Trigger | Recurrence, daily, schedule from Workflow Configuration `ActivationScheduleCron` |
| Idempotency key | `DocumentId + BusinessRevision + Activated` |

This flow is **scheduled**, not a long-running wait. A flow that waits months for an effective date
is fragile: it breaks on connection expiry, solution reimport and owner offboarding. The PRD
requires scheduled activation for exactly this reason.

## Steps

### 1. Find due revisions
```
Get items (Controlled Documents)
Filter Query:
  DmsLifecycleStatus eq 'Approved Pending Effective' and DmsEffectiveDate le '@{formatDateTime(utcNow(),'yyyy-MM-dd')}T23:59:59Z'
```
Both filter columns are indexed (`config/libraries.json`), so this stays within list-view threshold
limits at the PRD NFR-004 volume of 50,000 documents.

### 2. Per revision — revalidate before publishing

Every check must pass. Any failure **stops that revision only** and leaves the current effective
revision untouched. One bad revision never blocks the rest of the batch.

| # | Check | Failure action |
|---|---|---|
| 1 | Already activated? (`DmsCurrentEffective` true) | Skip silently — idempotency guard for replay |
| 2 | ETag matches `DmsApprovedETag` | `VersionIntegrity` High blocking exception; lifecycle → `Rework` (T-12); **do not publish** |
| 3 | Approval Evidence exists with outcome `Approved` for this revision | `MissingApprovalEvidence` High blocking exception |
| 4 | Mandatory metadata complete | `FlowFailure` High blocking exception |
| 5 | No open blocking exception for this document | Skip; retry next run |
| 6 | Retention class approved | `RetentionLabelFailure` High blocking exception; **do not publish** |

Check 2 is the one that makes the PRD acceptance criterion true: *a changed file cannot receive
approval intended for an earlier version*. It runs here as well as in Flow 2 because the file can
change in the gap between approval and the effective date.

### 3. Identify the outgoing revision
```
Get items: DmsDocumentId eq '<id>' and DmsCurrentEffective eq 1
```
Compare applicability. Only a revision sharing the applicability context is superseded.

If more than one is returned, the invariant is **already** broken: raise a `DuplicateCurrentRevision`
High blocking exception and do not activate. Activating into a broken state would compound it.

### 4. Activate — ordered to avoid a visible gap

```
1. Publish major version           (Set-PnPListItem UpdateType / SharePoint "Publish" action)
2. New revision:      DmsLifecycleStatus = Effective, DmsCurrentEffective = true,
                      DmsSharePointVersionRef = <published version>, DmsSupersedes = <prior id+rev>
3. Prior revision:    DmsLifecycleStatus = Superseded, DmsCurrentEffective = false,
                      DmsSupersededBy = <new id+rev>
4. Document Register: current link, revision, effective date, next review date
5. Apply retention label
6. Create acknowledgement assignments where DmsTrainingRequired
7. Send link-based notification
```

**Step 2 precedes step 3 deliberately.** Between them, two revisions are briefly flagged current.
That is the safe direction of failure: readers momentarily seeing a *newer* approved revision
alongside the old one is far less harmful than a gap in which **no** current revision exists and the
portal shows nothing. Step 3 is retried under its idempotency key, and the reconciliation sweep in
Flow 5 detects and repairs a stuck intermediate state.

SharePoint does not offer a cross-item transaction, so this ordering plus reconciliation is the
mitigation, and it is stated rather than assumed.

### 5. Next review date
```
addToTime(<effective date>, <DmsReviewFrequencyMonths>, 'Month')
```
Basis `InitialActivation` — no prior review decision is required for the first calculation.

### 6. Notify — links, never attachments
Body contains Document ID, title, revision, effective date, applicability, required action, due date
and a **direct link**. No workflow email attaches the controlled file (PRD F-017).

Notification failure raises a **Low, non-blocking** exception. Publication is **not** reversed —
the document is genuinely effective; only the announcement failed.

## Post-activation reconciliation
Immediately after the batch, re-run the uniqueness check across all activated documents
(`Test-DmsEffectiveRevisionUniqueness`). Any violation raises a High blocking exception. This is the
direct control for PRD MET-014.

## Error handling
| Condition | Type | Severity | Blocking | Reverses activation? |
|---|---|---|---|---|
| ETag mismatch | `VersionIntegrity` | High | Yes | Not activated |
| Duplicate current revision | `DuplicateCurrentRevision` | High | Yes | No — repair forward |
| Supersession step failed | `DuplicateCurrentRevision` | High | Yes | No — retry step 3 |
| Retention label failed | `RetentionLabelFailure` | High | Yes | No — PRD recovery behaviour |
| Notification failed | `NotificationFailure` | Low | No | No |
| Search not yet indexed | `SearchFreshness` | Low | No | No — direct link is the fallback (NFR-017) |
