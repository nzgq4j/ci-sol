# Requirements Traceability Matrix

> **Generated file.** Produced by `src/reporting/New-DmsTraceability.ps1`, which extracts every requirement ID directly from `SharePoint_DMS_PRD.md` and locates each one across configuration, code, flow specifications, tests and documentation. Do not edit by hand.

Generated 2026-08-25. Requirement IDs found in the PRD: **167**.

## Coverage status meanings

| Status | Meaning |
|---|---|
| Implemented and tested | Realised in configuration or code, and covered by an executing test. |
| Implemented, tenant validation pending | Realised in configuration or code. Cannot be proven against a tenant until a connection and the outstanding decisions exist. |
| Specified | Designed in a flow specification or design document; build depends on tenant access. |
| Not referenced | No reference in the repository. For a P0 requirement this is a gap. |

## Functional requirements (F)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **F-001** | P0 | The system shall provide centrally governed content types and site columns for Controlled Document, Operational Record, External Document, and supp... | Implemented, tenant validation pending | `config/content-types.json`<br>`config/libraries.json`<br>`config/site-columns.json`<br>`config/views.json` |
| **F-002** | P0 | The system shall assign or validate a unique, persistent Document ID and prevent duplicate active IDs. | Implemented and tested | `config/lifecycle-states.json`<br>`config/site-columns.json`<br>`src/migration/Compare-DmsMigration.ps1`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1` |
| **F-003** | P0 | The system shall create controlled documents from approved, content-type-specific templates and distinguish blank controlled forms from completed o... | Implemented, tenant validation pending | `config/content-types.json`<br>`config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/site-columns.json` |
| **F-004** | P0 | The system shall configure major/minor versioning, draft visibility, content approval, and check-out by library according to the approved operating... | Implemented, tenant validation pending | `config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/security-roles.json`<br>`src/provisioning/Invoke-DmsDiscovery.ps1` |
| **F-005** | P0 | The system shall maintain a business Lifecycle Status separately from native SharePoint Approval Status and restrict direct user changes to control... | Implemented and tested | `config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/security-roles.json`<br>`config/site-columns.json` |
| **F-006** | P0 | The system shall support check-out, check-in comments, discard, and authorised override for libraries using exclusive editing. | Implemented, tenant validation pending | `config/lifecycle-states.json` |
| **F-007** | P0 | The system shall capture new-document, revision, withdrawal, and emergency-change requests with required justification, owner, process, impact, and... | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/security-roles.json`<br>`src/power-platform/flow-specifications/Flow1-Request-Triage.md` |
| **F-008** | P0 | The system shall validate mandatory metadata and capture the submitted file version and ETag before initiating review. | Implemented and tested | `config/lifecycle-states.json`<br>`config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md` |
| **F-009** | P0 | The system shall route version-specific serial or parallel review and approval tasks according to configurable document type, process, risk, and au... | Implemented and tested | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/routing-rules.json`<br>`config/security-roles.json` |
| **F-010** | P0 | The system shall retain each review and approval decision as durable, attributable evidence. | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/lifecycle-states.json`<br>`config/lists.json` |
| **F-011** | P0 | The system shall return rejected content to Authoring with mandatory rationale and retain the rejected decision without publishing the revision. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md`<br>`src/power-platform/flow-specifications/README.md` |
| **F-012** | P0 | The system shall support an Approved Pending Effective state and activate only the approved revision at or after the authorised effective date. | Implemented and tested | `config/lifecycle-states.json`<br>`config/security-roles.json`<br>`config/site-columns.json`<br>`src/provisioning/Deploy-DmsPowerPlatform.ps1` |
| **F-013** | P0 | The system shall ensure that each controlled document has no more than one current effective revision within an applicability context. | Implemented and tested | `config/environments.example.json`<br>`config/environments.json`<br>`config/libraries.json`<br>`config/lifecycle-states.json` |
| **F-014** | P0 | The system shall record the supersedes/superseded-by relationship and prevent superseded or withdrawn content from appearing in default current-doc... | Implemented, tenant validation pending | `config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/metrics.json`<br>`config/security-roles.json` |
| **F-015** | P0 | The system shall calculate review dates from approved review-frequency rules, notify owners before due date, and escalate overdue items. | Implemented and tested | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/metrics.json`<br>`config/site-columns.json` |
| **F-016** | P0 | The system shall support continue-valid, revise, withdraw, and emergency-suspend review outcomes. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`src/power-platform/flow-specifications/Flow4-Periodic-Review.md`<br>`src/power-platform/flow-specifications/README.md`<br>`docs/POWER_AUTOMATE_DESIGN.md` |
| **F-017** | P0 | The system shall distribute publication and assignment notifications as links to authoritative content rather than file attachments. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`src/modules/DmsProvisioning/Public/PnPUsage.ps1`<br>`src/power-platform/flow-specifications/Flow3-Scheduled-Activation.md`<br>`src/power-platform/flow-specifications/README.md` |
| **F-018** | P0 | The system shall map every MVP controlled-document and operational-record class to an approved retention policy or label before production use. | Implemented and tested | `config/content-types.json`<br>`config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/metrics.json` |
| **F-019** | P0 | The system shall restrict record locking, unlocking, label removal, and regulatory-record use to authorised roles and approved procedures. | Implemented, tenant validation pending | `config/libraries.json`<br>`config/metrics.json`<br>`config/security-roles.json`<br>`src/provisioning/Deploy-DmsPurview.ps1` |
| **F-020** | P0 | The system shall support disposition through the approved automatic or reviewer-authorised path and preserve required evidence. | Implemented, tenant validation pending | `config/libraries.json`<br>`config/lifecycle-states.json`<br>`config/metrics.json`<br>`config/retention-map.example.json` |
| **F-021** | P0 | The system shall capture and expose auditable lifecycle events, including request, check-out/in, submit, review, approve/reject, activate, supersed... | Implemented, tenant validation pending | `config/lists.json`<br>`docs/DATA_DICTIONARY.md`<br>`docs/OPEN_DECISIONS.md`<br>`docs/PURVIEW_DESIGN.md` |
| **F-022** | P0 | The system shall create a governed Exception Register and prevent unsafe automatic publication when state or version integrity is uncertain. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/metrics.json`<br>`config/routing-rules.json` |
| **F-023** | P0 | The system shall detect checked-out documents beyond a configurable threshold and notify, escalate, or permit controlled override. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/metrics.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **F-024** | P0 | The system shall enforce role-based access through approved Microsoft Entra groups and maintain separation between content approval, records dispos... | Implemented and tested | `config/environments.json`<br>`config/lifecycle-states.json`<br>`config/metrics.json`<br>`config/security-roles.json` |
| **F-025** | P0 | The system shall disable external sharing on MVP controlled sites unless Security, Privacy, Legal, and the information owner approve a defined exce... | Implemented and tested | `config/environments.schema.json`<br>`config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **F-026** | P0 | The system shall provide current-document browsing, exact-ID search, keyword search, metadata filtering, and an authorised history view. | Implemented, tenant validation pending | `config/libraries.json`<br>`config/site-columns.json`<br>`config/views.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1` |
| **F-027** | P0 | The system shall provide role-appropriate dashboards and exportable operational reports. | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`config/views.json`<br>`src/reporting/Export-DmsMetrics.ps1` |
| **F-028** | P1 | The system shall maintain configurable routing, review-frequency, document-type, and escalation rules without editing flow logic for ordinary rule ... | Implemented, tenant validation pending | `config/lists.json`<br>`config/routing-rules.json`<br>`src/modules/DmsProvisioning/Public/Review.ps1`<br>`src/modules/DmsProvisioning/Public/Routing.ps1` |
| **F-029** | P1 | The system shall capture acknowledgement assignments and responses for documents requiring read-and-understand evidence. | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`config/site-columns.json`<br>`docs/DATA_DICTIONARY.md` |
| **F-030** | P1 | The system shall support Document Sets for approved case-file or multi-document work products. | Implemented, tenant validation pending | `config/content-types.json` |
| **F-031** | P1 | The system shall generate a controlled PDF rendition when an approved process requires a fixed-format copy. | Specified | `docs/OPEN_DECISIONS.md` |
| **F-032** | P1 | The system shall surface tasks and notifications in Teams where approved without making Teams the authoritative repository. | Not referenced | — |
| **F-033** | P1 | The system shall provide a Power App intake and Document Control work queue if native list forms do not meet validated usability needs. | Specified | `docs/ARCHITECTURE_DECISIONS.md` |
| **F-034** | P2 | The system may use document processing to classify content or extract metadata after accuracy and cost thresholds are approved. | Not referenced | — |
| **F-035** | P2 | The system may generate routine documents from controlled templates and approved business data. | Not referenced | — |
| **F-036** | P2 | The system may integrate an approved electronic-signature service where legal analysis defines signature identity, intent, consent, integrity, and ... | Specified | `docs/OPEN_DECISIONS.md` |
| **F-037** | P3 | The system shall not implement enterprise-wide migration until the pilot migration and reconciliation are accepted. | Implemented and tested | `config/lists.json`<br>`config/site-columns.json`<br>`src/migration/ACCEPTANCE_REPORT_TEMPLATE.md`<br>`src/migration/Compare-DmsMigration.ps1` |

