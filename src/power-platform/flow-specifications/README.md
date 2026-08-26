# Power Automate flow specifications

These are implementation specifications, not a solution archive.

**No solution `.zip` is included in this repository, and none should be fabricated.** A Power
Platform solution package is a build artefact produced by exporting from a real Dev environment.
Committing a hand-written archive would produce a file that imports incorrectly or not at all, and
would misrepresent tenant work as complete. `Deploy-DmsPowerPlatform.ps1` reports the missing
package as a blocking action rather than pretending it exists.

Each specification is precise enough to build the flow without further design decisions: trigger,
trigger conditions, actions in order, expressions, JSON schemas, error handling, idempotency keys
and the PRD requirements it satisfies.

| Flow | Purpose | PRD requirements | Workflow |
|---|---|---|---|
| [Flow1-Request-Triage](Flow1-Request-Triage.md) | Request capture, duplicate detection, triage | F-002, F-007 | WF-01 |
| [Flow2-Submit-Review-Approve](Flow2-Submit-Review-Approve.md) | Version-locked review and approval | F-008 to F-011, NFR-011 | WF-02 |
| [Flow3-Scheduled-Activation](Flow3-Scheduled-Activation.md) | Future-effective activation and supersession | F-012 to F-014, F-017, F-018 | WF-03 |
| [Flow4-Periodic-Review](Flow4-Periodic-Review.md) | Review scheduling, reminders, escalation | F-015, F-016 | WF-04 |
| [Flow5-Exception-Management](Flow5-Exception-Management.md) | Exceptions, stale check-outs, reconciliation | F-022, F-023, NFR-014 | WF-06 |

## Rules that apply to every flow

1. **Solution-aware.** Every flow lives in the DMS solution and uses connection references and
   environment variables. No site URL, list GUID or group ID is hard-coded (PRD ADM-005, NFR-010).
2. **Never triggered by every file modification.** Lifecycle flows start on explicit submission or a
   schedule. A blanket "when a file is modified" trigger causes recursive runs and is forbidden
   (PRD F-008 acceptance criteria).
3. **Recursion guard.** Any flow that writes back to the item it triggered on sets
   `DmsAutomationWriteMarker` and its trigger condition excludes items last modified by the
   automation identity.
4. **Idempotent.** Every side effect is guarded by the idempotency key declared in
   `config/lifecycle-states.json`. Replaying a run must not create a duplicate effective revision,
   decision, assignment or notification (PRD NFR-006).
5. **Correlation.** Every run carries `DmsApprovalCorrelationId` into every evidence record, every
   exception and every notification (PRD F-010, F-022, UX-007).
6. **Durable evidence.** Decisions are written to the Approval Evidence list, never left only in
   flow run history, which expires (PRD C-007, R-12).
7. **Configuration over logic.** Thresholds and schedules are read from the Workflow Configuration
   list at run time so ordinary changes need no flow edit (PRD F-028).
8. **Errors never silently swallowed.** Every terminal failure writes an Exception Register item
   with severity, owner and correlation ID. Error text passes through redaction; no token, secret or
   document content is ever written (PRD SEC-004, section 17.3).
9. **Bounded retry.** Retry policy is exponential, 4 attempts maximum, honouring `Retry-After`
   (PRD NFR-015).
10. **Two co-owners.** No production flow has a sole personal owner (PRD SEC-004, ADM-008).

## Environment variables

| Schema name | Type | Purpose |
|---|---|---|
| `dms_SiteUrl` | String | DMS site URL for the environment |
| `dms_ControlledDocumentsListId` | String | Controlled Documents library id |
| `dms_ApprovalEvidenceListId` | String | Approval Evidence list id |
| `dms_ExceptionListId` | String | Exception Register list id |
| `dms_DocumentRegisterListId` | String | Document Register list id |
| `dms_RoutingRulesListId` | String | Routing Rules list id |
| `dms_WorkflowConfigListId` | String | Workflow Configuration list id |
| `dms_NotificationSender` | String | Service mailbox used for notifications |
| `dms_DocumentControlGroup` | String | Document Control escalation recipient |

## Connection references

| Logical name | Connector | Least-privilege note |
|---|---|---|
| `dms_sharepoint` | SharePoint | Service identity with contribute on the DMS site only |
| `dms_office365users` | Office 365 Users | Read-only identity lookup for owner-departure detection |
| `dms_office365outlook` | Office 365 Outlook | Send-only from the service mailbox, constrained by an application access policy |
| `dms_approvals` | Approvals | Task creation and response |
