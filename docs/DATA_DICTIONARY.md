# Data Dictionary

> **Generated file.** Produced by `src/reporting/New-DmsDocumentation.ps1` from `config/site-columns.json`, `config/content-types.json` and `config/lists.json`. Do not edit by hand; edit the configuration and regenerate.

Implements PRD section 17 (Data Requirements). Internal names are stable contracts referenced by views, flows, search mappings, reports and provisioning scripts, and must not be renamed after first deployment.

## Site columns

| Internal name | Display name | Type | Required | Indexed | Data owner | Sensitivity | Set by | Editable in states | PRD |
|---|---|---|---|:--:|---|---|---|---|---|
| `DmsDocumentId` | Document ID | Text | Yes | Yes | Document Control | Internal | SystemAutomation | _none — system only_ | F-002, DATA-001 |
| `DmsDocumentType` | Document Type | Choice | Yes | Yes | Document Control | Internal | DocumentController | Triaged, Authoring | F-001, F-003, DATA-001 |
| `DmsBusinessFunction` | Business Function | TaxonomyFieldType | Yes | Yes | Document Control | Internal | Author | Triaged, Authoring, Rework | F-001, F-026, DATA-001 |
| `DmsBusinessProcess` | Business Process | TaxonomyFieldType | Yes | Yes | Document Control | Internal | Author | Triaged, Authoring, Rework | F-001, F-026, DATA-001 |
| `DmsDocumentOwner` | Document Owner | User | Yes | Yes | Document Control | Personal | DocumentController | Triaged, Authoring, Rework, Effective | F-015, F-024, DATA-001 |
| `DmsAuthor` | Author | UserMulti | No |  | Document Owner | Personal | DocumentController | Triaged, Authoring, Rework | DATA-001 |
| `DmsReviewer` | Reviewer | UserMulti | No |  | Document Control | Personal | DocumentController | Triaged, Authoring, Rework | F-009, DATA-004 |
| `DmsApprover` | Approver | UserMulti | No |  | Document Control | Personal | DocumentController | Triaged, Authoring, Rework | F-009, SEC-003, DATA-004 |
| `DmsLifecycleStatus` | Lifecycle Status | Choice | Yes | Yes | Document Control | Internal | SystemAutomation | _none — system only_ | F-005, F-012, F-013 |
| `DmsBusinessRevision` | Business Revision | Text | Yes |  | Document Control | Internal | SystemAutomation | _none — system only_ | F-002, DATA-002 |
| `DmsSharePointVersionRef` | SharePoint Version Reference | Text | No |  | Platform | Internal | SystemAutomation | _none — system only_ | F-010, NFR-011, DATA-002 |
| `DmsEffectiveDate` | Effective Date | DateTime | No | Yes | Document Control | Internal | DocumentController | Authoring, Rework, InReview | F-012, DATA-002 |
| `DmsNextReviewDate` | Next Review Date | DateTime | No | Yes | Document Owner | Internal | SystemAutomation | _none — system only_ | F-015, MET-004 |
| `DmsReviewFrequencyMonths` | Review Frequency (months) | Number | Yes |  | Document Owner | Internal | DocumentOwner | Triaged, Authoring, Rework, Effective | F-015 |
| `DmsSensitivityClassification` | Sensitivity Classification | Choice | Yes | Yes | Security and Privacy | Internal | Author | Triaged, Authoring, Rework | SEC-006, SEC-008, DATA-001 |
| `DmsApplicability` | Applicability | TaxonomyFieldTypeMulti | Yes |  | Document Control | Internal | Author | Triaged, Authoring, Rework | F-013, F-026, UX-003 |
| `DmsSiteRegion` | Site or Region | TaxonomyFieldTypeMulti | No |  | Document Control | Internal | Author | Triaged, Authoring, Rework | F-026, UX-003 |
| `DmsRetentionClass` | Retention Class | Choice | Yes | Yes | Records Management | Internal | RecordsManager | Triaged, Authoring, Rework | F-018, DATA-007 |
| `DmsTrainingRequired` | Acknowledgement Required | Boolean | No |  | Process Owner | Internal | DocumentController | Triaged, Authoring, Rework | F-029, DATA-008 |
| `DmsSupersedes` | Supersedes | Text | No |  | Document Control | Internal | SystemAutomation | _none — system only_ | F-014 |
| `DmsSupersededBy` | Superseded By | Text | No |  | Document Control | Internal | SystemAutomation | _none — system only_ | F-014, UX-004 |
| `DmsChangeSummary` | Change Summary | Note | Yes |  | Author | Internal | Author | Authoring, Rework | F-008, UX-006 |
| `DmsApprovalCorrelationId` | Approval Correlation ID | Text | No | Yes | Platform | Internal | SystemAutomation | _none — system only_ | F-010, F-022, NFR-006 |
| `DmsCurrentEffective` | Current Effective | Boolean | No | Yes | Document Control | Internal | SystemAutomation | _none — system only_ | F-013, F-026, NFR-004 |
| `DmsSubmittedVersion` | Submitted Version | Text | No |  | Platform | Internal | SystemAutomation | _none — system only_ | F-008, NFR-011 |
| `DmsSubmittedETag` | Submitted ETag | Text | No |  | Platform | Internal | SystemAutomation | _none — system only_ | F-008, NFR-011 |
| `DmsApprovedETag` | Approved ETag | Text | No |  | Platform | Internal | SystemAutomation | _none — system only_ | F-012, NFR-011 |
| `DmsRecordClass` | Record Class | Choice | No | Yes | Records Management | Internal | RecordsManager | * | F-018, DATA-006 |
| `DmsEventDate` | Event Date | DateTime | No | Yes | Business Process Owner | Internal | BusinessUser | * | F-018, DATA-006 |
| `DmsRelatedDocumentId` | Related Controlled Document | Text | No | Yes | Business Process Owner | Internal | BusinessUser | * | F-003, DATA-006 |
| `DmsSourceProvenance` | Source Provenance | Note | No |  | Migration Lead | Internal | SystemAutomation | _none — system only_ | F-037, DATA-012 |
| `DmsMigrationBatchId` | Migration Batch ID | Text | No | Yes | Migration Lead | Internal | SystemAutomation | _none — system only_ | F-037, DATA-012 |