## Non-functional requirements (NFR)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **NFR-001** |  | Performance | Not referenced | — |
| **NFR-002** |  | Workflow responsiveness | Not referenced | — |
| **NFR-003** |  | Availability | Specified | `docs/OPEN_DECISIONS.md`<br>`docs/OPERATIONS_RUNBOOK.md` |
| **NFR-004** |  | Scalability | Implemented, tenant validation pending | `config/libraries.json`<br>`config/site-columns.json`<br>`config/views.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1` |
| **NFR-005** |  | Reliability | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/POWER_AUTOMATE_DESIGN.md` |
| **NFR-006** |  | Resilience | Implemented and tested | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/New-DmsPlan.ps1` |
| **NFR-007** |  | Security | Not referenced | — |
| **NFR-008** |  | Usability | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/ARCHITECTURE_DECISIONS.md` |
| **NFR-009** |  | Accessibility | Implemented, tenant validation pending | `src/list-formatting/current-documents-view.json`<br>`src/list-formatting/README.md`<br>`docs/TEST_STRATEGY.md` |
| **NFR-010** |  | Maintainability | Implemented, tenant validation pending | `src/power-platform/flow-specifications/README.md`<br>`src/provisioning/Deploy-DmsPowerPlatform.ps1`<br>`docs/POWER_AUTOMATE_DESIGN.md` |
| **NFR-011** |  | Data integrity | Implemented and tested | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1` |
| **NFR-012** |  | Auditability | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/lists.json`<br>`config/retention-map.example.json` |
| **NFR-013** |  | Backup and recovery | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/OPEN_DECISIONS.md` |
| **NFR-014** |  | Observability | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`config/views.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **NFR-015** |  | Interoperability | Implemented, tenant validation pending | `config/lists.json`<br>`src/modules/DmsProvisioning/Public/Safety.ps1`<br>`src/power-platform/flow-specifications/README.md`<br>`docs/POWER_AUTOMATE_DESIGN.md` |
| **NFR-016** |  | Privacy | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`config/retention-map.example.json`<br>`docs/DATA_DICTIONARY.md` |
| **NFR-017** |  | Search freshness | Implemented, tenant validation pending | `config/lists.json`<br>`src/power-platform/flow-specifications/Flow3-Scheduled-Activation.md`<br>`docs/ARCHITECTURE.md`<br>`docs/OPEN_DECISIONS.md` |
| **NFR-018** |  | Portability | Implemented, tenant validation pending | `src/provisioning/Export-DmsConfiguration.ps1`<br>`src/reporting/Export-DmsMetrics.ps1`<br>`src/reporting/README.md` |
| **NFR-019** |  | Configuration management | Implemented and tested | `config/environments.schema.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1`<br>`src/modules/DmsProvisioning/Public/Safety.ps1`<br>`src/provisioning/Export-DmsConfiguration.ps1` |
| **NFR-020** |  | Compatibility | Not referenced | — |

## Security and compliance (SEC)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **SEC-001** |  | Authentication shall use Microsoft Entra ID; tenant-approved MFA and Conditional Access shall apply according to user, device, location, and sensit... | Specified | `docs/SECURITY_MODEL.md` |
| **SEC-002** |  | Authorisation shall use an approved role-permission matrix and Entra groups; direct user permissions and item-level unique permissions shall be exc... | Implemented and tested | `config/libraries.json`<br>`config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1`<br>`src/modules/DmsProvisioning/Public/PnPUsage.ps1` |
| **SEC-003** |  | Least privilege and separation of duties shall distinguish Reader, Author, Reviewer, Approver, Document Controller, Records Manager, and Platform A... | Implemented and tested | `config/routing-rules.json`<br>`config/security-roles.json`<br>`config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/Routing.ps1` |
| **SEC-004** |  | Production automation shall use approved connection ownership, least privilege, and at least two administrative co-owners; credentials shall not be... | Implemented and tested | `config/lists.json`<br>`config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/CoreHelpers.ps1`<br>`src/modules/DmsProvisioning/Public/PnPUsage.ps1` |
| **SEC-005** |  | External sharing shall be disabled for MVP controlled sites unless an approved exception defines sponsor, group, content, duration, and review. | Implemented, tenant validation pending | `config/environments.schema.json`<br>`config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1`<br>`src/provisioning/Deploy-DmsSecurity.ps1` |
| **SEC-006** |  | Sensitivity labels and DLP shall be applied where the information-classification assessment requires them; encrypted-file behaviour in SharePoint a... | Implemented, tenant validation pending | `config/site-columns.json`<br>`docs/DATA_DICTIONARY.md`<br>`docs/OPEN_DECISIONS.md`<br>`docs/PURVIEW_DESIGN.md` |
| **SEC-007** |  | Data shall use Microsoft 365 platform encryption in transit and at rest; any custom integration shall use supported TLS and approved secret storage. | Not referenced | — |
| **SEC-008** |  | A data inventory shall identify personal, financial, commercially sensitive, legally privileged, export-controlled, classified, or other regulated ... | Implemented, tenant validation pending | `config/site-columns.json`<br>`docs/DATA_DICTIONARY.md` |
| **SEC-009** |  | Where UK GDPR or another privacy law applies, metadata and workflow fields shall be purpose-limited and minimised, and retention shall reflect appr... | Implemented, tenant validation pending | `config/lists.json`<br>`config/retention-map.example.json` |
| **SEC-010** |  | Access, approval, administrative, label, sharing, and disposition events shall be logged for the approved period; evidence shall not rely exclusive... | Implemented, tenant validation pending | `config/lists.json`<br>`docs/DATA_DICTIONARY.md`<br>`docs/PURVIEW_DESIGN.md` |
| **SEC-011** |  | Privileged administrative actions shall use named accounts, approved roles, and periodic review; emergency access shall be logged and reviewed. | Implemented, tenant validation pending | `config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/Safety.ps1`<br>`docs/ARCHITECTURE.md` |
| **SEC-012** |  | Record-lock, unlock, regulatory-record, Preservation Lock, and disposition configuration shall require Records Management and Legal approval becaus... | Implemented and tested | `config/environments.schema.json`<br>`config/retention-map.example.json`<br>`config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1` |
| **SEC-013** |  | Security incidents involving the DMS shall follow the organisational incident-response process and preserve relevant evidence. | Not referenced | — |
| **SEC-014** |  | Custom components and scripts shall undergo peer review, dependency/vulnerability scanning where applicable, and secure release control. | Not referenced | — |
| **SEC-015** |  | Backup and restore access shall be restricted, logged, and tested without bypassing retention, privacy, or legal-hold obligations. | Specified | `docs/BACKUP_RECOVERY_PLAN.md`<br>`docs/SECURITY_MODEL.md` |

## Data requirements (DATA)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **DATA-001** |  | Controlled Document | Implemented, tenant validation pending | `config/content-types.json`<br>`config/site-columns.json`<br>`docs/ARCHITECTURE.md`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-002** |  | Document Revision | Implemented, tenant validation pending | `config/site-columns.json`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-003** |  | Change Request | Implemented, tenant validation pending | `config/lists.json`<br>`config/retention-map.example.json`<br>`src/power-platform/flow-specifications/Flow1-Request-Triage.md`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-004** |  | Approval Decision | Implemented, tenant validation pending | `config/lists.json`<br>`config/site-columns.json`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-005** |  | Document Register | Implemented, tenant validation pending | `config/lists.json`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-006** |  | Operational Record | Implemented, tenant validation pending | `config/content-types.json`<br>`config/libraries.json`<br>`config/site-columns.json`<br>`config/views.json` |
| **DATA-007** |  | Retention Class | Implemented, tenant validation pending | `config/site-columns.json`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-008** |  | Acknowledgement | Implemented, tenant validation pending | `config/lists.json`<br>`config/site-columns.json`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-009** |  | Exception | Implemented, tenant validation pending | `config/lists.json`<br>`docs/DATA_DICTIONARY.md` |
| **DATA-010** |  | Identity and Role Mapping | Not referenced | — |
| **DATA-011** |  | Disposition Decision | Implemented, tenant validation pending | `config/retention-map.example.json` |
| **DATA-012** |  | Migration Evidence | Implemented and tested | `config/lists.json`<br>`config/site-columns.json`<br>`src/migration/Get-DmsSourceInventory.ps1`<br>`tests/pester/DmsProvisioning.Tests.ps1` |

## Integrations (INT)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **INT-001** |  | Microsoft Entra ID | Implemented, tenant validation pending | `src/modules/DmsProvisioning/Public/PnPUsage.ps1` |
| **INT-002** |  | SharePoint Online | Not referenced | — |
| **INT-003** |  | Microsoft 365 Apps | Not referenced | — |
| **INT-004** |  | Power Automate / Approvals | Not referenced | — |
| **INT-005** |  | Exchange Online / Teams | Implemented, tenant validation pending | `src/modules/DmsProvisioning/Public/PnPUsage.ps1` |
| **INT-006** |  | Microsoft Purview | Not referenced | — |
| **INT-007** |  | Power Apps / Microsoft Lists | Not referenced | — |
| **INT-008** |  | Power BI | Specified | `docs/ENVIRONMENT_DISCOVERY.md` |
| **INT-009** |  | Backup service | Not referenced | — |
| **INT-010** |  | Source repositories/migration tooling | Implemented, tenant validation pending | `config/lists.json`<br>`src/migration/Compare-DmsMigration.ps1`<br>`docs/DATA_DICTIONARY.md`<br>`docs/MIGRATION_PLAN.md` |
| **INT-011** |  | Azure Automation/Functions or line-of-business APIs | Not referenced | — |

## Administration (ADM)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **ADM-001** |  | Product governance shall name the Executive Sponsor, Product Owner, Document Control authority, Records Manager, Security owner, Privacy owner, pla... | Specified | `docs/SUPPORT_MODEL.md` |
| **ADM-002** |  | The product shall maintain an approved service catalogue entry, support route, severity model, maintenance window, and escalation path. | Specified | `docs/OPEN_DECISIONS.md`<br>`docs/SUPPORT_MODEL.md` |
| **ADM-003** |  | Site, library, content-type, taxonomy, retention, security, and workflow changes shall use controlled change management. | Implemented, tenant validation pending | `src/modules/DmsProvisioning/Public/Safety.ps1` |
| **ADM-004** |  | Power Apps and Power Automate components shall be developed in Dev, validated in Test/UAT, and deployed to Production as managed solution artefacts. | Implemented, tenant validation pending | `src/provisioning/Deploy-DmsPowerPlatform.ps1`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/POWER_AUTOMATE_DESIGN.md` |
| **ADM-005** |  | Site URLs, list/library identifiers, group IDs, thresholds, and routing values shall use environment variables or governed configuration rather tha... | Implemented, tenant validation pending | `config/environments.schema.json`<br>`config/lists.json`<br>`src/modules/DmsProvisioning/Public/CoreHelpers.ps1`<br>`src/power-platform/deployment-settings/deployment-settings.dev.json` |
| **ADM-006** |  | SharePoint provisioning and validation shall use approved site scripts, SharePoint Online PowerShell, PnP PowerShell, Microsoft Graph, or equivalen... | Implemented, tenant validation pending | `config/security-roles.json`<br>`src/modules/DmsProvisioning/Public/PnPUsage.ps1`<br>`docs/ARCHITECTURE_DECISIONS.md` |
| **ADM-007** |  | PnP PowerShell or other community tooling shall be treated as a managed dependency with version pinning, test coverage, and support ownership rathe... | Implemented, tenant validation pending | `src/modules/DmsProvisioning/Public/PnPUsage.ps1`<br>`src/modules/DmsProvisioning/DmsProvisioning.psd1`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/OPERATIONS_RUNBOOK.md` |
| **ADM-008** |  | Production flows shall have approved connection ownership, at least two administrative co-owners, documented reauthentication, and an offboarding r... | Implemented, tenant validation pending | `config/security-roles.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md`<br>`src/power-platform/flow-specifications/README.md`<br>`src/provisioning/Deploy-DmsPowerPlatform.ps1` |
| **ADM-009** |  | Configuration, application, and procedure documentation shall be versioned and linked to the applicable release. | Implemented, tenant validation pending | `src/reporting/New-DmsDocumentation.ps1` |
| **ADM-010** |  | Backup, restore, and business-continuity procedures shall be approved and exercised at the frequency set by the Product Owner and continuity author... | Implemented, tenant validation pending | `config/metrics.json` |
| **ADM-011** |  | Monthly service review shall cover metrics, incidents, exceptions, permissions, owner status, licence/capacity, Microsoft roadmap changes, and impr... | Specified | `docs/OPERATIONS_RUNBOOK.md`<br>`docs/SUPPORT_MODEL.md` |
| **ADM-012** |  | At least annually, or after material regulatory/process change, the file plan, classification, access model, and operating procedures shall be revi... | Specified | `docs/OPERATIONS_RUNBOOK.md` |

## User experience (UX)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **UX-001** |  | The DMS home shall prioritise Find a Current Document, My Tasks, Request a Document/Change, Documents Due for Review, and Help according to role. | Implemented, tenant validation pending | `config/views.json`<br>`src/site-scripts/README.md` |
| **UX-002** |  | The default reader experience shall not require knowledge of site, library, folder, or filename structure. | Implemented, tenant validation pending | `config/views.json`<br>`src/site-scripts/README.md` |
| **UX-003** |  | Search and list results shall show Document ID, title, revision, lifecycle status, effective date, owner, document type, and applicability. | Implemented, tenant validation pending | `config/site-columns.json`<br>`config/views.json`<br>`src/list-formatting/current-documents-view.json`<br>`src/list-formatting/README.md` |
| **UX-004** |  | Obsolete, superseded, or withdrawn direct links shall display a prominent status and link to the current replacement where one exists. | Implemented, tenant validation pending | `config/site-columns.json`<br>`src/list-formatting/current-documents-view.json`<br>`src/list-formatting/README.md`<br>`docs/DATA_DICTIONARY.md` |
| **UX-005** |  | Author forms shall group fields by business meaning, explain required fields, preserve entered data after validation errors, and avoid asking users... | Specified | `docs/ARCHITECTURE_DECISIONS.md` |
| **UX-006** |  | Review and approval tasks shall show the exact version, change summary, prior revision link, due date, stage, and consequences of approval or rejec... | Implemented, tenant validation pending | `config/site-columns.json`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md`<br>`docs/DATA_DICTIONARY.md` |
| **UX-007** |  | Error messages shall state what happened, whether content was saved, what the user can do, and the correlation ID/support route; raw connector erro... | Implemented, tenant validation pending | `src/modules/DmsProvisioning/Public/Lifecycle.ps1`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md`<br>`src/power-platform/flow-specifications/README.md` |
| **UX-008** |  | Custom experiences shall conform to NFR-009 accessibility requirements and support keyboard-only use, visible focus, text scaling, screen-reader na... | Not referenced | — |
| **UX-009** |  | Notifications shall be actionable but concise and shall link to the authoritative source; reminders shall be consolidated where practical to reduce... | Not referenced | — |
| **UX-010** |  | The system shall provide role-specific onboarding, one-page quick references, glossary, lifecycle diagram, and contextual help. | Specified | `docs/USER_GUIDES/README.md` |
| **UX-011** |  | Administrative screens shall expose configuration status and validation without giving business users access to sensitive platform details. | Not referenced | — |
| **UX-012** |  | Mobile access shall be either tested for the defined read/approve use cases or explicitly marked unsupported for MVP; authoring on mobile is not as... | Not referenced | — |

## Metrics (MET)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **MET-001** |  | Control completeness: effective documents passing all required metadata and approval-evidence checks / all effective documents. | Implemented and tested | `config/lists.json`<br>`config/metrics.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1`<br>`src/reporting/Export-DmsMetrics.ps1` |
| **MET-002** |  | Findability success: representative users completing the current-document task within 60 seconds / users tested. | Implemented, tenant validation pending | `config/metrics.json` |
| **MET-003** |  | Approval cycle time: median business days from valid submission to final decision; report stage percentiles separately. | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/OPERATIONS_RUNBOOK.md` |
| **MET-004** |  | Overdue review rate: effective documents beyond next-review date / effective documents due for review. | Implemented, tenant validation pending | `config/metrics.json`<br>`config/site-columns.json`<br>`config/views.json`<br>`src/power-platform/flow-specifications/Flow4-Periodic-Review.md` |
| **MET-005** |  | Ownerless effective documents: count with no active owner. | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/metrics.json`<br>`config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1` |
| **MET-006** |  | Workflow success: terminal successful lifecycle runs / all eligible terminal runs, excluding approved tests/cancellations. | Implemented, tenant validation pending | `config/metrics.json` |
| **MET-007** |  | Aged blocking exceptions: open blocking exceptions older than one business day. | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`config/views.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **MET-008** |  | Stale check-out rate: documents checked out beyond approved threshold / checked-out documents. | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/environments.schema.json`<br>`config/lists.json` |
| **MET-009** |  | Retention mapping coverage: in-scope classes with approved mapping / all in-scope classes. | Implemented, tenant validation pending | `config/metrics.json` |
| **MET-010** |  | Retention-label conformance: sampled records with expected label/state / sampled records. | Implemented, tenant validation pending | `config/metrics.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md`<br>`docs/OPERATIONS_RUNBOOK.md`<br>`docs/PURVIEW_DESIGN.md` |
| **MET-011** |  | Disposition backlog: due disposition items open more than 30 days / all due items. | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/OPERATIONS_RUNBOOK.md` |
| **MET-012** |  | Acknowledgement completion: completed by due date / assigned acknowledgements. | Implemented, tenant validation pending | `config/lists.json`<br>`config/metrics.json`<br>`docs/DATA_DICTIONARY.md` |
| **MET-013** |  | Pilot adoption: eligible users with at least one qualifying DMS interaction in 30 days / eligible pilot users. | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/OPERATIONS_RUNBOOK.md` |
| **MET-014** |  | Uncontrolled current-document incidents: verified cases where a DMS experience presents the wrong revision as current. | Implemented and tested | `config/metrics.json`<br>`src/modules/DmsProvisioning/Public/Lifecycle.ps1`<br>`src/power-platform/flow-specifications/Flow3-Scheduled-Activation.md`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **MET-015** |  | Recovery conformance: latest restore exercise completed within approved RTO with data within approved RPO. | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/BACKUP_RECOVERY_PLAN.md`<br>`docs/OPERATIONS_RUNBOOK.md` |

