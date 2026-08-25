# Operations Runbook

## 1. Daily

| Check | Where | Action on breach |
|---|---|---|
| Open blocking exceptions | Exception Register → *Open Blocking Exceptions* | Any older than 24h escalates (MET-007, target 0) |
| Duplicate or missing current revision | Exception Register, types `DuplicateCurrentRevision` / `MissingCurrentRevision` | **Immediate.** Highest-severity condition in the system (MET-014) |
| Failed flow runs | Power Automate run history + Exception Register | Diagnose; do not blind-retry a non-idempotent step |
| Activation sweep completed | Flow 3 run history | If missed, next run self-corrects; confirm no revision is stuck |
| Ownerless effective documents | Document Register | Reassign owner (MET-005, target 0) |

## 2. Weekly

Stale check-outs (MET-008, target <2%) · overdue reviews (MET-004, target <5%) · approval cycle time
(MET-003) · direct-permission and sharing exceptions · connection health.

## 3. Monthly

Configuration drift (`Export-DmsConfiguration -CompareToBaseline`) · retention-label conformance
sampling (MET-010) · disposition backlog (MET-011) · access review · adoption (MET-013) ·
Microsoft Message Center review for service changes affecting connectors or limits (ADM-011, R-15).

## 4. Quarterly

Recovery exercise (MET-015) · service-owner offboarding simulation · file plan and classification
review (ADM-012) · PnP dependency upgrade test with index regeneration (ADM-007).

## 5. Exception response

| Type | Severity | First action |
|---|---|---|
| `VersionIntegrity` | High | **Do not force publication.** Content changed after review; author resubmits for a new approval instance |
| `DuplicateCurrentRevision` | High | Identify the intended revision from Approval Evidence; clear `DmsCurrentEffective` on the other; rerun reconciliation |
| `MissingCurrentRevision` | High | Check whether activation half-completed; rerun Flow 3 for the document (idempotent) |
| `MissingApprovalEvidence` | High | **Do not manufacture evidence.** Investigate how the revision became effective; treat as a control failure |
| `MissingRoute` | High | Add an explicit routing rule; resubmit |
| `RetentionLabelFailure` | High | Records Management. Activation is not reversed |
| `StaleCheckOut` | Medium | Remind owner; escalate at 2× threshold; override only with recorded justification |
| `ConnectionExpired` | High | Reauthenticate (section 6); verify co-owners |
| `OwnerlessDocument` | High | Reassign through Document Control |
| `NotificationFailure` | Low | Resend; publication stands |
| `SearchFreshness` | Low | Direct link is the fallback; monitor |

**Never** close a blocking exception without `DmsResolutionReason`. **Never** resolve a
`DuplicateCurrentRevision` by deleting a revision — clear the flag instead.

## 6. Connection renewal (ADM-008)

1. Sign in as the service identity owner.
2. Power Platform → Solutions → DMS → Connection References.
3. Reauthenticate the expired reference.
4. Confirm at least two co-owners remain.
5. Rerun one flow to confirm.
6. Record the change.

**Do not** repoint a connection reference to a personal account. That reintroduces PRD risk R-09.

## 7. User offboarding

| Role | Action |
|---|---|
| Document owner | Reassign every owned effective document before the account is disabled |
| Approver | Remove from the group; update routing rules that name them individually |
| Flow co-owner | Add a replacement **before** removing them, so the count never drops below two |
| Document Controller | Transfer the open work queue |

Run the ownerless-document report immediately after any offboarding.

## 8. Microsoft service-change review (ADM-011, R-15)

Monthly, check Message Center and the roadmap for changes to: SharePoint connector actions, list view
threshold, retention label behaviour, Approvals, and PnP PowerShell releases.

For a connector or cmdlet change: regenerate the PnP index, rerun validation, run the regression
suite in Test before Prod.

## 9. Manual fallback (NFR-003)

If the flows are unavailable, readers retain full access to current documents — the current-document
view is a SharePoint view, not a flow output. Nothing about reading depends on automation.

Manual activation by a Document Controller, for an approved revision whose effective date has passed:

1. Verify Approval Evidence exists for the exact revision.
2. Verify the file has not changed since approval (compare ETag).
3. Publish the major version.
4. Set `DmsLifecycleStatus = Effective`, `DmsCurrentEffective = true`.
5. Set the prior revision to `Superseded`, `DmsCurrentEffective = false`.
6. Update the Document Register.
7. Record an Approval Evidence row with outcome `Activated`, role `Document Controller`.

Step 7 is not optional. A manual activation with no evidence is indistinguishable from an
unauthorised one.