## Validation rules

| Internal name | Rule |
|---|---|
| `DmsDocumentId` | Matches the approved namespace pattern and is unique among non-Obsolete revisions of different documents. |
| `DmsDocumentType` | Must match the content type in use. Provisioning validates that the value set is consistent with config/content-types.json. |
| `DmsBusinessFunction` | Must be an active term. Deprecated terms remain resolvable for history. PRD section 17.3. |
| `DmsBusinessProcess` | Must be an active term within the selected Business Function branch where the taxonomy defines that relationship. |
| `DmsDocumentOwner` | Must resolve to an active Entra identity. Departure raises an ownerless-document exception. PRD MET-005. |
| `DmsAuthor` | Active Entra identities or approved groups. |
| `DmsReviewer` | Resolved from routing rules at submission; a manual override is audited. |
| `DmsApprover` | Must not equal the sole Author for the same revision. Separation of duties, PRD SEC-003. |
| `DmsLifecycleStatus` | Only values declared in config/lifecycle-states.json. Direct user edits are blocked by permission design; changes flow through the transition engine. PRD F-005. |
| `DmsBusinessRevision` | Business revision is distinct from the SharePoint version. Convention pending OQ-11. |
| `DmsSharePointVersionRef` | The platform version label of the activated major version, e.g. 3.0. Recorded for evidence reconciliation. |
| `DmsEffectiveDate` | Required before final approval. Stored in UTC; displayed in the tenant default time zone. PRD section 17.3. |
| `DmsNextReviewDate` | Calculated from DmsReviewFrequencyMonths and the effective date. May only move forward when an attributable review decision exists. PRD F-015. |
| `DmsReviewFrequencyMonths` | Must match an active entry in the Review Frequencies list. |
| `DmsSensitivityClassification` | Business classification value. It does not itself apply a Purview sensitivity label; label mapping is defined in docs/PURVIEW_DESIGN.md. PRD SEC-006. |
| `DmsApplicability` | Defines the context within which exactly one revision may be effective. PRD F-013. |
| `DmsSiteRegion` | Optional in MVP. Multi-region retention variation is out of MVP scope. PRD OQ-16. |
| `DmsRetentionClass` | Must reference an approved retention class. Provisional classes block production record capture. PRD F-018, R-03. |
| `DmsTrainingRequired` | Acknowledgement is read-and-understand evidence only. It is not competence certification. PRD F-029. |
| `DmsSupersedes` | Document ID and business revision of the revision this one replaces. |
| `DmsSupersededBy` | Required when Lifecycle Status is Superseded. Withdrawal without a replacement leaves this empty. PRD section 17.3. |
| `DmsChangeSummary` | Required at submission. Shown to reviewers and approvers on the task. PRD UX-006. |
| `DmsApprovalCorrelationId` | GUID generated at submission. Joins the document, its approval evidence and any exception. PRD F-010, F-022. |
| `DmsCurrentEffective` | Exactly one item may be true per Document ID and applicability context. Reconciliation reports zero or multiple. PRD F-013. |
| `DmsSubmittedVersion` | Platform version label captured at submission. PRD F-008. |
| `DmsSubmittedETag` | ETag captured at submission and re-checked before approval and again before activation. A mismatch invalidates the approval. PRD F-008, NFR-011, R-05. |
| `DmsApprovedETag` | ETag at the moment of final approval. Revalidated by the activation flow before publishing. PRD F-012. |
| `DmsRecordClass` | Required on Operational Record. Must map to an approved retention class before production capture. PRD F-018. |
| `DmsEventDate` | The retention trigger date for event-based retention. Must not precede the logical event unless approved as migrated historical data. PRD section 17.3. |
| `DmsRelatedDocumentId` | Links a completed record to the controlled form or SOP that produced it. PRD F-003. |
| `DmsSourceProvenance` | Set only by migration. Records source path, source identifier, source timestamps and hash where chain of custody requires it. PRD DATA-012, C-009. |
| `DmsMigrationBatchId` | Joins a migrated item to its migration evidence record for reconciliation. |

