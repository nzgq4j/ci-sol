# Author Guide

## 1. Start with a request, not a document

Every controlled document starts as a **Change Request** — new document, revision, withdrawal or
emergency change. Document Control triages it and assigns the Document ID.

This is not bureaucracy: it is what prevents two people independently writing the same SOP and what
guarantees the ID is unique and permanent.

Provide: request type, justification, urgency, affected process, proposed owner, impacted audience and
the requested effective date. An incomplete request is returned with specific guidance, not rejected.

## 2. Author from the approved template

Once triaged, work from the controlled template. The control header (ID, revision, effective date,
owner, review date, classification) is **bound to the document properties** — do not type those
values, and do not maintain a revision-history table in the body. The DMS holds both.

While you are authoring, the document is at **minor versions** (1.1, 1.2…). Readers cannot see them.
The previous approved revision stays visible and effective throughout — your draft never disturbs it.

## 3. Check-out

Controlled Documents does **not** force check-out, so you can co-author. Templates does force
check-out, because concurrent template editing causes drift.

If you do check something out, check it back in. A check-out left beyond three business days triggers
a reminder, then escalation. Content is never discarded automatically — but an abandoned lock blocks
your colleagues.

## 4. Complete the metadata

Required before submission: Document Type, Business Function, Business Process, Document Owner,
Sensitivity Classification, Applicability, Retention Class, Review Frequency and a **Change Summary**.

The Change Summary is what reviewers read first. "Updated" is not useful. "Section 4.2 revised to
require two-person verification before release" is.

## 5. Submit

Submission is explicit — the flow does not start when you save. At submission the system captures the
exact file version and its ETag.

**This is why you must not edit after submitting.** If the file changes, the approval no longer applies
to what was reviewed: the approval is invalidated, the document returns to Rework, and reviewers must
start again. If you realise a change is needed, withdraw the submission rather than editing underneath
it.

## 6. If it is rejected

Rejection returns the document to Rework with mandatory comments explaining why, tied to the exact
revision reviewed. Fix the content and resubmit — this creates a **new** approval instance. The
previous rejection is retained as evidence; it is not overwritten.

The current effective revision was never affected.

## 7. Approved, but not yet effective

After approval the document sits in **Approved Pending Effective** until its effective date. It is not
visible to readers as current and does not replace the existing revision until then.

Activation happens automatically on a daily sweep. You do not need to do anything.

## 8. After it is effective

You will be reminded before the review date (90, 30 and 7 days by default). At review you choose:
**Continue Valid**, **Revise**, **Withdraw**, or **Emergency Suspend**.

The review date only moves forward when you record a decision. There is no way to make a reminder go
away without making a decision — that is deliberate.

## Common mistakes

| Mistake | What happens |
|---|---|
| Editing after submission | Approval invalidated; back to Rework |
| Typing the revision number into the body | Diverges from the real revision; use the bound property |
| Saving a completed form over the blank template | Destroys the template and misfiles the record |
| Emailing the document as an attachment | Creates an uncontrolled copy; send the link |
| Naming files `SOP v2 final FINAL.docx` | The DMS holds the revision; the filename should not |
