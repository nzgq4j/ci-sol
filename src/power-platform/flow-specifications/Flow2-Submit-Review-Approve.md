# Flow 2 — Submit, review and approve

| Field | Value |
|---|---|
| Workflow | WF-02 |
| PRD requirements | F-008, F-009, F-010, F-011, NFR-011, NFR-006, SEC-003 |
| Risk mitigated | **R-05** — content changes after submission but approval is applied to the wrong revision |
| Trigger | Manual (selected item) on Controlled Documents, or HTTP request from the intake app |
| Idempotency key | `DmsApprovalCorrelationId` |

This is the flow that carries the PRD's single most important integrity control: **an approval must
apply to the exact revision that was reviewed.**

## Trigger

`When an item is selected` (SharePoint) on the Controlled Documents library, or `When an HTTP
request is received` from the Document Control app.

It is deliberately **not** `When a file is created or modified`. That trigger fires on every save,
including the flow's own metadata writes, causing recursive runs and starting approvals nobody
requested (PRD F-008: "start only on explicit submission, not every file modification").

### Trigger condition

```
@and(
  equals(triggerOutputs()?['body/DmsLifecycleStatus/Value'], 'Authoring'),
  not(equals(triggerOutputs()?['body/Editor/Email'], parameters('dms_AutomationIdentity')))
)
```

The second clause is the recursion guard.

## Steps

### 1. Initialise correlation

```
Compose  CorrelationId = guid()
```
Written to `DmsApprovalCorrelationId` on the item and carried into every evidence row, exception and
notification.

### 2. Validate mandatory metadata

Check every field in the content type's `requiredFields` (`config/content-types.json`).

```
@empty(coalesce(triggerOutputs()?['body/DmsChangeSummary'], ''))
```

On failure: **terminate with Failed**, return field-level guidance to the author, and do **not**
create an exception — an incomplete submission is a user error, not a system fault. The message
follows PRD UX-007: what happened, whether work was saved (it was — the draft is untouched), the
corrective action, and the correlation ID.

### 3. Capture version and ETag — the integrity anchor

```
Get file metadata (SharePoint)   → outputs('Get_file_metadata')?['ETag']
Get file properties (SharePoint) → outputs('Get_file_properties')?['{VersionNumber}']
```

Write to the item:

| Field | Value |
|---|---|
| `DmsSubmittedETag` | `@{outputs('Get_file_metadata')?['ETag']}` |
| `DmsSubmittedVersion` | `@{outputs('Get_file_properties')?['{VersionNumber}']}` |
| `DmsApprovalCorrelationId` | `@{outputs('Compose_CorrelationId')}` |

**Capture happens before any task is created.** If a task were created first, a change made in the
gap would be invisible to the integrity check.

### 4. Resolve the routing rule

Query the Routing Rules list filtered to active rules, then apply the resolution algorithm in
`config/routing-rules.json`: highest specificity wins; a tie is ambiguous.

```
Filter array  specificity == max(specificity)
Condition     length(body('Filter_winners')) == 1
```

| Outcome | Action |
|---|---|
| Exactly one winner | Continue |
| More than one | Create a **blocking** `MissingRoute` exception naming the competing rules. Terminate. Do **not** pick one. |
| Zero | Create a **blocking** `MissingRoute` exception. Terminate (PRD F-009). |

Then remove the sole author from the assignee list (PRD SEC-003). If a stage empties, raise a
blocking exception rather than approving with a smaller set.

### 5. Set lifecycle state

Transition `Authoring → In Review` (T-05). Update `DmsLifecycleStatus`.

### 6. Run the stages

`Do until` over stages ordered by sequence.

- **Serial stage** — `Start and wait for an approval`, type `Approve/Reject - First to respond`.
- **Parallel stage** — type `Approve/Reject - Everyone must approve` for quorum `All`;
  `First to respond` for `Any`. For `Majority`, use a parallel `Start an approval` per assignee and
  evaluate `length(filter(outcomes, equals(item()?['outcome'],'Approve'))) > div(length(assignees),2)`.

