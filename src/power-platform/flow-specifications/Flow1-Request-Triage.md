# Flow 1 — Request and triage

| Field | Value |
|---|---|
| Workflow | WF-01 |
| PRD requirements | F-002, F-007, DATA-003 |
| Trigger | `When an item is created` on Change Requests |
| Idempotency key | `RequestId + TriageDecision` |

## Trigger condition
```
@equals(triggerOutputs()?['body/DmsRequestStatus/Value'], 'Submitted')
```

## Steps

### 1. Assign a request ID
Read the current sequence from Workflow Configuration (`RequestSequence`), increment it, and format:
```
concat('CR-', formatDateTime(utcNow(),'yyyy'), '-', formatNumber(add(int(body('Get_sequence')?['DmsSettingValue']),1),'000000'))
```
Update the sequence setting in the same run. On a concurrency clash the update fails, the run retries
with backoff, and a second ID is never issued for the same item.

### 2. Validate required data
Required: `DmsRequestType`, `DmsJustification`, `DmsUrgency`, `DmsAffectedProcess`, `DmsProposedOwner`,
`DmsImpactedAudience`. For `Revision` and `Withdrawal`, `DmsRequestedDocumentId` is also required.
```
@and(
  not(empty(triggerOutputs()?['body/DmsJustification'])),
  if(or(equals(triggerOutputs()?['body/DmsRequestType/Value'],'Revision'),
        equals(triggerOutputs()?['body/DmsRequestType/Value'],'Withdrawal')),
     not(empty(triggerOutputs()?['body/DmsRequestedDocumentId'])), true)
)
```
On failure set status `Returned` with field-level guidance. This is a user error, not an exception.

### 3. Detect potential duplicates
Query open requests for the same `DmsAffectedProcess` and `DmsRequestedDocumentId` in the last 90 days.
The flow **flags** candidates for the controller; it never auto-rejects, because duplicate detection
on free-text justification is not reliable enough to make an automated rejection decision.

### 4. Route to Document Control
`Start and wait for an approval` — `Custom Responses`: **Accept**, **Return**, **Reject**, **Escalate**,
assigned to the Document Control group from `dms_DocumentControlGroup`.
Rationale is mandatory for Return, Reject and Escalate.

### 5. Apply the decision

| Response | Actions |
|---|---|
| **Accept** | Assign Document ID (see below). Create or link the Document Register item. Set `DmsRequestStatus = Accepted`. Lifecycle `Requested → Triaged` (T-01). |
| **Return** | `Returned` + rationale. Requester may correct and resubmit. |
| **Reject** | `Rejected` + rationale. Lifecycle `Requested → Withdrawn` (T-02). |
| **Escalate** | `Escalated`, notify the escalation contact. Request stays open. |

### 6. Document ID assignment (Accept, New Document only)
Validate against the approved namespace pattern and check uniqueness across the Document Register.
```
Filter: DmsDocumentId eq '<candidate>'
Condition: length(body('Filter')) == 0
```
A collision creates a **blocking** exception and leaves the request in triage. It never silently
increments to the next free number, because a Document ID is a persistent identifier and an
unexpected one breaks the requester's traceability (PRD F-002).

For `Revision`, the existing Document ID is reused and the business revision increments.

### 7. Record decision evidence
Approval Evidence row: outcome (`Submitted` for accept, `Cancelled` for reject), actor, timestamp,
rationale, correlation ID.

## Error handling
| Condition | Type | Severity | Blocking |
|---|---|---|---|
| Duplicate Document ID | `FlowFailure` | High | Yes |
| Register write failure | `FlowFailure` | High | Yes |
| Proposed owner not an active identity | `OwnerlessDocument` | Medium | Yes |
