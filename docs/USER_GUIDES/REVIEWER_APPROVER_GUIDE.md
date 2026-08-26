# Reviewer and Approver Guide

## What your task tells you

Every task shows the exact file version, the Document ID and revision, the change summary, a link to
the previous revision, the due date, the stage, and what happens if you approve or reject.

You are reviewing **that exact version**. If the author changes the file after submission, your
decision is invalidated rather than applied to content you did not see.

## Reviewer versus Approver

**Reviewer** — verifies technical accuracy and usability. A review stage may run in parallel with
other reviewers, with a quorum of All, Any or Majority.

**Approver** — accepts business, quality, legal or risk accountability. Approval stages are usually
serial and come last.

Both decisions are recorded identically: actor, role, stage, outcome, timestamp, comments, file
version and ETag.

## Approving

Approval means the content is correct **and** you accept accountability for it being used.

Approval does **not** publish the document. The revision moves to *Approved Pending Effective* and is
activated on its effective date by a scheduled process, which re-checks that the file still matches
what you approved.

## Rejecting

Rejection requires a rationale. It is not optional, and the reason is what the author works from.

Say what is wrong and what would make it acceptable. "Section 4.2 does not reflect the two-person
verification rule agreed in the March change" is actionable; "not right" is not.

Rejection returns the document to Rework. The current effective revision stays untouched and visible.

## What you cannot do, and why

- **You cannot approve a document where you are the sole author.** The system removes you from the
  route. If that leaves the stage empty, it blocks and asks Document Control for an independent
  reviewer rather than proceeding.
- **You cannot edit an effective revision.** Changes go through a new revision.
- **You cannot alter a decision after recording it.** A correction is a new, attributable record. That
  is what makes the evidence trail worth having.

## If a route is wrong

If the task reaches the wrong person, or nobody, tell Document Control. Routes are configuration and
can be corrected without changing any workflow logic.

If routing is ambiguous — two rules matching equally — the system **blocks and raises an exception
rather than guessing** which approver is correct. Document Control resolves it by adding an explicit
rule.

## Delegation

Where an approved delegation exists, the decision records both the delegate and the person delegated
from. A decision taken outside an approved delegation is not valid evidence.