## Content types

| Name | Content type ID | Parent | Abstract | Required fields |
|---|---|---|:--:|---|
| Controlled Document | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | `0x0101` | Yes | DmsDocumentId, DmsDocumentType, DmsBusinessFunction, DmsBusinessProcess, DmsDocumentOwner, DmsLifecycleStatus, DmsBusinessRevision, DmsReviewFrequencyMonths, DmsSensitivityClassification, DmsApplicability, DmsRetentionClass, DmsChangeSummary |
| Policy | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D01` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| SOP | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D02` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| Work Instruction | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D03` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| Standard | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D04` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| Controlled Form or Template | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D05` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| Business Operations Document | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D06` | `0x010100A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4D` | No |  |
| Operational Record | `0x010100B4E9D2C6F1A84B379E5C0D8A6F2B1E37` | `0x0101` | No | DmsRecordClass, DmsEventDate, DmsBusinessProcess, DmsSensitivityClassification |
| External Document | `0x010100C8D5F0A29E634C1BA7F2D3E6B0C4A519` | `0x0101` | No | DmsDocumentId, DmsBusinessFunction, DmsDocumentOwner, DmsSensitivityClassification |
| Controlled Case File | `0x0120D52000A7F3C81B9B4D4E2A8C5F6D0E1B2A3C4E` | `0x0120D520` | No |  |

## Registers (lists)

### Document Register

Master index of every controlled document and its current lifecycle summary. PRD DATA-005.

MVP treatment: Required. PRD: DATA-005, F-013, F-027, MET-001.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Document Title | Text | Yes |
| `DmsDocumentId` |  | _site column_ | Yes |
| `DmsDocumentType` |  | _site column_ | Yes |
| `DmsBusinessFunction` |  | _site column_ |  |
| `DmsBusinessProcess` |  | _site column_ |  |
| `DmsDocumentOwner` |  | _site column_ | Yes |
| `DmsLifecycleStatus` |  | _site column_ | Yes |
| `DmsBusinessRevision` |  | _site column_ |  |
| `DmsEffectiveDate` |  | _site column_ |  |
| `DmsNextReviewDate` |  | _site column_ |  |
| `DmsCurrentEffective` |  | _site column_ |  |
| `DmsRetentionClass` |  | _site column_ |  |
| `DmsApplicability` |  | _site column_ |  |
| `DmsCurrentItemUrl` | Current Revision Link | URL |  |
| `DmsHistoryViewUrl` | History Link | URL |  |
| `DmsControlCompleteness` | Control Completeness | Choice |  |
| `DmsCompletenessFailures` | Completeness Failures | Note |  |

