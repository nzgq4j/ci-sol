# Document Controller Guide

You hold day-to-day accountability for control integrity.

## Daily

**Work queue** — requests awaiting triage, submissions in review, revisions approved and pending
effective, stale check-outs.

**Blocking exceptions first.** Two types outrank everything else:

- `DuplicateCurrentRevision` — more than one revision is flagged current. Readers may be seeing the
  wrong document *right now*.
- `MissingCurrentRevision` — the register expects a current revision and none exists.

Fix these before anything else. Both are Severity 1.

## Triage

For each request: is it complete, is it a duplicate, is the proposed owner right, and is it genuinely
new versus a revision?

**Accept** assigns the Document ID and creates the register entry. **Return** sends it back for more
information. **Reject** closes it with a rationale. **Escalate** routes it onward.

Document ID assignment is permanent. If the ID collides, triage blocks — the system will not silently
take the next free number, because an unexpected ID breaks the requester's traceability.

## Publication

You do not publish manually in normal operation. The scheduled activation flow publishes approved
revisions on their effective dates, re-validating first.

Manual activation exists as a fallback and is documented in `OPERATIONS_RUNBOOK.md` section 9. If you
use it, **you must write the Approval Evidence row yourself** — step 7 is not optional. A manual
activation with no evidence is indistinguishable from an unauthorised one.

## Stale check-outs

Reminder at the threshold (3 business days), escalation at twice that. Override requires a recorded
justification.

**Never discard a colleague's checked-out content to clear a queue.** Contact them first. The system
will not do it automatically, and neither should you.

## Exceptions you will handle

| Exception | Your action |
|---|---|
| `VersionIntegrity` | Author resubmits. **Do not force publication** — content changed after review |
| `MissingRoute` | Add an explicit routing rule; ask the author to resubmit |
| `DuplicateCurrentRevision` | Identify the intended revision from Approval Evidence, clear the flag on the other, rerun reconciliation. **Never delete a revision** |
| `MissingApprovalEvidence` | **Do not create evidence retrospectively.** Investigate how the revision became effective and treat it as a control failure |
| `OwnerlessDocument` | Reassign the owner |

Closing any exception requires a resolution reason.

## What you cannot do

You cannot alter completed Approval Evidence — nobody can, including platform administrators. You
cannot change retention labels or dispose of records; that is Records Management. You cannot approve
content where you are the sole author.

These limits are the point. They are what make the evidence you rely on trustworthy.

## Monthly

Metadata and evidence completeness (target 100%) · overdue reviews (target under 5%) · ownerless
documents (target zero) · approval cycle time · routing rules still resolving to active people.