Each task shows Document ID, title, business revision, change summary, prior revision link, due date,
stage name and the consequence of approving or rejecting (PRD UX-006).

Due date: `addDays(utcNow(), stage.dueBusinessDays)` adjusted for weekends using the business
calendar (PRD OQ-18 — assumption stated in `docs/OPEN_DECISIONS.md`).

### 7. Re-check integrity before recording each decision

```
@equals(outputs('Get_file_metadata_2')?['ETag'], triggerOutputs()?['body/DmsSubmittedETag'])
```

If the ETag no longer matches:

1. Write Approval Evidence with outcome `Invalidated`.
2. Create a **High, blocking** `VersionIntegrity` exception.
3. Set lifecycle to `Rework` (T-12 semantics).
4. Cancel any outstanding tasks.
5. Terminate.

**The approval is not recorded against the changed content under any circumstance.** This is the
control that makes PRD acceptance criterion "a content change after submission prevents approval of
the changed version" true.

### 8. Write Approval Evidence for every decision

One row per decision — not one per flow run — created with `Create item` on the Approval Evidence
list:

| Column | Expression |
|---|---|
| `DmsApprovalCorrelationId` | `@{outputs('Compose_CorrelationId')}` |
| `DmsDocumentId` | `@{triggerOutputs()?['body/DmsDocumentId']}` |
| `DmsBusinessRevision` | `@{triggerOutputs()?['body/DmsBusinessRevision']}` |
| `DmsEvidenceFileVersion` | `@{triggerOutputs()?['body/DmsSubmittedVersion']}` |
| `DmsEvidenceETag` | `@{triggerOutputs()?['body/DmsSubmittedETag']}` |
| `DmsDecisionStage` | `@{items('For_each_stage')?['DmsRuleStageName']}` |
| `DmsDecisionActor` | `@{body('Start_and_wait_for_an_approval')?['responses'][0]['responder']['email']}` |
| `DmsDecisionOutcome` | `@{body('Start_and_wait_for_an_approval')?['outcome']}` |
| `DmsDecisionTimestampUtc` | `@{utcNow()}` |
| `DmsDecisionComments` | `@{body('Start_and_wait_for_an_approval')?['responses'][0]['comments']}` |
| `DmsTaskReference` | `@{body('Start_and_wait_for_an_approval')?['responses'][0]['requestDate']}` |

Evidence is written by the automation identity, the only principal with write access to that list
(`config/security-roles.json`). This is what makes evidence tamper-resistant and independent of flow
run history (PRD F-010, C-007, R-12).

### 9. Rejection path

On any `Reject`:

1. Evidence row with outcome `Rejected`. **Comments are mandatory** — if empty, re-prompt rather than
   record a rationale-free rejection (PRD F-011).
2. Lifecycle `In Review → Rework` (T-07).
3. Cancel remaining stage tasks.
4. Notify the author with the comments and a link.
5. **The current effective revision is untouched and remains visible to readers.**

Resubmission creates a **new** correlation ID and a **new** approval instance. A rejected decision is
never reused.

### 10. Final approval

When all required stages approve:

1. Validate `DmsEffectiveDate` is present and `DmsRetentionClass` is mapped.
2. Evidence row with outcome `Approved`, storing `DmsApprovedETag`.
3. Lifecycle `In Review → Approved Pending Effective` (T-08).
4. Set native content approval status to Approved.
5. **Do not publish.** Publication is Flow 3's responsibility, even when the effective date is today.
   Approval and activation are separate so a future effective date cannot be bypassed (PRD F-012).

## Error handling

Every scope has a `Configure run after` failure path that creates an Exception Register item:

| Condition | Type | Severity | Blocking |
|---|---|---|---|
| ETag mismatch | `VersionIntegrity` | High | Yes |
| No/ambiguous route | `MissingRoute` | High | Yes |
| Approver no longer active | `FlowFailure` | High | Yes |
| Approvals connector failure | `FlowFailure` | Medium | Yes |
| Notification failure | `NotificationFailure` | Low | No |

Retry policy on every SharePoint and Approvals action: exponential, 4 retries, 20-second interval.