### Change Requests

New-document, revision, withdrawal and emergency-change requests. PRD DATA-003, WF-01.

MVP treatment: Required. PRD: F-007, DATA-003, WF-01.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Request Title | Text | Yes |
| `DmsRequestId` | Request ID | Text | Yes |
| `DmsRequestType` | Request Type | Choice | Yes |
| `DmsJustification` | Justification | Note | Yes |
| `DmsUrgency` | Urgency | Choice | Yes |
| `DmsAffectedProcess` | Affected Process | TaxonomyFieldType | Yes |
| `DmsRequestedDocumentId` | Existing Document ID | Text |  |
| `DmsProposedOwner` | Proposed Owner | User | Yes |
| `DmsImpactedAudience` | Impacted Audience | Note | Yes |
| `DmsRequestedEffectiveDate` | Requested Effective Date | DateTime |  |
| `DmsRequestStatus` | Request Status | Choice | Yes |
| `DmsTriageDecisionBy` | Triage Decision By | User |  |
| `DmsTriageDecisionDate` | Triage Decision Date | DateTime |  |
| `DmsTriageRationale` | Triage Rationale | Note |  |
| `DmsDuplicateOfRequestId` | Duplicate Of | Text |  |
| `DmsApprovalCorrelationId` |  | _site column_ |  |

### Approval Evidence

Durable, attributable record of every review and approval decision. Deliberately independent of Power Automate run history, which expires. PRD F-010, C-007, R-12.

MVP treatment: Required. PRD: F-010, F-021, NFR-012, DATA-004, SEC-010.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Evidence Title | Text | Yes |
| `DmsApprovalCorrelationId` |  | _site column_ | Yes |
| `DmsDocumentId` |  | _site column_ | Yes |
| `DmsBusinessRevision` |  | _site column_ | Yes |
| `DmsEvidenceFileVersion` | File Version | Text | Yes |
| `DmsEvidenceETag` | File ETag | Text | Yes |
| `DmsDecisionStage` | Stage | Text | Yes |
| `DmsDecisionSequence` | Stage Sequence | Number |  |
| `DmsDecisionActor` | Decision By | User | Yes |
| `DmsDecisionActorRole` | Role | Choice | Yes |
| `DmsDecisionOutcome` | Outcome | Choice | Yes |
| `DmsDecisionTimestampUtc` | Decision Timestamp (UTC) | DateTime | Yes |
| `DmsDecisionComments` | Comments | Note |  |
| `DmsDelegatedFrom` | Delegated From | User |  |
| `DmsTaskReference` | Task Reference | Text |  |
| `DmsEvidenceRetentionClass` | Evidence Retention Class | Text |  |

### Exception Register

Failed flows, stale check-outs, integrity failures, permission and retention exceptions. PRD F-022, DATA-009, WF-06.

MVP treatment: Required. PRD: F-022, F-023, DATA-009, NFR-014, MET-007.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Exception Summary | Text | Yes |
| `DmsApprovalCorrelationId` |  | _site column_ |  |
| `DmsExceptionType` | Exception Type | Choice | Yes |
| `DmsSeverity` | Severity | Choice | Yes |
| `DmsIsBlocking` | Blocks Publication | Boolean | Yes |
| `DmsAffectedItemUrl` | Affected Item | URL |  |
| `DmsDocumentId` |  | _site column_ |  |
| `DmsErrorDetail` | Error Detail | Note | Yes |
| `DmsExceptionOwner` | Owner | User | Yes |
| `DmsRetryCount` | Retry Count | Number |  |
| `DmsExceptionStatus` | Status | Choice | Yes |
| `DmsDetectedUtc` | Detected (UTC) | DateTime | Yes |
| `DmsResolvedUtc` | Resolved (UTC) | DateTime |  |
| `DmsResolutionReason` | Resolution Reason | Note |  |
| `DmsIncidentReference` | Incident/Ticket Reference | Text |  |