## Objectives (OBJ)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **OBJ-01** |  | Make current controlled information reliably findable. | Implemented, tenant validation pending | `config/metrics.json` |
| **OBJ-02** |  | Establish complete control evidence for effective documents. | Implemented and tested | `config/metrics.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1`<br>`tests/pester/DmsRules.Tests.ps1` |
| **OBJ-03** |  | Reduce lifecycle delay and manual coordination. | Implemented, tenant validation pending | `config/metrics.json` |
| **OBJ-04** |  | Prevent unmanaged document ageing. | Implemented, tenant validation pending | `config/metrics.json` |
| **OBJ-05** |  | Apply defensible retention and disposition. | Implemented, tenant validation pending | `config/metrics.json` |
| **OBJ-06** |  | Operate supportable automation. | Implemented, tenant validation pending | `config/metrics.json` |
| **OBJ-07** |  | Demonstrate controlled adoption. | Implemented, tenant validation pending | `config/metrics.json` |

## Workflows (WF)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **WF-01** |  |  | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`src/power-platform/flow-specifications/Flow1-Request-Triage.md`<br>`src/power-platform/flow-specifications/README.md` |
| **WF-02** |  |  | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md`<br>`src/power-platform/flow-specifications/README.md` |
| **WF-03** |  |  | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`src/power-platform/flow-specifications/Flow3-Scheduled-Activation.md`<br>`src/power-platform/flow-specifications/README.md` |
| **WF-04** |  |  | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`src/power-platform/flow-specifications/Flow4-Periodic-Review.md`<br>`src/power-platform/flow-specifications/README.md` |
| **WF-05** |  |  | Implemented, tenant validation pending | `config/content-types.json`<br>`config/libraries.json`<br>`config/lifecycle-states.json` |
| **WF-06** |  |  | Implemented, tenant validation pending | `config/lifecycle-states.json`<br>`config/lists.json`<br>`config/views.json`<br>`src/power-platform/flow-specifications/Flow5-Exception-Management.md` |
| **WF-07** |  |  | Not referenced | — |
| **WF-08** |  |  | Not referenced | — |

## Open questions (OQ)

| ID | Priority | Requirement | Coverage | Key artefacts |
|---|:--:|---|---|---|
| **OQ-01** |  | Which legal, contractual, quality, safety, privacy, records, and sector-specific regimes apply to the pilot and enterprise scope? | Specified | `docs/OPEN_DECISIONS.md`<br>`docs/PURVIEW_DESIGN.md` |
| **OQ-02** |  | What Microsoft 365 licences and add-ons are owned, and which may be purchased? | Implemented, tenant validation pending | `src/reporting/README.md`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-03** |  | What is the approved retention schedule/file plan, including triggers, periods, disposition, and proof requirements? | Implemented, tenant validation pending | `config/retention-map.example.json`<br>`src/modules/DmsProvisioning/Public/Configuration.ps1`<br>`src/provisioning/Deploy-DmsPurview.ps1`<br>`docs/ARCHITECTURE_DECISIONS.md` |
| **OQ-04** |  | Which pilot business process, document types, operational record, and user population will validate the MVP? | Implemented, tenant validation pending | `config/environments.json`<br>`config/taxonomy.json`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-05** |  | Is a single controlled library with approved major versions sufficient, or must each approved revision be a separate immutable artefact? | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/libraries.json`<br>`docs/ARCHITECTURE_DECISIONS.md` |
| **OQ-06** |  | What RPO, RTO, recovery scope, retention, and exercise frequency apply? | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/ARCHITECTURE.md`<br>`docs/BACKUP_RECOVERY_PLAN.md` |
| **OQ-07** |  | What audit-evidence retention period is required, and does existing Audit licensing meet it? | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/environments.schema.json`<br>`docs/ARCHITECTURE.md` |
| **OQ-08** |  | What external sharing, guest, offline access, sync, print, and download scenarios are permitted? | Implemented, tenant validation pending | `config/security-roles.json`<br>`src/provisioning/Deploy-DmsSecurity.ps1`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-09** |  | Does the organisation need acknowledgement, competence-based LMS training, or legally binding electronic signatures? | Specified | `docs/OPEN_DECISIONS.md` |
| **OQ-10** |  | What source repositories, volumes, formats, permissions, duplicate rate, and approval evidence must be migrated? | Implemented, tenant validation pending | `src/provisioning/Invoke-DmsDiscovery.ps1`<br>`docs/ENVIRONMENT_DISCOVERY.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-11** |  | What Document ID and business revision convention is required, and must it appear inside generated/renditioned files? | Implemented, tenant validation pending | `config/site-columns.json`<br>`src/modules/DmsProvisioning/Public/Integrity.ps1`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/DATA_DICTIONARY.md` |
| **OQ-12** |  | Which metadata fields are globally mandatory versus conditional by type, process, region, or confidentiality? | Implemented, tenant validation pending | `config/environments.json`<br>`config/taxonomy.json`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-13** |  | What approval authorities, delegation rules, quorum, sequencing, due dates, and escalation apply by document class? | Implemented, tenant validation pending | `config/lists.json`<br>`config/routing-rules.json`<br>`docs/DATA_DICTIONARY.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-14** |  | Are emergency change and suspension workflows required in MVP, and what post-hoc review is authorised? | Specified | `docs/OPEN_DECISIONS.md` |
| **OQ-15** |  | Is Power Apps required, or can native SharePoint forms meet MVP usability and accessibility? | Implemented, tenant validation pending | `config/libraries.json`<br>`docs/ARCHITECTURE_DECISIONS.md`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-16** |  | Which languages, regions, business calendars, and data-residency locations are required after MVP? | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`config/site-columns.json`<br>`config/taxonomy.json` |
| **OQ-17** |  | What baseline values exist for search time, approval time, overdue reviews, incidents, and support effort? | Implemented, tenant validation pending | `config/metrics.json`<br>`docs/OPEN_DECISIONS.md` |
| **OQ-18** |  | What operating hours, support severity response, and maintenance windows are required? | Implemented, tenant validation pending | `config/environments.example.json`<br>`config/environments.json`<br>`src/modules/DmsProvisioning/Public/Review.ps1`<br>`src/power-platform/flow-specifications/Flow2-Submit-Review-Approve.md` |

## P0 functional requirement coverage

The PRD marks **27** functional requirements as P0. "Not started" is not an acceptable final state for any of them.

| Coverage | P0 count |
|---|---:|
| Implemented and tested | 10 |
| Implemented, tenant validation pending | 17 |

**Every P0 functional requirement is referenced by configuration, code, specification or test.**

Tenant-dependent verification for all of the above is tracked in `docs/BUILD_STATUS.md`.
