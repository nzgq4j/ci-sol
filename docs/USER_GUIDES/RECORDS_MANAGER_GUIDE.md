# Records Manager Guide

## Before anything is configured

**No retention is applied until you approve the file plan.** Every retention class currently reads
`REQUIRES_RECORDS_APPROVAL`, and the deployment script refuses to apply retention while that is true.
This is deliberate: labels configured before an approved schedule cause over-retention, premature
disposal, or content that cannot be deleted when it should be.

Five classes await your approval: Completed Inspection Record, Superseded Controlled Document
Revision, Approval Evidence, Change Request, Acknowledgement Response.

For each, supply: retention authority, trigger, trigger type, period, disposition action, and whether
it is declared a record.

## Irreversible controls

| Control | Status | Why |
|---|---|---|
| Regulatory record label | **Prohibited in MVP** | Cannot be removed by anyone, ever — including a Global Administrator |
| Preservation Lock | **Prohibited in MVP** | Cannot be reduced or removed once applied |
| Automatic permanent deletion | **Prohibited in MVP** | No review step before irreversible loss |

Enabling any of these requires three things together: the environment flag set, an explicit
authorisation switch on the command, and a **signed decision record** from Records Management and
Legal. Missing any one produces a blocked action naming exactly what is absent.

Applying a regulatory label to the wrong class permanently prevents legitimate revision and disposal.
There is no rollback to plan for — prevention is the only control.

## Disposition

Disposition review is the default path, not automatic deletion. You see items reaching end of
retention, decide, and the outcome is recorded with rationale and exported as proof.

A legal or eDiscovery hold overrides disposition. Held items are excluded and reported separately —
never silently skipped.

**No user-interface delete substitutes for disposition.** That is why business users hold a permission
level with delete rights removed.

## Records versus documents

A **controlled document** is instruction: it has a lifecycle, an owner, revisions and a review date.

An **operational record** is evidence that something happened: it is captured, not authored, has no
lifecycle status, and is governed by retention from the moment of capture.

A blank form is a document. The completed form is a record. Getting this wrong applies the wrong
retention to both.

## Superseded revisions

Superseded revisions are retained, not deleted. That is what lets an auditor establish what was
effective on a past date. Their retention class is separate from the current revision's.

## Monthly

Label coverage (target 100% of in-scope classes) · label conformance sampling · disposition backlog ·
hold conflicts · personal-data classes still justified for their retention period.

## Personal data

Acknowledgement records contain personal data. Retain only as long as the approved evidence
requirement — storage limitation applies. Access is restricted to the assignee, their manager and the
process owner.