### Routing Rules

Configurable review and approval routes resolved at submission. Changing a route must not require editing flow logic. PRD F-028.

MVP treatment: Required. PRD: F-009, F-028, OQ-13.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Rule Name | Text | Yes |
| `DmsRuleDocumentType` | Document Type | Text | Yes |
| `DmsRuleBusinessFunction` | Business Function | Text |  |
| `DmsRuleSensitivity` | Sensitivity | Text |  |
| `DmsRuleSpecificity` | Specificity | Number | Yes |
| `DmsRuleStageName` | Stage Name | Text | Yes |
| `DmsRuleStageSequence` | Stage Sequence | Number | Yes |
| `DmsRuleStageMode` | Stage Mode | Choice | Yes |
| `DmsRuleApprovers` | Assignees | UserMulti | Yes |
| `DmsRuleQuorum` | Quorum | Choice | Yes |
| `DmsRuleDueBusinessDays` | Due (business days) | Number | Yes |
| `DmsRuleEscalateTo` | Escalate To | User |  |
| `DmsRuleActive` | Active | Boolean | Yes |

### Review Frequencies

Approved periodic-review intervals and reminder schedules. PRD F-015.

MVP treatment: Required. PRD: F-015, F-028.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Frequency Name | Text | Yes |
| `DmsFrequencyMonths` | Months | Number | Yes |
| `DmsReminderOffsetsDays` | Reminder Offsets (days before due) | Text | Yes |
| `DmsEscalationAfterDaysOverdue` | Escalate After (days overdue) | Number | Yes |
| `DmsAppliesToDocumentType` | Applies To Document Type | Text |  |
| `DmsFrequencyActive` | Active | Boolean |  |

### Workflow Configuration

Operational thresholds and switches read by the flows at runtime, so ordinary rule changes never require editing flow logic. PRD F-028, ADM-005.

MVP treatment: Required. PRD: F-028, ADM-005, NFR-014.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Setting Key | Text | Yes |
| `DmsSettingValue` | Value | Text | Yes |
| `DmsSettingType` | Value Type | Choice | Yes |
| `DmsSettingDescription` | Description | Note | Yes |
| `DmsSettingLastChangedBy` | Last Changed By | User |  |
| `DmsSettingActive` | Active | Boolean |  |

### Acknowledgements

Read-and-understand assignments and responses. Acknowledgement is NOT competence certification. PRD F-029, DATA-008.

MVP treatment: P1. Provisioned only when the pilot requires it.. PRD: F-029, DATA-008, MET-012, NFR-016.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Assignment | Text | Yes |
| `DmsDocumentId` |  | _site column_ | Yes |
| `DmsBusinessRevision` |  | _site column_ | Yes |
| `DmsAckAssignedTo` | Assigned To | User | Yes |
| `DmsAckAssignedUtc` | Assigned (UTC) | DateTime | Yes |
| `DmsAckDueDate` | Due Date | DateTime | Yes |
| `DmsAckRespondedUtc` | Responded (UTC) | DateTime |  |
| `DmsAckStatus` | Status | Choice | Yes |
| `DmsAckRemindersSent` | Reminders Sent | Number |  |

### Migration Evidence

Provenance and reconciliation evidence for migrated content. PRD DATA-012, F-037.

MVP treatment: P1. Required before any pilot migration.. PRD: F-037, DATA-012, INT-010.

| Field | Display name | Type | Required |
|---|---|---|:--:|
| `Title` | Source Item | Text | Yes |
| `DmsMigrationBatchId` |  | _site column_ | Yes |
| `DmsSourcePath` | Source Path | Note | Yes |
| `DmsSourceIdentifier` | Source Identifier | Text |  |
| `DmsSourceSizeBytes` | Source Size (bytes) | Number |  |
| `DmsSourceModifiedUtc` | Source Modified (UTC) | DateTime |  |
| `DmsSourceHash` | Source Hash (SHA-256) | Text |  |
| `DmsTargetItemUrl` | Target Item | URL |  |
| `DmsTargetHash` | Target Hash (SHA-256) | Text |  |
| `DmsMigrationResult` | Result | Choice | Yes |
| `DmsMigrationNotes` | Notes | Note |  |

