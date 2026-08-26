# Product Requirements Document: Microsoft 365 SharePoint Document Management System

| Document control field | Value |
|---|---|
| Document status | Draft for stakeholder review |
| Version | 0.1 |
| Date | 25 August 2026 |
| Product | Enterprise Document Management System (DMS) on Microsoft 365 |
| Primary platform | SharePoint Online, Power Platform, Microsoft Purview, Microsoft Entra ID |
| Source baseline | SharePoint DMS Concept of Operations (CONOPS) developed in this task |
| Intended audience | Executive sponsor, Product Owner, Document Control, Records Management, Security, Privacy, IT, Engineering, QA, and business process owners |
| Decision authority | To be assigned |

## Research and Interpretation Notes

### What the CONOPS clearly establishes

The CONOPS establishes a Microsoft 365-based document-management capability in which SharePoint Online is the authoritative repository, Power Automate controls lifecycle workflows, Microsoft Purview controls retention and records, Microsoft Entra ID controls access, and Microsoft Lists or Power Apps provide business-process registers and request interfaces. It distinguishes working documents, controlled published documents, and operational records; defines a lifecycle from request through disposition; and identifies separate operational roles for authors, reviewers, approvers, Document Control, Records Management, platform administration, and readers.

### What research added

Research confirmed that:

- SharePoint content types and columns are the primary metadata mechanisms for organising and finding content, while deep folder structures are less flexible ([Microsoft SharePoint information architecture](https://learn.microsoft.com/en-us/sharepoint/information-architecture-modern-experience)).
- Required check-out and simultaneous co-authoring are incompatible operating modes; check-out should therefore be applied selectively ([Microsoft versioning guidance](https://support.microsoft.com/en-us/sharepoint/lists/documents-and-library/how-versioning-works-in-lists-and-libraries)).
- Power Automate can set SharePoint content approval status, and file approvals require the file ETag to protect version integrity ([Microsoft SharePoint connector guidance](https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/sharepoint-connector-actions-triggers)).
- Purview retention labels can manage individual documents, declare records, support event-based retention and disposition review, and provide proof of disposition; a regulatory-record label is intentionally difficult to reverse ([Microsoft Purview retention](https://learn.microsoft.com/en-us/purview/retention), [Microsoft Purview records management](https://learn.microsoft.com/en-us/purview/records-management)).
- ISO 15489-1 defines principles for records, metadata, responsibilities, monitoring, training, records controls, and the creation, capture, and management of records ([ISO 15489-1:2016](https://www.iso.org/standard/62542.html)).
- ISO guidance for ISO 9001 clause 7.5 treats controlled documented information as both process-supporting information and evidence that planned work occurred ([ISO 9001 documented-information guidance](https://www.iso.org/files/live/sites/isoorg/files/standards/docs/en/iso_9001_2015_guidance_documented_information.pdf)).
- Power Platform solutions, environments, connection references, and environment variables support governed application lifecycle management rather than production flows owned by individual makers ([Microsoft Power Platform ALM](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm)).

### Major assumptions

- The initial deployment is a corporate or ISO-oriented controlled-document system, not a validated GxP, FDA 21 CFR Part 11, defence-classified, FedRAMP, or qualified electronic-signature system.
- The organisation already owns Microsoft 365 and can license the required SharePoint, Power Platform, and Purview capabilities.
- Microsoft Entra ID is the authoritative workforce identity service.
- English is the MVP user-interface and document-control language.
- The MVP pilot will contain no more than 50,000 documents and 1,000 eligible users; enterprise volumes remain to be confirmed.
- The organisation will appoint Document Control and Records Management authorities before production launch.
- Proposed metric targets in this PRD are initial acceptance hypotheses and must be baselined during discovery and the pilot.

### Major unresolved questions

- Which legal, contractual, quality, privacy, or sector-specific regimes apply?
- What Microsoft 365 licences and add-ons are already available?
- What approved retention schedule and file plan must be implemented?
- Is the single-library controlled-document pattern sufficient, or must every approved revision be a separate immutable record?
- What recovery point objective (RPO), recovery time objective (RTO), audit-retention period, and data-residency requirements apply?
- Which repositories and file shares must be migrated, and what are their volumes and data quality?
- Does the organisation require acknowledgement only, compliance training through an LMS, or legally binding electronic signatures?

### Key scope implications

The MVP must prove one end-to-end controlled-document lifecycle before adding intelligent document processing, bespoke interfaces, complex external integrations, or enterprise-wide migration. The product must retain native SharePoint behaviour wherever it satisfies the requirement and reserve custom development for validated gaps.

---

## 1. Executive Summary

The product is an enterprise Document Management System built on Microsoft 365. It will provide a governed source of truth for policies, standard operating procedures (SOPs), work instructions, controlled templates, business operations documents, completed records, approval evidence, and disposition decisions.

The product will replace inconsistent folder structures, emailed attachments, undocumented approvals, uncontrolled copies, manual review reminders, and ambiguous retention practices with metadata-driven libraries, role-based access, version control, approval workflows, current-document publishing, review scheduling, audit evidence, retention labels, and management reporting.

The recommended MVP is a pilot for one business function using a single governed controlled-document library, a document register, a change-request register, an approval-evidence register, role-based Entra groups, three core Power Automate workflows, a read-only current-document portal, and an approved Purview retention mapping. The stricter two-library immutable-revision model remains an architectural option pending compliance review.

The product will be accepted when authorised users can create, review, approve, publish, find, revise, supersede, retain, and dispose of controlled information with complete metadata and traceable evidence; ordinary readers can reliably identify the current effective version; and administrators can monitor access, workflow exceptions, overdue reviews, and records status.

## 2. Source Document Interpretation

### 2.1 Mission or business purpose

Create a sustainable enterprise operating capability that ensures personnel use the correct, approved, effective, protected, and retrievable business information while preserving evidence of decisions and meeting approved retention obligations.

### 2.2 Operational problem

Business documents are commonly distributed across network drives, Teams sites, email, OneDrive, local devices, and inconsistent SharePoint libraries. This fragmentation makes it difficult to determine ownership, current revision, approval status, applicability, review date, confidentiality, and retention treatment. Manual controls increase the risk of outdated SOP use, missing approval evidence, abandoned check-outs, duplicated records, uncontrolled sharing, and unmanaged disposal.

### 2.3 Intended users

- Employees and contractors who consume controlled information.
- Authors who create and revise documents.
- Subject-matter reviewers and accountable approvers.
- Document Controllers who administer the document lifecycle.
- Records Managers who administer the file plan and disposition.
- Security, Privacy, Legal, Quality, and Compliance reviewers.
- Microsoft 365 and Power Platform administrators.
- Managers and executives who require operational and compliance reporting.

### 2.4 Future-state capability

The future state provides one governed portal that routes users to current documents, controls draft visibility, captures review and approval evidence, activates approved revisions on their effective dates, retires superseded revisions from normal use, applies retention controls, and measures process health.

### 2.5 Core workflows

1. New-document and change request.
2. Controlled authoring and metadata completion.
3. Technical review and accountable approval.
4. Future-effective activation and publication.
5. Acknowledgement or training assignment.
6. Periodic review, revision, withdrawal, and supersession.
7. Operational-record capture and retention.
8. Disposition review and proof of disposal.
9. Exception, failed-flow, and stale-check-out management.
10. Administrative configuration, access review, reporting, migration, backup, and recovery.

### 2.6 Product boundary

The product includes configured Microsoft 365 sites, libraries, lists, content types, taxonomy, views, search experiences, Power Apps, Power Automate flows, Purview controls, Entra groups, reporting, provisioning scripts, runbooks, and operating procedures.

The product does not include a general enterprise resource planning system, contract lifecycle management suite, learning management system, qualified electronic-signature service, or validated eQMS unless separately approved as an integration or later phase.

### 2.7 Expected outcomes

- Users can identify and retrieve the current effective document quickly.
- Every effective controlled document has an accountable owner, approved revision, effective date, review date, classification, and retention treatment.
- Approval and lifecycle decisions are attributable and auditable.
- Superseded and withdrawn documents no longer appear in normal current-document experiences.
- Completed business records are retained and disposed of according to an approved file plan.
- Operational owners can see bottlenecks, overdue reviews, exceptions, and adoption.

### 2.8 Terminology requiring control

| Term | Controlled meaning in this PRD |
|---|---|
| Controlled document | Information whose creation, review, approval, publication, revision, and withdrawal are governed. |
| Operational record | Evidence of a completed business activity that is captured and retained. |
| Effective revision | The approved revision authorised for current operational use. |
| Major version | A SharePoint published milestone version. |
| Minor version | A SharePoint draft version not intended for general reader use. |
| Approval Status | Native SharePoint content state such as Draft, Pending, Approved, or Rejected. |
| Lifecycle Status | Business state such as Authoring, In Review, Approved Pending Effective, Effective, Superseded, Withdrawn, or Obsolete. |
| Record label | A Purview retention label configured to impose records-management restrictions. |
| Regulatory record | A Purview record type with irreversible restrictions; it is not synonymous with an ordinary business record. |
| Controlled copy | An authorised rendition or view whose status and revision can be verified against the DMS. |

## 3. Research Method and Key Findings

Research was conducted on 25 August 2026 using primary and authoritative sources: Microsoft product documentation, ISO publications, W3C standards, NIST publications, and UK Information Commissioner's Office guidance. Research was limited to findings that affect product scope, requirements, controls, metrics, or risk.

| Finding | Evidence | Relevance | PRD implication | Requirement impact |
|---|---|---|---|---|
| Metadata and content types are core SharePoint information-architecture mechanisms. | [Microsoft information architecture](https://learn.microsoft.com/en-us/sharepoint/information-architecture-modern-experience) | A DMS cannot depend on folder paths alone. | Establish centrally governed content types, columns, taxonomy, indexed views, and search. | F-001, F-002, F-021; NFR-008 |
| Required check-out blocks simultaneous co-authoring. | [Microsoft versioning guidance](https://support.microsoft.com/en-us/sharepoint/lists/documents-and-library/how-versioning-works-in-lists-and-libraries) | A single checkout policy cannot serve every collaboration mode. | Configure check-out by library and use it only where exclusive editing is required. | F-004, F-006; risk R-04 |
| File approval through Power Automate requires ETag handling. | [Microsoft SharePoint connector](https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/sharepoint-connector-actions-triggers) | Approval must apply to the reviewed version, not a later edit. | Capture version and ETag; reject or restart if the content changes during approval. | F-008, F-009; NFR-011 |
| Retention labels and policies serve different scopes. | [Microsoft Purview retention](https://learn.microsoft.com/en-us/purview/retention) | Site-wide rules alone cannot express mixed document schedules. | Use policies for uniform containers and labels for item-level classes. | F-018, F-020; DATA-007 |
| Regulatory record labels are deliberately irreversible and cannot be applied to checked-out files. | [Microsoft Purview records management](https://learn.microsoft.com/en-us/purview/records-management) | Incorrect use can prevent legitimate revision or deletion. | Regulatory records require explicit legal approval, testing, and a separate design decision. | F-019; SEC-012; risk R-06 |
| Audit Standard normally retains audit records for 180 days; premium licensing supports longer policies. | [Microsoft audit retention](https://learn.microsoft.com/en-us/purview/audit-log-retention-policies) | Native audit duration may be shorter than document-retention obligations. | Keep durable approval evidence in a governed register and approve an audit-retention policy. | F-009, F-024; NFR-012 |
| SharePoint supports large libraries but unique-permission and synchronisation patterns have lower practical limits. | [Microsoft SharePoint limits](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits) | Item-level permissions and uncontrolled sync create scale and support risks. | Prefer library/site security boundaries, indexed metadata, and governed sync. | F-022, F-023; NFR-004 |
| Power Platform environments and managed solutions provide ALM boundaries. | [Microsoft Power Platform ALM](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm) | Individually owned production flows are not supportable. | Use Dev/Test/Prod, solutions, connection references, environment variables, source control, and controlled deployment. | ADM-004, ADM-005; NFR-010 |
| ISO 15489 emphasises records, metadata, responsibilities, controls, monitoring, and training. | [ISO 15489-1:2016](https://www.iso.org/standard/62542.html) | The product is an operating system of people, process, controls, and technology. | Require assigned owners, documented procedures, monitoring, and training in addition to software. | F-014, F-020; ADM-001; DoD |
| ISO 9001 documented-information guidance distinguishes information needed to operate processes from retained evidence. | [ISO guidance](https://www.iso.org/files/live/sites/isoorg/files/standards/docs/en/iso_9001_2015_guidance_documented_information.pdf) | Blank controlled forms and completed forms require different lifecycle treatment. | Model controlled templates separately from completed operational records. | F-003, F-029; DATA-001, DATA-006 |
| WCAG 2.2 is the current W3C Recommendation and adds testable accessibility criteria. | [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/) | Custom portals, forms, formatting, and apps can introduce accessibility barriers. | Require WCAG 2.2 AA testing for custom user experiences. | NFR-009; UX-008 |
| UK GDPR principles include data minimisation, storage limitation, integrity, and confidentiality. | [ICO data-protection principles](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/) | DMS metadata and operational records may contain personal information. | Minimise personal fields, define retention, restrict access, and complete a privacy assessment when applicable. | SEC-008 to SEC-011; DATA-010 |
| Microsoft 365 document processing can provide OCR, classification, content assembly, translation, and eSignature on a pay-as-you-go basis. | [Microsoft document processing](https://learn.microsoft.com/en-us/microsoft-365/documentprocessing/syntex-overview) | Advanced automation is available but is not necessary to validate the core DMS. | Defer intelligent processing and automated document generation to P1/P2 unless the pilot proves a high-value use case. | F-031, F-034, F-035 |
| Microsoft 365 Backup offers SharePoint recovery points and site-level restore, with separate service and cost considerations. | [Microsoft 365 Backup](https://learn.microsoft.com/en-us/microsoft-365/backup/backup-overview) | Versioning and recycle bins do not by themselves define a business recovery service. | Approve RPO/RTO and select native or third-party backup accordingly. | NFR-013; ADM-010; open question OQ-06 |

## 4. Operational Context

### 4.1 Operating environment

The DMS operates within the organisation's Microsoft 365 tenant and is accessed through supported browsers, Microsoft 365 desktop applications, mobile clients where authorised, and optionally Teams. SharePoint is the authoritative content repository. Teams, email, Power Apps, and dashboards expose tasks or links but do not create competing authoritative copies.

### 4.2 Operating principles

1. **One authoritative source:** Users receive links, not uncontrolled attachments.
2. **Metadata before folders:** Classification, search, views, retention, and reporting depend on controlled metadata.
3. **Current documents by default:** Ordinary readers see only effective content unless specifically authorised to view history.
4. **Separate document and record lifecycles:** Controlled instructions and completed evidence are different entities.
5. **Least privilege:** Access is granted through role-based groups and reviewed regularly.
6. **Workflow evidence is durable:** Approval decisions are stored as governed records, not solely as transient flow-run history.
7. **Configuration as code:** Repeatable provisioning and managed solutions reduce environment drift.
8. **Human accountability remains:** Automation routes and records decisions; it does not replace accountable approval.

### 4.3 Operating modes

| Mode | Description | Applicable content |
|---|---|---|
| Collaborative | Co-authoring enabled; no forced check-out; version history retained. | General working documents not subject to formal control. |
| Controlled authoring | Minor versions, draft security, optional required check-out, formal review and approval. | Policies, SOPs, work instructions, controlled templates. |
| Published consumption | Read-only current-effective view or library; direct authoritative links. | Current controlled documents. |
| Records | Changes restricted according to approved retention label and record state. | Completed forms, approvals, reports, superseded revisions where required. |
| Administrative recovery | Restricted access for Document Control, Records Management, and platform support. | Exceptions, migration evidence, restore operations, disposition evidence. |

### 4.4 System context

```text
Microsoft Entra ID ── identities and groups ──────────────┐
                                                         v
Users/Teams/Office ── links and documents ──> SharePoint DMS
                                               │    │    │
                         Power Apps/Lists <─────┘    │    └──> Microsoft Search
                               │                    │
                               └──> Power Automate ─┼──> Approvals/Notifications
                                                    │
                                                    ├──> Purview labels/audit/DLP
                                                    ├──> Power BI reporting
                                                    └──> Backup/recovery service
```

## 5. Problem Statement

Employees, Document Controllers, process owners, and compliance stakeholders cannot consistently determine whether a business document is current, approved, applicable, protected, review-complete, or retained correctly when information is distributed across folders, email, Teams, OneDrive, and inconsistently configured SharePoint sites. Existing manual methods are insufficient because they rely on filenames, individual knowledge, email approvals, and calendar reminders rather than enforced metadata, workflow state, version integrity, and durable evidence. If unresolved, the organisation risks use of obsolete instructions, delayed approvals, missing evidence, oversharing, retention violations, rework, audit findings, and operational disruption. The product must enable at least 90% of representative users to find the current effective document within 60 seconds and must ensure 100% of newly effective MVP documents contain the required control metadata and approval evidence.

## 6. Product Vision

Provide every authorised person with a trustworthy, simple, and auditable way to create, govern, find, use, and retire business information across its lifecycle, using Microsoft 365 as the operating platform and retaining human accountability for content decisions.

The product experience should make the compliant action the easiest action: readers search or browse current documents; authors start from controlled templates; reviewers receive a version-specific task; approvers see the content and impact; Document Control governs publication; Records Management governs retention and disposal; and administrators support the platform without becoming content authorities.

## 7. Product Objectives

Targets below are proposed unless marked confirmed. Baselines must be collected during discovery and pilot operation.

| Objective ID | Objective | Stakeholder served | Operational value | Measurement | Initial success threshold |
|---|---|---|---|---|---|
| OBJ-01 | Make current controlled information reliably findable. | Readers, operators | Reduces obsolete-document use and search time. | Moderated findability test and search analytics. | At least 90% of representative users find the current document within 60 seconds without help. |
| OBJ-02 | Establish complete control evidence for effective documents. | Document Control, auditors | Proves ownership, approval, revision, effective date, and review status. | Metadata and approval-register reconciliation. | 100% of newly effective MVP documents pass the control-completeness rule. |
| OBJ-03 | Reduce lifecycle delay and manual coordination. | Authors, reviewers, approvers | Shortens time from submission to effective use. | Median elapsed business days by workflow stage. | Median approval cycle at or below 5 business days after stabilisation; no stage lacks an owner. |
| OBJ-04 | Prevent unmanaged document ageing. | Process owners, Quality | Reduces overdue reviews and unknown ownership. | Effective documents past next-review date. | Fewer than 5% overdue after 90 days of steady-state operation; zero ownerless effective documents. |
| OBJ-05 | Apply defensible retention and disposition. | Records Management, Legal, Privacy | Protects necessary evidence and limits unnecessary storage. | Label coverage, exception sampling, disposition backlog. | 100% of MVP record classes mapped to an approved retention class; no disposal occurs without authorised rule or review. |
| OBJ-06 | Operate supportable automation. | IT, Product Owner | Prevents hidden workflow failure and personal-owner dependency. | Monthly run success, exception age, deployment audit. | At least 99% of lifecycle runs complete without manual repair; no production flow has a sole personal owner. |
| OBJ-07 | Demonstrate controlled adoption. | Sponsor, managers | Validates business value before enterprise expansion. | Eligible-user activity and acknowledgement data. | At least 80% of eligible pilot users use the DMS monthly by 90 days after launch. |

### Objective classes

- **Mission objective:** Ensure personnel act using current, authorised information and preserve evidence of business activity.
- **Product objectives:** OBJ-01 through OBJ-07.
- **User objectives:** Find current documents, complete assigned reviews, publish correctly, and understand exceptions.
- **Technical objectives:** Reliable workflows, governed deployment, auditable access, configuration consistency, and recoverability.

## 8. Stakeholders and User Roles

| Stakeholder | Primary objectives | Responsibilities | Decisions and information needed | Success criteria | Likely objection or adoption risk |
|---|---|---|---|---|---|
| Executive Sponsor | Reduce operational and compliance risk; obtain measurable value. | Fund, set authority, resolve cross-functional conflicts. | Cost, adoption, risk, overdue reviews, audit results. | Pilot objectives met and ownership sustained. | Perception that SharePoint configuration alone solves governance. |
| Product Owner | Deliver and improve the DMS service. | Prioritise backlog, accept releases, coordinate stakeholders. | User evidence, defects, metrics, licence and platform constraints. | Stable roadmap and accepted releases. | Scope expansion across unrelated business processes. |
| Document Controller | Maintain control integrity. | Triage requests, assign IDs, validate metadata, publish, supersede, resolve check-outs. | Status, owners, approvals, effective dates, exceptions. | Zero uncontrolled publication; low overdue-review rate. | Excessive manual workload or automation that obscures accountability. |
| Author | Produce accurate controlled content. | Draft, classify, respond to review, provide change summaries. | Template, requirements, reviewers, due dates, prior revision. | Draft accepted without avoidable metadata or formatting rework. | Forced check-out or metadata burden during normal authoring. |
| Reviewer/SME | Verify technical accuracy and usability. | Review assigned version, comment, approve or reject review stage. | Exact version, change summary, scope, due date. | Decision recorded against the correct revision. | Approval fatigue and unclear authority. |
| Accountable Approver | Accept business, quality, legal, or risk accountability. | Make final decision; state conditions or rejection rationale. | Reviewer outcomes, impact, exact revision, effective date. | Attributable and timely decision. | Treating an email acknowledgement as a sufficient signature. |
| Reader/Operator | Use current authorised guidance. | Search, read, follow, acknowledge when required, report errors. | Current status, applicability, owner, effective date. | Finds correct document quickly and recognises current status. | Confusing portal, duplicate search results, or obsolete links. |
| Records Manager | Apply approved file plan and disposal governance. | Define labels, approve mappings, monitor retention, conduct disposition. | Record class, trigger, period, legal holds, disposition evidence. | Complete label coverage and defensible disposal. | Labels configured before the retention schedule is approved. |
| Quality/Compliance | Verify controlled-process design. | Approve lifecycle rules, sample evidence, review deviations. | Control mapping, audit results, training evidence, exceptions. | Requirements traceable to controls and tests. | Unsupported claims that the platform is automatically compliant. |
| Security/Privacy/Legal | Protect information and define obligations. | Approve classification, sharing, privacy, legal hold, incident response. | Data types, access model, residency, processors, retention. | Risks assessed and controls evidenced. | Sensitive information placed in broadly accessible sites. |
| Platform Administrator | Maintain Microsoft 365 service configuration. | Provision, deploy, monitor, recover, and support. | Configuration baseline, service health, failed flows, permissions. | Repeatable deployments and recoverable service. | Being assigned content-approval authority by convenience. |
| Manager/Executive Consumer | Monitor process health. | Review dashboards and direct remediation. | Adoption, cycle time, backlog, risk, exceptions. | Timely intervention and measurable improvement. | Metrics without definitions or actionable owners. |
| External Partner | Supply or consume authorised content where approved. | Authenticate, access permitted content, follow sharing terms. | Access duration, permitted use, applicable document. | Least-privilege access with expiry and audit. | Guest access complexity or inadvertent oversharing. |

## 9. Current-State Analysis

The CONOPS implies a fragmented current state. Discovery shall verify each point and capture baselines before design sign-off.

| Current-state condition | Operational effect | Evidence to collect during discovery |
|---|---|---|
| Documents held in network drives, Teams, email, OneDrive, and local folders. | Duplicate and conflicting versions; unclear source of truth. | Repository inventory, duplicate sample, link and attachment analysis. |
| Folder and filename conventions carry most classification. | Poor filtering, inconsistent naming, fragile moves, weak retention mapping. | Folder-depth analysis, naming exceptions, search-task testing. |
| Approvals occur through email or informal meetings. | Decision evidence is separated from the reviewed revision. | Approval sample, audit findings, rework incidents. |
| Review dates are tracked in spreadsheets or individual calendars. | Overdue reviews and ownerless documents are difficult to identify. | Overdue counts, calendar/register samples. |
| Teams and SharePoint sites have inconsistent permissions and settings. | Oversharing and administrative effort. | Site and sharing report, group ownership, broken inheritance. |
| Completed forms are stored with blank templates. | Instruction and evidence receive the wrong lifecycle and retention treatment. | Content sample by form type. |
| Users email attachments for convenience. | Uncontrolled offline copies remain after supersession. | Mail sample, user interviews, stale-copy incidents. |
| Flow or macro automation is personally owned. | Failure when owners leave; little release or support evidence. | Flow inventory, ownership, connections, environment analysis. |
| Reporting is manual and retrospective. | Leaders cannot identify bottlenecks early. | Existing reports, preparation effort, decision latency. |
| Recovery relies on version history and recycle bins without approved objectives. | Recovery capability may not match business expectations. | Incident history, current backup contracts, RPO/RTO interviews. |

## 10. Future-State Concept

### 10.1 Operating-model change

The DMS changes document control from a location-and-filename practice to a lifecycle-and-metadata service. Authors create from controlled templates; the system validates metadata; reviewers and approvers act on a version-specific task; Document Control governs activation; readers see the current effective revision; Records Management governs retention; and dashboards expose ageing and exceptions.

### 10.2 Target logical architecture

| Component | Purpose | MVP treatment |
|---|---|---|
| DMS communication site | Home, help, role-based navigation, current documents, search. | Required |
| Controlled Documents library | Drafts, minor/major versions, approval state, lifecycle metadata. | Required |
| Published Revisions library | Separate immutable approved revision artefacts. | Decision gate; not default MVP |
| Templates library | Controlled Word/Excel/PowerPoint templates. | Required |
| Operational Records library | Completed forms and evidence. | One pilot record class required |
| External References library | Supplier, customer, legal, and standards documents. | P1 unless pilot needs it |
| Document Register list | Master index and lifecycle summary. | Required |
| Change Request list | New, revise, withdraw, emergency-change requests. | Required |
| Approval Evidence list | Version-specific decisions and comments. | Required |
| Acknowledgement list | Assignment and user response evidence. | P1; MVP only if pilot requires it |
| Exception Register list | Failed flows, stale check-outs, data and permission exceptions. | Required |
| Purview file plan and labels | Retention, record declaration, disposition. | Required for pilot classes |
| Power Platform solution | Apps and flows deployed through Dev/Test/Prod. | Required |
| Reporting semantic model/dashboard | Operational, management, compliance indicators. | MVP summary plus export |

### 10.3 Information flow

1. Request data creates or updates the Document Register.
2. The approved content type and template create a controlled document.
3. Authoring updates draft content and metadata.
4. Submission captures the document version and ETag.
5. Review and approval decisions are stored in the Approval Evidence register.
6. Activation publishes the approved major version and updates lifecycle metadata.
7. Search and portal views expose only authorised effective content by default.
8. Review scheduling creates owner tasks and escalations.
9. Revision or withdrawal changes the current-effective relationship.
10. Retention and disposition actions are governed by Purview and Records Management.

### 10.4 Decision improvement

- Reviewers receive the exact revision and change summary.
- Approvers see previous decisions, applicability, and proposed effective date.
- Document Control sees completeness checks and exceptions before publication.
- Records Managers see label coverage and disposition workload.
- Managers see process delay, ageing, adoption, and exceptions.
- Readers see current status and applicability without interpreting filenames.

## 11. Product Scope

### 11.1 In scope for MVP

| Capability | Rationale |
|---|---|
| DMS portal and current-document experience | Validates reliable consumption of controlled information. |
| Controlled content types, metadata, taxonomy, and templates | Foundation for search, workflow, records, and reporting. |
| Major/minor versioning, content approval, and selective check-out | Core document-control mechanism. |
| New/change/withdraw request register | Establishes authorised lifecycle entry. |
| Review, approval, rejection, and version-integrity controls | Establishes accountable decision flow. |
| Future-effective activation and supersession | Prevents premature publication and obsolete-document use. |
| Periodic-review scheduling and escalation | Prevents unmanaged ageing. |
| Document, approval, and exception registers | Provides durable evidence and supportability. |
| Role-based access using Entra groups | Establishes least privilege and separation of duties. |
| One operational-record class with retention mapping | Validates document-versus-record lifecycle. |
| Search, filtering, and indexed views | Validates findability. |
| Basic dashboard and CSV export | Supports operational control and pilot evaluation. |
| Dev/Test/Prod ALM, provisioning scripts, monitoring, and runbooks | Makes the product deployable and supportable. |
| Pilot migration with reconciliation | Validates transition from an existing repository. |

### 11.2 Out of scope for MVP

| Capability | Rationale |
|---|---|
| Enterprise-wide migration | Too risky before information architecture and workflows are proven. |
| Full eQMS, CAPA, non-conformance, or validation suite | Separate product domain requiring dedicated requirements and possible specialist software. |
| Qualified or regulated electronic signatures | Power Automate approvals are not assumed to meet signature law or sector regulation. |
| Full learning management | Acknowledgement can be captured, but competency and certification require an LMS decision. |
| Contract lifecycle management | Negotiation, clause management, obligation tracking, and counterparty workflows are separate scope. |
| Bespoke SharePoint Framework application | Native SharePoint and Power Platform capability must first be validated. |
| AI classification, OCR, translation, or content assembly | Valuable enhancements but not required to prove core lifecycle control. |
| Unrestricted guest collaboration | External access requires a separately approved sharing model. |
| Regulatory-record labels | Deferred until legal need, irreversible effects, and operating procedure are approved. |

### 11.3 Future considerations

- Separate immutable Published Revisions library.
- Enterprise search vertical and advanced refiners.
- Document Sets for case files and multi-document deliverables.
- Automated PDF rendition and controlled-print watermarking.
- Microsoft 365 document processing for OCR, extraction, classification, and content assembly.
- eSignature integration after legal and compliance assessment.
- LMS integration and role-derived training assignments.
- ERP, CRM, HRIS, service-management, and contract-system integrations.
- Multilingual metadata, translated documents, and regional retention variations.
- SharePoint Advanced Management for site ownership, attestation, inactive-site policy, restricted access control, and oversharing insight.
- Microsoft 365 Backup or approved third-party backup based on RPO/RTO.

## 12. MVP Definition

### 12.1 Core use case

A pilot business function creates or revises an SOP, obtains technical review and accountable approval against a fixed version, activates it on a defined effective date, exposes it through the current-document portal, performs a scheduled review, and retains the approval evidence and one associated completed operational record.

### 12.2 MVP users

- 1 Product Owner.
- 1–3 Document Controllers.
- 5–20 authors/reviewers/approvers.
- Up to 1,000 eligible readers.
- 1 Records Manager or delegated authority.
- Security, Privacy, Quality, and IT representatives.

### 12.3 Required workflows

1. New/change/withdraw request.
2. Submit-review-approve/reject.
3. Scheduled activation and supersession.
4. Periodic review and escalation.
5. Exception and failed-run management.

### 12.4 Required entities

Controlled Document, Document Revision, Change Request, Approval Decision, Document Register, Operational Record, Retention Class, Exception, User/Group Role, and Migration Evidence.

### 12.5 Required controls

MFA and tenant Conditional Access as applicable; Entra group-based access; least privilege; draft visibility; version and ETag capture; separation of platform administration from content approval; external sharing disabled for pilot sites unless approved; retention mapping; durable audit evidence; managed deployment; backup/recovery test; and accessibility testing.

### 12.6 Required reports

- Current and effective documents.
- Documents pending review or approval.
- Documents due for review and overdue.
- Stale check-outs.
- Workflow failures and aged exceptions.
- Metadata/control completeness.
- Retention-label coverage.
- Pilot adoption and search-task success.

### 12.7 Excluded MVP features

Enterprise migration, intelligent document processing, advanced eSignature, full LMS, external partner portal, custom SPFx, regulatory records, and multi-region variations.

### 12.8 Validation method

- Scripted configuration validation.
- Functional and negative tests derived from requirements.
- Security and permission tests by role.
- Migration count and metadata reconciliation.
- Restore exercise.
- Moderated usability test using representative find-and-act tasks.
- Four-week controlled pilot followed by a 30/60/90-day metric review.

### 12.9 MVP success criteria

- All P0 requirements accepted.
- At least 20 representative documents complete the full lifecycle, including one rejection and one supersession.
- 100% of effective pilot documents pass metadata and evidence reconciliation.
- At least 90% user findability success within 60 seconds.
- At least 99% workflow-run success after the first two weeks of stabilisation.
- No unresolved Critical or High security defects.
- Recovery test meets the approved interim RPO/RTO.
- Product Owner, Document Control, Records Management, Security, and pilot business owner sign acceptance.

### 12.10 Risk of under-scoping

An MVP without real migration, records treatment, negative approval paths, future effective dates, and restore testing could demonstrate a pleasant SharePoint portal while failing to validate the operating controls that make it a DMS. Those scenarios are therefore mandatory in the pilot.

## 13. User Personas

| Persona | Operational context and responsibilities | Goals and common tasks | Pain points | Permissions and information needs | Success criteria |
|---|---|---|---|---|---|
| Reader/Operator | Uses controlled information while performing work. | Find current SOP; filter by process/site; confirm effective date; acknowledge assigned change. | Duplicate results, obsolete attachments, unfamiliar metadata. | Read effective content only; see owner, applicability, status, effective date. | Finds correct content without help and does not use superseded copies. |
| Controlled-Document Author | Creates and revises policies, SOPs, and templates. | Start from template; edit draft; supply metadata; submit; resolve comments. | Check-out confusion, repetitive metadata, unclear review route. | Contribute to assigned drafts; see previous revision and reviewer feedback. | Submits a complete draft and understands status at all times. |
| Reviewer/Approver | Performs technical or accountable decision. | Review exact version; compare change summary; approve or reject with comments. | Email overload, changed content after review, ambiguous responsibility. | Read reviewed content; act on assigned task; cannot silently edit approved content. | Decision is timely, attributable, and version-specific. |
| Document Controller | Runs daily control operations. | Triage requests; assign IDs; validate metadata; activate; supersede; resolve check-outs; manage exceptions. | Manual registers, inconsistent libraries, hidden flow failures. | Broad lifecycle administration without unnecessary tenant administration. | No uncontrolled publication; issues visible and recoverable. |
| Records Manager | Governs records after capture. | Maintain file plan; map labels; review exceptions; authorise disposition. | Records mixed with drafts; incomplete triggers; irreversible label mistakes. | Purview records role; read relevant content and evidence; restricted disposition authority. | Approved rules applied and disposal evidenced. |
| Platform Support Administrator | Maintains configuration and automation. | Deploy solutions; validate drift; monitor flows; restore; rotate connections. | Personal ownership, hard-coded URLs, production editing. | Platform administration; no default content-approval authority. | Repeatable deployment, monitored operation, tested recovery. |
| Compliance/Quality Auditor | Samples control operation and evidence. | Trace request to revision, approval, effective use, review, and disposition. | Decisions scattered across email and logs; weak provenance. | Read-only access to controlled evidence and reports. | Completes sample without manual reconstruction. |

### 13.1 Prioritised user stories

#### Reader/Operator

- As a reader, I want search and navigation to show the single current effective revision so that I do not act on obsolete instructions.
- As an operator following an old bookmark, I want to see that the document is superseded and be redirected to the replacement so that I can recover safely.
- As a reader assigned a new SOP, I want to acknowledge the exact revision through an authoritative link so that my response is attributable.

#### Author and Document Owner

- As an author, I want to start from the approved template and see only the metadata I must supply so that I can prepare a compliant draft without avoidable rework.
- As an author, I want rejected reviews to return version-specific comments so that I can correct and resubmit the document.
- As a document owner, I want reminders and escalation before a review becomes overdue so that the document does not remain effective without reassessment.

#### Reviewer and Approver

- As a reviewer, I want the task to identify the exact file version, change summary, and due date so that I know what I am reviewing.
- As an approver, I want the system to invalidate approval if the content changes after submission so that my decision cannot be applied to unreviewed content.
- As an approver, I want to approve, reject, or return with comments while preserving my identity and timestamp so that the decision is auditable.

#### Document Control and Records Management

- As a Document Controller, I want automated completeness checks and a work queue so that only correctly controlled documents become effective.
- As a Document Controller, I want stale check-outs and failed activations to appear as owned exceptions so that hidden failures do not block operations.
- As a Records Manager, I want document and record classes mapped to an approved file plan so that retention and disposal are defensible.
- As a Records Manager, I want irreversible record controls gated by authorised procedure so that configuration mistakes do not lock content permanently.

#### Platform Support and Management

- As a platform administrator, I want repeatable Dev/Test/Prod deployment and configuration validation so that environments do not drift.
- As a manager, I want agreed metrics for approval time, review compliance, exceptions, and adoption so that I can direct corrective action.
- As an auditor, I want to trace a document from request through approval, effective use, supersession, and retention without reconstructing evidence from personal email.

## 14. User Journeys and Operational Workflows

### WF-01: New document, revision, or withdrawal request

| Element | Definition |
|---|---|
| Trigger | A user identifies a new-document need, required change, error, regulatory change, periodic-review action, or withdrawal need. |
| Actor | Requester; Document Controller. |
| Preconditions | Requester is authenticated; request categories and ownership rules exist. |
| Inputs | Request type, justification, affected process, urgency, document or proposed title, owner, impacted audience, requested effective date. |
| Process | Requester submits; system assigns request ID; Document Control checks completeness and duplicates; triage accepts, returns, rejects, or escalates; accepted request creates/links a Document Register entry. |
| Decisions | Duplicate? Emergency route? Correct owner? New document, revision, or withdrawal? |
| Data affected | Change Request, Document Register, relationship to prior document. |
| Output | Authorised work item, assigned owner, due date, template/content type, and audit entry. |
| Exceptions | Missing owner, duplicate request, urgent safety issue, withdrawn request. |
| Completion | Request has a final triage decision and, if accepted, an assigned controlled-document work item. |
| Audit/reporting | Requester, timestamps, decision, rationale, assigned controller, ageing, and outcome. |

### WF-02: Author, review, and approve

| Element | Definition |
|---|---|
| Trigger | Accepted request or periodic-review decision requires authoring. |
| Actor | Author, reviewer, approver, Document Controller. |
| Preconditions | Controlled content type/template exists; author and approval route assigned; draft is not locked as a regulatory record. |
| Inputs | Draft document, metadata, change summary, reviewer/approver route, proposed effective date. |
| Process | Author creates or revises draft; optional check-out protects exclusive editing; author checks in with comment; submission validates metadata; system records version and ETag; reviewers act; approver acts; decisions persist in Approval Evidence. |
| Decisions | Metadata complete? Content changed during approval? Review approved? Final approval approved? |
| Data affected | Controlled Document, Document Revision, Approval Decision, Document Register. |
| Output | Rejected draft or Approved Pending Effective revision. |
| Exceptions | Stale check-out, missing approver, changed ETag, timeout, connector failure, approver departure. |
| Completion | Rejected item is returned with rationale, or approved item is frozen for activation with complete evidence. |
| Audit/reporting | Version, ETag, actors, timestamps, outcomes, comments, cycle time, resubmissions. |

### WF-03: Activate and publish an approved revision

| Element | Definition |
|---|---|
| Trigger | Effective date/time is reached for an Approved Pending Effective revision. |
| Actor | Scheduled automation; Document Controller for exceptions. |
| Preconditions | Approval remains valid; metadata complete; no unresolved blocking exception; previous current revision identified. |
| Inputs | Approved revision, effective date, current revision, audience, retention/classification settings. |
| Process | Scheduled job revalidates approved version; publishes major version or copies approved artefact according to selected architecture; marks new revision Effective; marks prior revision Superseded; updates register and portal; sends link-based notification. |
| Decisions | Same approved version? Previous revision exists? Training required? Publication failed? |
| Data affected | Document Revision, Document Register, prior revision, acknowledgement assignments, exception log. |
| Output | One current effective revision and a retained superseded relationship. |
| Exceptions | Version mismatch, duplicate effective revision, label failure, search delay, notification failure. |
| Completion | Current view resolves to exactly one effective revision and control reconciliation passes. |
| Audit/reporting | Activation actor, timestamps, old/new revision, notifications, validation result, exceptions. |

### WF-04: Periodic review, revision, or withdrawal

| Element | Definition |
|---|---|
| Trigger | Review-warning window opens or owner initiates an early review. |
| Actor | Document owner, reviewer, Document Controller. |
| Preconditions | Effective document has owner, review frequency, and next-review date. |
| Inputs | Current revision, usage/change context, incidents, regulatory or process changes. |
| Process | System notifies owner; owner confirms continued validity, requests revision, or requests withdrawal; required review/approval occurs; next date is calculated only after valid decision. |
| Decisions | Still valid? Change required? Withdraw? Owner unresponsive? |
| Data affected | Review Decision, Change Request, Controlled Document, escalation record. |
| Output | Renewed review date, revision workflow, or approved withdrawal. |
| Exceptions | Owner departed, no response, emergency suspension, legal hold. |
| Completion | Review decision is recorded and no effective document remains ownerless or indefinitely overdue without escalation. |
| Audit/reporting | Due date, reminder/escalation history, decision, actor, next date, overdue days. |

### WF-05: Operational record capture and disposition

| Element | Definition |
|---|---|
| Trigger | A business activity produces completed evidence, or a controlled form is completed. |
| Actor | Business user, Records Manager, system automation. |
| Preconditions | Record class, required metadata, owner, retention trigger, and label mapping are approved. |
| Inputs | Completed record, related process/document, event date, classification, record class. |
| Process | Record is captured; metadata validated; approved label applied; access restricted as required; at end of retention, authorised disposition review or automatic rule executes. |
| Decisions | Complete and authentic? Record or working material? Legal hold? Disposition action? |
| Data affected | Operational Record, Retention Class, Disposition Decision, audit evidence. |
| Output | Retained record or evidenced disposition. |
| Exceptions | Missing trigger date, label failure, litigation/eDiscovery hold, incorrect classification. |
| Completion | Record is retained for the approved period or disposed through the approved path with evidence. |
| Audit/reporting | Capture, label, lock/unlock, hold, review, disposal, and proof-of-disposition events. |

### WF-06: Exception and stale-check-out management

| Element | Definition |
|---|---|
| Trigger | Workflow failure, invalid state, stale check-out, metadata mismatch, permission exception, or reconciliation failure. |
| Actor | Automation, Document Controller, platform support, security as applicable. |
| Preconditions | Exception categories, severity, owner, and escalation thresholds exist. |
| Inputs | Correlation ID, document/request ID, error, state, retry count, timestamp, affected user. |
| Process | Log exception; notify owner; apply safe retry where idempotent; prevent publication when integrity is uncertain; escalate aged/high-severity issues; record resolution. |
| Decisions | Retry safe? Content integrity affected? Security incident? Manual intervention required? |
| Data affected | Exception Register, workflow state, incident/ticket reference. |
| Output | Resolved and evidenced exception or formal escalation. |
| Exceptions | Automation cannot write exception; service outage; owner unavailable. |
| Completion | State is reconciled and resolution evidence exists; unresolved issues remain visible. |
| Audit/reporting | Severity, age, retry, owner, resolution, recurrence, linked incident. |

### WF-07: Administration and controlled change

| Element | Definition |
|---|---|
| Trigger | Approved product change, schema change, licence change, defect fix, or Microsoft service change. |
| Actor | Product Owner, platform administrator, engineer, QA, control owners. |
| Preconditions | Change ticket, source-controlled artefact, test environment, rollback plan. |
| Inputs | Requirement, configuration/script/solution change, test evidence, release notes. |
| Process | Develop in Dev; peer review; deploy to Test; execute regression/security tests; obtain release approval; deploy managed artefact to Production; validate; monitor. |
| Decisions | Backward compatible? Data migration required? Rollback safe? Control owner approval required? |
| Data affected | Configuration baseline, solution version, deployment log, documentation. |
| Output | Approved production release or rollback. |
| Exceptions | Microsoft platform change, failed deployment, environment drift, expired connection. |
| Completion | Production matches approved baseline and post-deployment validation passes. |
| Audit/reporting | Commit/release, approver, deployment actor, timestamps, test results, rollback. |

### WF-08: Management reporting and continuous improvement

| Element | Definition |
|---|---|
| Trigger | Scheduled refresh, management review, audit, or threshold breach. |
| Actor | Product Owner, Document Control, Records Manager, manager, auditor. |
| Preconditions | Metric definitions and data ownership approved. |
| Inputs | Registers, SharePoint metadata, workflow events, audit data, adoption data. |
| Process | Refresh measures; validate quality; apply role-based views; flag threshold breaches; assign corrective action; trend outcomes. |
| Decisions | Threshold exceeded? Data complete? Corrective action required? Product change required? |
| Data affected | Metric snapshots, corrective-action links, management-review evidence. |
| Output | Operational dashboard, compliance report, export, and action record. |
| Exceptions | Stale refresh, incomplete source, privacy restriction, metric-definition change. |
| Completion | Report is current, traceable, and reviewed by the responsible role. |
| Audit/reporting | Refresh time, source status, viewer access where required, actions and closure. |

## 15. Functional Requirements

### 15.1 Source and priority legend

- **CD:** CONOPS-Derived Requirement.
- **RB:** Research-Based Requirement.
- **INF:** Inferred Requirement necessary to operate or control the CONOPS.
- **SA:** Stakeholder Assumption requiring validation.
- **P0 / Must Have:** Required for MVP or mission-critical operation.
- **P1 / Should Have:** Important fast-follow capability; MVP can operate without it.
- **P2 / Could Have:** Future enhancement to preserve in architecture.
- **P3 / Won't Have Initially:** Explicitly deferred.

Every P0 is required because removing it would break one of five core outcomes: authoritative current-document use, attributable approval, lifecycle control, records treatment, or supportable operation.

### 15.2 Information architecture and document control

| ID | Requirement and description | Role | Priority / source | Acceptance criteria | Dependencies / workflow / notes |
|---|---|---|---|---|---|
| F-001 | **The system shall provide centrally governed content types and site columns for Controlled Document, Operational Record, External Document, and supporting registers.** This is P0 because workflow, search, reporting, and retention cannot operate consistently without a shared schema. | Information Architect; Document Control | P0 / CD, RB | Content types are published from the approved gallery; pilot libraries consume the approved versions; unauthorised local schema changes are detected; required fields appear for each type. | Content Type Gallery, Term Store; all workflows. |
| F-002 | **The system shall assign or validate a unique, persistent Document ID and prevent duplicate active IDs.** | Document Controller | P0 / CD, INF | An accepted request receives an ID; moving or renaming does not change it; duplicate activation is blocked; search by exact ID returns the authorised item. | ID convention decision; WF-01, WF-03. |
| F-003 | **The system shall create controlled documents from approved, content-type-specific templates and distinguish blank controlled forms from completed operational records.** | Author; Document Controller | P0 / CD, RB | New SOP uses the approved SOP template; template version is identifiable; a completed form is captured under an Operational Record type and does not overwrite the blank template. | Templates library; WF-02, WF-05. |
| F-004 | **The system shall configure major/minor versioning, draft visibility, content approval, and check-out by library according to the approved operating mode.** | Platform Admin; Document Control | P0 / CD, RB | Controlled authoring retains draft and major versions; readers cannot see drafts; forced check-out is enabled only where exclusive editing is approved; co-authoring test passes where check-out is off. | Library configuration baseline; WF-02. |
| F-005 | **The system shall maintain a business Lifecycle Status separately from native SharePoint Approval Status and restrict direct user changes to controlled states.** | All lifecycle roles | P0 / CD, INF | Only authorised workflow/controller actions can set Approved Pending Effective, Effective, Superseded, Withdrawn, or Obsolete; invalid transitions are rejected and logged. | State model; WF-02 to WF-04. |
| F-006 | **The system shall support check-out, check-in comments, discard, and authorised override for libraries using exclusive editing.** | Author; Document Controller | P0 / CD | Author can check out and check in; version/comment is recorded; another author cannot edit while checked out; controller override requires reason and generates evidence. | SharePoint permissions; WF-02, WF-06. |

### 15.3 Request, review, approval, and publication

| ID | Requirement and description | Role | Priority / source | Acceptance criteria | Dependencies / workflow / notes |
|---|---|---|---|---|---|
| F-007 | **The system shall capture new-document, revision, withdrawal, and emergency-change requests with required justification, owner, process, impact, and requested date.** | Requester; Document Controller | P0 / CD | Required fields are validated; request ID and timestamp are assigned; duplicate or incomplete requests can be returned; triage decision and rationale are retained. | Change Request list; WF-01. |
| F-008 | **The system shall validate mandatory metadata and capture the submitted file version and ETag before initiating review.** | Author; Automation | P0 / CD, RB | Incomplete submissions are blocked with field-level guidance; submitted version and ETag are stored; a later content change causes approval invalidation or restart rather than silent approval. | SharePoint connector; WF-02. |
| F-009 | **The system shall route version-specific serial or parallel review and approval tasks according to configurable document type, process, risk, and authority rules.** | Reviewer; Approver | P0 / CD | Route resolves to authorised people/groups; tasks show document link, ID, revision, change summary, due date, and requested action; missing route produces a blocking exception. | Routing matrix, Entra groups; WF-02. |
| F-010 | **The system shall retain each review and approval decision as durable, attributable evidence.** | Auditor; Document Control | P0 / CD, RB | Evidence includes correlation ID, document ID, file version, ETag, actor, role/stage, outcome, timestamp, and comments; ordinary users cannot alter completed evidence; evidence survives flow-history expiry. | Approval Evidence list and retention; WF-02. |
| F-011 | **The system shall return rejected content to Authoring with mandatory rationale and retain the rejected decision without publishing the revision.** | Reviewer; Approver; Author | P0 / CD | Rejection changes business state to Rework/Authoring; current effective version remains visible; author sees comments; resubmission creates a new approval instance tied to the new version. | WF-02. |
| F-012 | **The system shall support an Approved Pending Effective state and activate only the approved revision at or after the authorised effective date.** | Approver; Document Controller | P0 / CD, INF | Approval does not prematurely replace current content; scheduled activator finds due items; version/ETag is revalidated; activation is idempotent; failed activation creates an exception. | Scheduled flow; WF-03. |
| F-013 | **The system shall ensure that each controlled document has no more than one current effective revision within an applicability context.** | Reader; Document Controller | P0 / CD | Activation atomically or safely sequences new Effective and prior Superseded states; reconciliation flags zero or multiple current revisions; current view returns exactly one. | Architecture pattern decision; WF-03. |
| F-014 | **The system shall record the supersedes/superseded-by relationship and prevent superseded or withdrawn content from appearing in default current-document views.** | Reader; Auditor | P0 / CD | Reader search/view excludes superseded content by default; authorised history view shows relationship and dates; direct obsolete link displays clear status and current-document link where available. | Search design; WF-03, WF-04. |
| F-015 | **The system shall calculate review dates from approved review-frequency rules, notify owners before due date, and escalate overdue items.** | Document Owner; Document Controller | P0 / CD, RB | Review date is calculated from configured rule; reminders occur at approved intervals; overdue status is visible; owner departure or non-response escalates; date cannot roll forward without a recorded decision. | Recurring flow, ownership data; WF-04. |
| F-016 | **The system shall support continue-valid, revise, withdraw, and emergency-suspend review outcomes.** | Document Owner; Approver | P0 / CD, INF | Each outcome has an authorised route; continue-valid records evidence and next date; revise creates a linked request; withdrawal/suspension removes normal current access only after authorised action. | WF-04. |
| F-017 | **The system shall distribute publication and assignment notifications as links to authoritative content rather than file attachments.** | Reader; Manager | P0 / CD | Notification contains ID, title, revision, effective date, applicability, action, due date, and link; no workflow email attaches the controlled file by default; notification failure does not reverse publication but creates an exception. | Exchange/Teams; WF-03. |

### 15.4 Records, retention, audit, and exceptions

| ID | Requirement and description | Role | Priority / source | Acceptance criteria | Dependencies / workflow / notes |
|---|---|---|---|---|---|
| F-018 | **The system shall map every MVP controlled-document and operational-record class to an approved retention policy or label before production use.** | Records Manager | P0 / CD, RB | Mapping register identifies class, trigger, period, action, record status, and authority; unmapped classes cannot enter production record capture; sampled items show expected label. | Approved file plan and licensing; WF-05. |
| F-019 | **The system shall restrict record locking, unlocking, label removal, and regulatory-record use to authorised roles and approved procedures.** | Records Manager; Legal | P0 / RB | Ordinary contributors cannot change protected state; unlock records reason and actor; regulatory-record configuration is absent in MVP unless separately approved; checked-out-file conflict is tested. | Purview role groups; WF-05. |
| F-020 | **The system shall support disposition through the approved automatic or reviewer-authorised path and preserve required evidence.** | Records Manager | P0 / CD, RB | Due items enter expected path; legal/eDiscovery hold prevents disposal; reviewer outcome is recorded; disposal evidence is exportable; no user-interface delete substitutes for disposition. | Purview Records Management; WF-05. |
| F-021 | **The system shall capture and expose auditable lifecycle events, including request, check-out/in, submit, review, approve/reject, activate, supersede, withdraw, label, lock/unlock, access administration, exception, and disposition.** | Auditor; Support | P0 / CD, RB | Defined events can be reconstructed for a sampled document; event timestamps and actor are available; evidence source and retention period are documented; gaps are reported. | Purview Audit plus registers; all workflows. |
| F-022 | **The system shall create a governed Exception Register and prevent unsafe automatic publication when state or version integrity is uncertain.** | Document Control; Support | P0 / INF | Failure creates correlation ID, severity, owner, error, state, and retry count; safe retries do not duplicate effects; blocking exceptions keep content non-effective; closure reason is required. | Monitoring; WF-06. |
| F-023 | **The system shall detect checked-out documents beyond a configurable threshold and notify, escalate, or permit controlled override.** | Author; Document Controller | P0 / CD | Daily/approved schedule identifies stale check-outs; owner receives reminder; controller sees ageing; override captures justification; no automatic discard of content occurs without approved rule. | WF-06. |

### 15.5 Access, search, reporting, and administration

| ID | Requirement and description | Role | Priority / source | Acceptance criteria | Dependencies / workflow / notes |
|---|---|---|---|---|---|
| F-024 | **The system shall enforce role-based access through approved Microsoft Entra groups and maintain separation between content approval, records disposition, and platform administration.** | Security; Admin | P0 / CD, RB | Role-permission matrix is approved; test users receive only expected access; administrator cannot approve content solely due to platform role; direct user permissions are reported as exceptions. | Entra ID; all workflows. |
| F-025 | **The system shall disable external sharing on MVP controlled sites unless Security, Privacy, Legal, and the information owner approve a defined exception.** | Security; Site Owner | P0 / CD, RB | Anonymous/guest sharing tests fail by default; approved exception has group, expiry, sponsor, content scope, and audit; sharing changes are monitored. | Tenant/site sharing controls; all workflows. |
| F-026 | **The system shall provide current-document browsing, exact-ID search, keyword search, metadata filtering, and an authorised history view.** | Reader; Auditor | P0 / CD, RB | Representative task set meets OBJ-01; search results show title, ID, revision, status, owner, effective date, and applicability; default view excludes non-effective content. | Search schema/indexed columns; WF-03, WF-08. |
| F-027 | **The system shall provide role-appropriate dashboards and exportable operational reports.** | Manager; Controller; Records Manager | P0 / CD | Reports in section 20 are available; data timestamp and metric definition are displayed; users see only permitted underlying content; CSV export reconciles to source. | Lists/Power BI; WF-08. |
| F-028 | **The system shall maintain configurable routing, review-frequency, document-type, and escalation rules without editing flow logic for ordinary rule changes.** | Product Owner; Document Control | P1 / INF | Authorised admin can change a rule in configuration; change is audited; validation prevents invalid people/groups or intervals; next run uses approved value. | Configuration lists; WF-07. |
| F-029 | **The system shall capture acknowledgement assignments and responses for documents requiring read-and-understand evidence.** | Reader; Manager | P1 / CD | Audience, due date, document revision, assignment, response, timestamp, and overdue state are retained; revised document creates new assignment when required; system labels this acknowledgement, not competence certification. | Audience source; WF-03. |
| F-030 | **The system shall support Document Sets for approved case-file or multi-document work products.** | Business Process Owner | P1 / CD, RB | Document Set inherits approved shared metadata; permitted document types are constrained; case can be closed and retained as designed; volume/view tests pass. | Information architecture; future workflow. |
| F-031 | **The system shall generate a controlled PDF rendition when an approved process requires a fixed-format copy.** | Document Controller | P1 / CD | PDF identifies document ID, revision, effective date, and controlled/uncontrolled status; source and rendition are linked; conversion failure blocks required rendition publication. | Word/PDF service or document processing; WF-03. |
| F-032 | **The system shall surface tasks and notifications in Teams where approved without making Teams the authoritative repository.** | Reviewer; Reader | P1 / CD | Teams item links to SharePoint source; permissions are rechecked on access; deletion of message does not delete evidence; no duplicate authoritative file is created. | Teams/Approvals; WF-02, WF-03. |
| F-033 | **The system shall provide a Power App intake and Document Control work queue if native list forms do not meet validated usability needs.** | Requester; Document Controller | P1 / INF | App exposes only role-relevant actions; validation matches source lists; accessibility and performance tests pass; native fallback remains documented. | Power Apps licensing; WF-01, WF-06. |
| F-034 | **The system may use document processing to classify content or extract metadata after accuracy and cost thresholds are approved.** | Records Manager; Controller | P2 / RB | Model has labelled test set; confidence threshold and human-review path exist; false positives/negatives are measured; usage cost is monitored; no automatic regulatory-record action occurs. | Pay-as-you-go service; future. |
| F-035 | **The system may generate routine documents from controlled templates and approved business data.** | Business User | P2 / RB | Data-to-field mapping is approved; generated output identifies template/version; validation handles missing data; generated record follows the correct lifecycle. | Content assembly; future. |
| F-036 | **The system may integrate an approved electronic-signature service where legal analysis defines signature identity, intent, consent, integrity, and evidence requirements.** | Legal; Approver | P2 / INF | Signed artefact and evidence package are retained; signer identity and intent are verified; failure and cancellation paths work; jurisdictional assessment is approved. | Legal decision and service procurement; future. |
| F-037 | **The system shall not implement enterprise-wide migration until the pilot migration and reconciliation are accepted.** | Product Owner | P3 / CD | Enterprise migration plan remains gated; pilot import preserves approved metadata and evidence; counts and samples reconcile before source repository is retired. | Migration inventory; WF-07. |

## 16. Non-Functional Requirements

Thresholds marked **proposed** require confirmation after volume and user baselines are known.

| ID | Quality | Requirement | Acceptance criteria / threshold | Source / notes |
|---|---|---|---|---|
| NFR-001 | Performance | Key DMS landing, current-document, work-queue, and document-register views shall load within 5 seconds at the 95th percentile under the agreed pilot load, excluding a declared Microsoft 365 service incident. | Synthetic and user tests over five business days; custom components shall not add more than 1 second median overhead. | SA; proposed. |
| NFR-002 | Workflow responsiveness | Interactive submission shall acknowledge receipt within 10 seconds; task notification shall begin within 5 minutes for 95% of events. | Timestamp comparison; degraded Microsoft service is separately reported. | SA; proposed. |
| NFR-003 | Availability | The solution shall not introduce a single custom component whose failure makes current effective documents unreadable. | During flow outage, readers retain current-document access; documented manual activation fallback exists; availability inherits contracted Microsoft service terms. | INF. |
| NFR-004 | Scalability | MVP shall support 50,000 documents and 1,000 eligible users without redesign; enterprise design shall use indexed views and avoid per-item permissions as the default. | Load/view tests pass; no operational view depends on an unindexed high-cardinality query; volume assumptions documented. | RB, SA; [SharePoint limits](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits). |
| NFR-005 | Reliability | At least 99% of production lifecycle runs shall complete without manual repair after stabilisation. | Monthly numerator is successful terminal runs; denominator excludes approved tests and cancelled requests; duplicate side effects equal zero. | OBJ-06. |
| NFR-006 | Resilience | All automated actions that create, publish, supersede, label, notify, or log evidence shall be idempotent or protected by a unique correlation/state check. | Replaying each critical flow does not create duplicate effective revisions, decisions, or assignments. | INF. |
| NFR-007 | Security | Authentication shall use Microsoft Entra ID and tenant-approved MFA/Conditional Access; authorisation shall use least-privilege roles. | Unauthenticated access denied; role test matrix passes; privileged assignments reviewed at approved frequency. | RB; NIST least privilege principle. |
| NFR-008 | Usability | Representative readers shall complete the defined find-current-document task with at least 90% success within 60 seconds. | Moderated test with at least 10 representative pilot users and no facilitator assistance. | OBJ-01. |
| NFR-009 | Accessibility | Custom pages, forms, Power Apps, view formatting, and help content shall meet WCAG 2.2 AA to the extent applicable. | Automated scan plus keyboard, focus, screen-reader, zoom/reflow, contrast, error, and accessible-name manual tests; no unresolved critical barrier. | RB; [WCAG 2.2](https://www.w3.org/TR/WCAG22/). |
| NFR-010 | Maintainability | Apps and flows shall be solution-aware, use environment variables and connection references, and deploy through Dev/Test/Prod without direct production editing. | Managed release imports successfully; configuration contains no hard-coded production URL; rollback/redeploy is demonstrated. | RB; Power Platform ALM. |
| NFR-011 | Data integrity | Approval, activation, and supersession shall operate on the intended version and reject version/ETag conflicts. | Concurrency and change-during-approval tests pass; audit evidence identifies exact reviewed and activated revision. | RB. |
| NFR-012 | Auditability | Product evidence shall support reconstruction of the controlled-document lifecycle for the longer of the document's approved evidence period or applicable audit policy. | Auditor traces a sample without email reconstruction; evidence-retention mapping is approved; native audit limitations are documented. | CD, RB. |
| NFR-013 | Backup and recovery | The product shall meet an approved RPO and RTO; until approved, the MVP planning assumption is 24-hour RPO and 8-business-hour RTO. | Restore exercise recovers a representative site/configuration and reconciles sampled content, metadata, permissions, and evidence. | SA; open question OQ-06. |
| NFR-014 | Observability | Critical flows, scheduled jobs, connection health, aged exceptions, and reconciliation failures shall be monitored with actionable ownership. | Deliberate failure generates alert and Exception Register item within 15 minutes; dashboard shows age and owner. | INF; proposed. |
| NFR-015 | Interoperability | Supported integrations shall use Microsoft-supported connectors/APIs and documented authentication; custom interfaces shall handle throttling and retry guidance. | Integration contract and error handling are tested; retry does not duplicate actions; unsupported legacy workflow is absent. | RB; [Power Automate limits guidance](https://learn.microsoft.com/en-us/power-automate/guidance/coding-guidelines/understand-limits). |
| NFR-016 | Privacy | Personal information in metadata, logs, acknowledgements, and records shall be limited to approved purpose and retention. | Privacy field inventory, lawful-purpose/notice decision, access test, and deletion/retention test are approved where privacy law applies. | RB; ICO principles. |
| NFR-017 | Search freshness | Newly effective documents shall be directly available immediately through authoritative links and discoverable through indexed search within 60 minutes for 95% of pilot activations. | Activation/search timestamps measured; delayed indexing is visible as non-blocking exception; portal current view has direct metadata-based fallback. | SA; proposed due to SaaS indexing variability. |
| NFR-018 | Portability | Registers, metadata, configuration, and evidence shall be exportable in documented, non-proprietary or Microsoft-supported formats. | Admin exports CSV/JSON and controlled files; schema and relationships are documented; sampled export reconciles. | INF. |
| NFR-019 | Configuration management | Production configuration shall be compared to an approved baseline after each release and at least monthly. | Automated or scripted validation reports drift in libraries, fields, content types, views, permissions, flows, and labels; deviations have tickets. | CD. |
| NFR-020 | Compatibility | The product shall support organisation-approved current Microsoft Edge and Microsoft 365 desktop/web clients; mobile scope shall be explicitly tested or excluded. | Supported-client matrix approved; core workflows pass in each supported client; unsupported behaviour is documented. | SA. |

## 17. Data Requirements

### 17.1 Conceptual data model

```text
Change Request ──creates/revises/withdraws──> Controlled Document
                                                  │
                                                  ├──has──> Document Revision
                                                  │          ├──has──> Approval Decision
                                                  │          └──may assign──> Acknowledgement
                                                  │
                                                  ├──classified by──> Taxonomy / Sensitivity
                                                  ├──governed by──> Retention Class
                                                  └──related to──> Operational Record

Workflow Run ──may create──> Exception
Disposition Decision ──acts on──> Operational Record / retained revision
Migration Batch ──contains──> Migration Evidence ──validates──> migrated entity
```

### 17.2 Major entities

| ID | Entity | Purpose and key fields | Source / owner | Sensitivity | Lifecycle and retention |
|---|---|---|---|---|---|
| DATA-001 | Controlled Document | Document ID, title, type, function, process, owner, author, classification, applicability, lifecycle status, current revision, review frequency/date, training flag, retention class. | SharePoint / Document Control | Internal to Confidential depending content | Exists while governed; deletion only through approved lifecycle. |
| DATA-002 | Document Revision | Document ID, SharePoint version, business revision, file, change summary, approval state, effective date, supersedes/by, template version, content hash if required. | SharePoint / Document Owner and Control | Inherits document classification | Draft versions per version policy; approved/superseded treatment per file plan. |
| DATA-003 | Change Request | Request ID/type, requester, justification, urgency, affected process/document, impact, triage outcome, owner, due dates. | List/Power App / Document Control | Internal; may include sensitive rationale | Retain according to quality/change-control schedule. |
| DATA-004 | Approval Decision | Correlation ID, document ID, version, ETag, stage, actor, outcome, timestamp, comments, delegation, task ID. | Power Automate/List / Document Control | Internal; comments may be sensitive | Durable evidence; period set by file plan, not flow history. |
| DATA-005 | Document Register | Master index, identifiers, state, owners, dates, current link, historical link, label and completeness indicators. | List or derived view / Document Control | Internal | Maintained for governed lifetime; historical entries retained as approved. |
| DATA-006 | Operational Record | Record ID, class, event date, creator, process, related document/case, classification, retention trigger, label, lock state, file. | SharePoint/business process / Business owner and Records Manager | Variable; may include personal, financial, or operationally sensitive information | Retained and disposed according to approved record class. |
| DATA-007 | Retention Class | Class name, authority, trigger, period, action, record status, reviewer, legal notes, effective date/version. | Purview/file-plan register / Records Manager | Internal governance | Controlled configuration retained with change history. |
| DATA-008 | Acknowledgement | Assignment ID, user/group, document ID/revision, assigned/due/responded dates, response, reminder/escalation. | List/Power App / Process owner | Personal information | Retain only as long as approved evidence requirement. |
| DATA-009 | Exception | Correlation ID, type, severity, source, affected item, error, owner, retry, timestamps, resolution, incident/ticket link. | Automation/List / Product Owner | Internal; may contain technical identifiers | Retain per operational support policy; redact secrets. |
| DATA-010 | Identity and Role Mapping | Entra object IDs, group names, role, scope, owner, review date. | Entra/config register / Security | Personal/administrative | Current plus approved access-review evidence. |
| DATA-011 | Disposition Decision | Item/record ID, class, reviewer, outcome, rationale, action date, proof/reference, hold state. | Purview / Records Manager | Internal/Legal | Retain proof for approved period; Microsoft provides proof capabilities for records. |
| DATA-012 | Migration Evidence | Batch ID, source path/ID, target ID, size, dates, checksum where required, metadata mapping, result, exception. | Migration tooling / Migration lead | Mirrors source sensitivity | Retain through migration acceptance and audit period. |

### 17.3 Validation rules

- Document ID shall be unique within the approved namespace.
- Effective requires approved revision, approval evidence, owner, effective date, next-review date, applicability, classification, and retention mapping.
- Superseded requires superseded-by reference unless withdrawal has no replacement.
- Approval evidence shall reference an immutable decision instance and exact file version/ETag.
- Person fields shall resolve to active Entra identities or approved groups; owner departure shall generate an exception.
- Choice and taxonomy fields shall use active controlled terms; deprecated terms remain resolvable for history.
- Retention trigger dates shall not precede the logical event unless approved as migrated historical data.
- Completed records shall not be stored as attachments to ordinary list items when the attachment would evade the intended retention treatment.
- Secrets, access tokens, and connection credentials shall never be written to operational logs or exception descriptions.
- Date/time evidence shall use an agreed tenant standard and preserve UTC for system events; user displays may localise.

### 17.4 Data ownership and quality

- Document owners are accountable for content accuracy and continued need.
- Document Control owns lifecycle metadata quality and identifier integrity.
- Records Management owns retention-class definitions and disposition rules.
- Security/Privacy own classification and personal-data control rules.
- Platform Support owns technical logs, configuration, and integration health.
- Product Owner owns metric definitions and data-quality remediation.

## 18. Security, Privacy, and Compliance Requirements

This section defines controls and evidence expectations. It does not claim certification or legal compliance.

| ID | Requirement | Acceptance evidence |
|---|---|---|
| SEC-001 | Authentication shall use Microsoft Entra ID; tenant-approved MFA and Conditional Access shall apply according to user, device, location, and sensitivity policy. | Authentication/Conditional Access design and tested user scenarios. |
| SEC-002 | Authorisation shall use an approved role-permission matrix and Entra groups; direct user permissions and item-level unique permissions shall be exceptions. | Permission export, role tests, and exception report. |
| SEC-003 | Least privilege and separation of duties shall distinguish Reader, Author, Reviewer, Approver, Document Controller, Records Manager, and Platform Administrator. | Positive and negative access tests; privileged-role review. |
| SEC-004 | Production automation shall use approved connection ownership, least privilege, and at least two administrative co-owners; credentials shall not be embedded in code or configuration files. | Connection inventory, secret scan, ownership test, offboarding test. |
| SEC-005 | External sharing shall be disabled for MVP controlled sites unless an approved exception defines sponsor, group, content, duration, and review. | Tenant/site setting, guest tests, sharing audit. |
| SEC-006 | Sensitivity labels and DLP shall be applied where the information-classification assessment requires them; encrypted-file behaviour in SharePoint and Office shall be tested. | Label/DLP policy, file-type tests, sharing/download tests. |
| SEC-007 | Data shall use Microsoft 365 platform encryption in transit and at rest; any custom integration shall use supported TLS and approved secret storage. | Microsoft service assurance reference; integration configuration evidence. |
| SEC-008 | A data inventory shall identify personal, financial, commercially sensitive, legally privileged, export-controlled, classified, or other regulated information before migration. | Approved data-classification and privacy inventory. |
| SEC-009 | Where UK GDPR or another privacy law applies, metadata and workflow fields shall be purpose-limited and minimised, and retention shall reflect approved need. | Privacy assessment, field justification, notice/lawful-basis decision where required. |
| SEC-010 | Access, approval, administrative, label, sharing, and disposition events shall be logged for the approved period; evidence shall not rely exclusively on short-lived automation history. | Audit policy, event sample, Approval Evidence retention mapping. |
| SEC-011 | Privileged administrative actions shall use named accounts, approved roles, and periodic review; emergency access shall be logged and reviewed. | Admin-role export, access review, emergency-access test. |
| SEC-012 | Record-lock, unlock, regulatory-record, Preservation Lock, and disposition configuration shall require Records Management and Legal approval because some actions are difficult or impossible to reverse. | Signed decision record, non-production test, runbook, role restriction. |
| SEC-013 | Security incidents involving the DMS shall follow the organisational incident-response process and preserve relevant evidence. | Incident integration, severity mapping, tabletop test. |
| SEC-014 | Custom components and scripts shall undergo peer review, dependency/vulnerability scanning where applicable, and secure release control. | Pull request, scan results, test and release evidence. |
| SEC-015 | Backup and restore access shall be restricted, logged, and tested without bypassing retention, privacy, or legal-hold obligations. | Recovery role matrix, restore test, data-handling record. |

### 18.1 Framework alignment

| Framework or authority | Applicable principle | Product alignment | Qualification |
|---|---|---|---|
| ISO 15489-1:2016 | Records, metadata, responsibilities, controls, monitoring, and training. | Content model, roles, file plan, lifecycle evidence, monitoring, operating procedures. | Alignment target only; certification is not claimed. |
| ISO 9001:2015 clause 7.5 guidance | Maintain information needed to operate processes and retain evidence that work occurred. | Separates controlled instructions/templates from completed records; controls availability and revision. | Applicability depends on the organisation's QMS scope. |
| NIST least privilege principle | Authorised access limited to assigned duties and periodically reviewed. | Entra groups, role separation, admin review, exception reporting. | Control baseline, not a federal compliance claim. |
| WCAG 2.2 AA | Perceivable, operable, understandable, and robust web content. | Custom SharePoint, Power Apps, forms, formatting, notifications, and help testing. | Native Microsoft component conformance remains Microsoft's responsibility; customisation remains product responsibility. |
| UK GDPR / ICO principles | Minimisation, storage limitation, integrity/confidentiality, accountability. | Privacy inventory, least access, retention mapping, logging, privacy assessment. | Applies only where processing and jurisdiction bring data into scope; legal determination required. |

### 18.2 Trust assumptions

- Microsoft operates the underlying Microsoft 365 SaaS platform and publishes service-assurance evidence.
- The organisation controls tenant configuration, identities, access groups, information architecture, workflows, retention choices, connectors, and user behaviour.
- Users with authorised download rights can create offline copies; sensitivity labels, block-download controls, training, and monitoring reduce but may not eliminate this risk.
- A workflow approval is an attributable business decision but is not automatically a legally qualified electronic signature.
- Microsoft search and Copilot respect permissions, but incorrect permissions can expose content through multiple discovery experiences.

## 19. Integration Requirements

| ID | System | Purpose and data exchanged | Direction / frequency / authentication | Error handling and security | Acceptance criteria / dependency risk |
|---|---|---|---|---|---|
| INT-001 | Microsoft Entra ID | Users, groups, role membership, account status, object IDs. | Entra to DMS; real time/on access plus scheduled review; OAuth/Microsoft identity. | Disabled owner/member generates exception; least privilege; no local password store. | Role and offboarding tests pass. Risk: group ownership/data quality. |
| INT-002 | SharePoint Online | Documents, versions, metadata, lists, views, search, permissions. | Core bidirectional product operation; Microsoft 365 auth. | ETag/concurrency, throttling retry, safe failure. | All P0 lifecycle tests pass. Risk: tenant configuration drift and service limits. |
| INT-003 | Microsoft 365 Apps | Word/Excel/PowerPoint authoring and document properties. | User initiated; Microsoft identity; desktop/web. | Unsupported format/client guidance; check-out awareness. | Template, version, metadata, and client tests pass. Risk: inconsistent client versions. |
| INT-004 | Power Automate / Approvals | Triggers, tasks, decisions, status updates, schedules, notifications. | Bidirectional event/scheduled; connection references and approved identity. | Retry, concurrency, ETag, exception logging, no sole personal owner. | Failure/replay/offboarding tests pass. Risk: throttling, licensing, connector change. |
| INT-005 | Exchange Online / Teams | Assignment, reminder, escalation, publication notifications and links. | DMS outbound; user response inbound where designed; Microsoft identity. | Notification failure logged; permissions checked at link open; no authoritative attachments. | Link and response tests pass. Risk: users treat notification as source. |
| INT-006 | Microsoft Purview | Retention labels, record state, disposition, sensitivity, DLP, audit. | Bidirectional configuration/events; Purview roles and Microsoft APIs. | Label conflict and hold handling; irreversible actions gated. | File-plan sample and disposition test pass. Risk: licence and irreversible configuration. |
| INT-007 | Power Apps / Microsoft Lists | Request, work queue, acknowledgement, exception, and configuration data. | Bidirectional; Microsoft identity and SharePoint/Dataverse connector. | Form validation, offline limitation documented, DLP policy. | Role, validation, accessibility, and export tests pass. Risk: premium connector/licence need. |
| INT-008 | Power BI | Aggregated lifecycle, quality, adoption, and exception measures. | DMS to reporting; scheduled refresh; service identity/OAuth. | Row-level access as needed; stale refresh alert; minimise personal data. | Metrics reconcile and refresh timestamp displays. Risk: licence and semantic inconsistency. |
| INT-009 | Backup service | Protected sites/configuration and restore operations. | SharePoint to backup; scheduled/continuous per service; privileged Microsoft identity. | Restore approval, logging, privacy/retention checks. | RPO/RTO restore test passes. Risk: cost and site-level granularity. |
| INT-010 | Source repositories/migration tooling | Files, source IDs, timestamps, owners, metadata, permissions, checksums where required. | Source to DMS in controlled batches; approved app identity. | Quarantine failures, preserve source, reconcile, no destructive cutover before acceptance. | Counts, sizes, metadata, permissions, and sample hashes reconcile. Risk: poor source data. |
| INT-011 | Azure Automation/Functions or line-of-business APIs | Optional complex generation, hashing, reconciliation, or enterprise data. | API/event/scheduled; managed identity or certificate-based OAuth. | Secret management, throttling, dead-letter/exception handling, monitoring. | Contract tests and failure recovery pass before use. Risk: custom-code support burden. |

## 20. Reporting and Analytics Requirements

### 20.1 Required report families

| Report | Audience | Content | Refresh | Visibility |
|---|---|---|---|---|
| Document Control Work Queue | Document Controllers | Requests, submissions, pending stages, activations, stale check-outs, blocking exceptions. | Near real time or at least every 15 minutes | Document Control and support. |
| Current Document Register | Readers and auditors | Current-effective metadata and links; authorised history for auditors. | Near real time | Role based. |
| Review Compliance | Owners, managers, Quality | Due in 30/60/90 days, overdue, ownerless, review decisions and ageing. | Daily | Managers and control roles. |
| Approval Performance | Product Owner, managers | Stage cycle time, queue age, rejection/resubmission, workload. | Daily | Aggregated; detailed role restricted. |
| Control Completeness | Document Control, auditors | Missing metadata, missing approval evidence, multiple/zero effective revision, label mismatch. | Daily and on activation | Control roles. |
| Records and Disposition | Records Manager, Legal | Label coverage, hold conflicts, due disposition, backlog, outcomes, proof. | Daily/weekly depending Purview | Records/Legal only. |
| Access and Sharing Exceptions | Security, Privacy, site owners | Direct permissions, guests, sharing links, ownerless groups, sensitive-site exceptions. | Daily/weekly | Security and authorised owners. |
| Product Operations | Product Owner, support | Flow success, exception age, connection health, release/configuration drift, recovery tests. | Near real time/daily | Product and IT. |
| Adoption and Findability | Sponsor, Product Owner | Eligible active users, search/task success, common failed queries, portal usage. | Weekly/monthly | Aggregated; privacy minimised. |

### 20.2 Metric definitions and targets

| Metric ID | Metric and calculation | Data source | Frequency | Proposed target |
|---|---|---|---|---|
| MET-001 | **Control completeness:** effective documents passing all required metadata and approval-evidence checks / all effective documents. | SharePoint and Approval Evidence | Daily | 100% |
| MET-002 | **Findability success:** representative users completing the current-document task within 60 seconds / users tested. | Usability test | Release and quarterly | At least 90% |
| MET-003 | **Approval cycle time:** median business days from valid submission to final decision; report stage percentiles separately. | Workflow/Approval Evidence | Weekly/monthly | Median at or below 5 business days after stabilisation |
| MET-004 | **Overdue review rate:** effective documents beyond next-review date / effective documents due for review. | Document Register | Daily/monthly | Below 5% |
| MET-005 | **Ownerless effective documents:** count with no active owner. | SharePoint/Entra | Daily | 0 |
| MET-006 | **Workflow success:** terminal successful lifecycle runs / all eligible terminal runs, excluding approved tests/cancellations. | Flow telemetry/Exception Register | Daily/monthly | At least 99% |
| MET-007 | **Aged blocking exceptions:** open blocking exceptions older than one business day. | Exception Register | Daily | 0; any exception older than threshold escalated |
| MET-008 | **Stale check-out rate:** documents checked out beyond approved threshold / checked-out documents. | SharePoint | Daily/weekly | Below 2%; threshold initially 3 business days |
| MET-009 | **Retention mapping coverage:** in-scope classes with approved mapping / all in-scope classes. | File plan/config | Release/monthly | 100% |
| MET-010 | **Retention-label conformance:** sampled records with expected label/state / sampled records. | SharePoint/Purview | Monthly | 100% for MVP sample |
| MET-011 | **Disposition backlog:** due disposition items open more than 30 days / all due items. | Purview | Monthly | Below 10%, subject to legal workload |
| MET-012 | **Acknowledgement completion:** completed by due date / assigned acknowledgements. | Acknowledgement Register | Daily/monthly | At least 95% where used |
| MET-013 | **Pilot adoption:** eligible users with at least one qualifying DMS interaction in 30 days / eligible pilot users. | Usage analytics | Monthly | At least 80% by day 90 |
| MET-014 | **Uncontrolled current-document incidents:** verified cases where a DMS experience presents the wrong revision as current. | Incident/Exception Register | Monthly | 0 Severity 1 or High incidents |
| MET-015 | **Recovery conformance:** latest restore exercise completed within approved RTO with data within approved RPO. | Recovery test evidence | Quarterly/after material change | 100% |

Metric owners shall approve calculation details, exclusions, timezone, business-calendar treatment, privacy treatment, and baseline before the pilot scorecard is used for executive decisions.

## 21. User Experience Requirements

| ID | Requirement |
|---|---|
| UX-001 | The DMS home shall prioritise Find a Current Document, My Tasks, Request a Document/Change, Documents Due for Review, and Help according to role. |
| UX-002 | The default reader experience shall not require knowledge of site, library, folder, or filename structure. |
| UX-003 | Search and list results shall show Document ID, title, revision, lifecycle status, effective date, owner, document type, and applicability. |
| UX-004 | Obsolete, superseded, or withdrawn direct links shall display a prominent status and link to the current replacement where one exists. |
| UX-005 | Author forms shall group fields by business meaning, explain required fields, preserve entered data after validation errors, and avoid asking users for system-derived values. |
| UX-006 | Review and approval tasks shall show the exact version, change summary, prior revision link, due date, stage, and consequences of approval or rejection. |
| UX-007 | Error messages shall state what happened, whether content was saved, what the user can do, and the correlation ID/support route; raw connector errors and secrets shall not be shown. |
| UX-008 | Custom experiences shall conform to NFR-009 accessibility requirements and support keyboard-only use, visible focus, text scaling, screen-reader names, contrast, and understandable validation. |
| UX-009 | Notifications shall be actionable but concise and shall link to the authoritative source; reminders shall be consolidated where practical to reduce fatigue. |
| UX-010 | The system shall provide role-specific onboarding, one-page quick references, glossary, lifecycle diagram, and contextual help. |
| UX-011 | Administrative screens shall expose configuration status and validation without giving business users access to sensitive platform details. |
| UX-012 | Mobile access shall be either tested for the defined read/approve use cases or explicitly marked unsupported for MVP; authoring on mobile is not assumed. |

## 22. Administrative Requirements

| ID | Requirement | Acceptance evidence |
|---|---|---|
| ADM-001 | Product governance shall name the Executive Sponsor, Product Owner, Document Control authority, Records Manager, Security owner, Privacy owner, platform owner, and support tiers. | Approved governance charter and RACI. |
| ADM-002 | The product shall maintain an approved service catalogue entry, support route, severity model, maintenance window, and escalation path. | Published service and support documentation. |
| ADM-003 | Site, library, content-type, taxonomy, retention, security, and workflow changes shall use controlled change management. | Change/release records and approval evidence. |
| ADM-004 | Power Apps and Power Automate components shall be developed in Dev, validated in Test/UAT, and deployed to Production as managed solution artefacts. | Environment inventory, solution package, release log. |
| ADM-005 | Site URLs, list/library identifiers, group IDs, thresholds, and routing values shall use environment variables or governed configuration rather than hard-coded production values. | Configuration scan and deployment test. |
| ADM-006 | SharePoint provisioning and validation shall use approved site scripts, SharePoint Online PowerShell, PnP PowerShell, Microsoft Graph, or equivalent repeatable automation. | Source-controlled scripts, peer review, idempotency/drift report. |
| ADM-007 | PnP PowerShell or other community tooling shall be treated as a managed dependency with version pinning, test coverage, and support ownership rather than assumed Microsoft product support. | Dependency register and upgrade test. |
| ADM-008 | Production flows shall have approved connection ownership, at least two administrative co-owners, documented reauthentication, and an offboarding runbook. | Ownership export and simulated owner departure. |
| ADM-009 | Configuration, application, and procedure documentation shall be versioned and linked to the applicable release. | Documentation register and release sample. |
| ADM-010 | Backup, restore, and business-continuity procedures shall be approved and exercised at the frequency set by the Product Owner and continuity authority. | Successful exercise and corrective-action record. |
| ADM-011 | Monthly service review shall cover metrics, incidents, exceptions, permissions, owner status, licence/capacity, Microsoft roadmap changes, and improvement backlog. | Meeting record, scorecard, actions. |
| ADM-012 | At least annually, or after material regulatory/process change, the file plan, classification, access model, and operating procedures shall be reviewed by accountable owners. | Review evidence and approved updates/no-change decision. |

## 23. Assumptions

| ID | Assumption | Validation owner / method | Impact if false |
|---|---|---|---|
| A-001 | SharePoint Online, not SharePoint Server, is the target platform. | Product Owner and IT confirm tenant architecture. | Product architecture, scripting, and licensing require revision. |
| A-002 | Microsoft Entra ID is the authoritative workforce identity source. | Security/IT confirm identity design. | Additional identity integration and access lifecycle are required. |
| A-003 | The MVP is corporate/ISO-oriented and is not initially subject to validated GxP, Part 11, classified, FedRAMP, or qualified-signature requirements. | Legal, Quality, Security, and business sponsor complete applicability assessment. | Separate validation, evidence, infrastructure, or specialist product may be required. |
| A-004 | The pilot has no more than 50,000 documents, 1,000 eligible users, and 50 concurrent active workflow participants. | Migration and user inventory. | Performance, topology, licences, and test plan must be re-estimated. |
| A-005 | English is the MVP language and the tenant has a single primary operating timezone for due-date display. | Sponsor and HR/operations confirmation. | Localisation, translations, regional calendars, and accessibility testing expand. |
| A-006 | A Document Control authority and Records Manager will be assigned before build completion. | Sponsor names accountable people. | Production launch is blocked because workflow and retention decisions lack owners. |
| A-007 | Native SharePoint/Power Platform capabilities can meet the MVP without SPFx. | Prototype and fit-gap review. | Custom development, security review, ALM, and support scope increase. |
| A-008 | Ordinary readers need current effective documents but not draft access. | Persona interviews and permission workshop. | Search, permissions, and information architecture require alternate segmentation. |
| A-009 | Proposed metric, RPO/RTO, and performance thresholds are acceptable planning hypotheses. | Sponsor and continuity owner approve or revise. | Acceptance plan and potentially architecture/licensing change. |
| A-010 | The organisation will permit links rather than attachments as the normal controlled-document distribution method. | Policy and change-management approval. | Offline-copy risk remains high and adoption targets may not be achievable. |

## 24. Constraints

| ID | Constraint | Product effect |
|---|---|---|
| C-001 | The solution must operate within supported Microsoft 365 capabilities and service limits. | Design shall avoid unsupported classic workflow and excessive unique permissions; service changes require monitoring. |
| C-002 | Licensing is not yet confirmed. | Features that require advanced Purview, Power BI, premium Power Platform, SharePoint Advanced Management, document processing, or Backup remain gated. |
| C-003 | SaaS indexing, connector throttling, service incidents, and product updates are not fully controlled by the product team. | Direct-link fallback, retry, observability, and change monitoring are required. |
| C-004 | Required check-out prevents simultaneous co-authoring. | Check-out shall be a library-level business decision, not a universal DMS setting. |
| C-005 | Regulatory-record and Preservation Lock features can be difficult or impossible to reverse. | They are excluded from MVP unless separately authorised and tested. |
| C-006 | SharePoint permissions follow site/library inheritance patterns, and large numbers of unique scopes are operationally undesirable. | Security boundaries shall usually be sites or libraries rather than individual files. |
| C-007 | Flow run history is not a sufficient long-term audit repository. | Durable evidence lists/records and Purview audit policy are required. |
| C-008 | The system cannot prevent every authorised reader from creating a screenshot, printout, or offline copy. | Policy, labelling, block-download options, watermarking, training, and monitoring provide layered mitigation. |
| C-009 | Source repositories may have missing owners, duplicate files, invalid names, weak metadata, and unknown approval history. | Migration requires quarantine, mapping, reconciliation, and explicit treatment of unknown provenance. |
| C-010 | The DMS is not a substitute for accountable human content review, records authority, legal advice, or competence-based training. | Workflow automates routing and evidence but does not make substantive decisions. |

## 25. Dependencies

| ID | Dependency | Needed for | Owner | Required decision or deliverable |
|---|---|---|---|---|
| D-001 | Executive sponsorship and governance charter | Authority, scope, dispute resolution | Sponsor | Named roles, budget owner, decision rights. |
| D-002 | Microsoft 365 licence inventory and target SKU decision | Purview, Power Apps, Power BI, Backup, SAM, document processing | IT/Procurement | Feature-by-feature licence confirmation. |
| D-003 | Approved records retention schedule/file plan | Labels, record state, disposition | Records/Legal | Class, trigger, period, action, reviewers. |
| D-004 | Information-classification and external-sharing policy | Site topology, permissions, sensitivity, DLP | Security/Privacy/Legal | Classification tiers and handling rules. |
| D-005 | Regulatory and quality applicability assessment | Architecture, validation, signatures, audit | Legal/Quality/Security | Applicable laws, standards, contract clauses, assessment path. |
| D-006 | Identity and group ownership | RBAC, offboarding, approval routing | Entra/HR/IT | Group naming, owners, membership source, review cadence. |
| D-007 | Source-repository inventory and migration authority | Pilot and enterprise migration | Business/Migration lead | Sources, volumes, owners, freeze/cutover, deletion authority. |
| D-008 | Power Platform environment and DLP strategy | Governed apps/flows | Power Platform Admin | Dev/Test/Prod, regions, connectors, service identity. |
| D-009 | Business continuity requirements | Backup and restore architecture | Continuity/IT | RPO, RTO, scope, exercise cadence. |
| D-010 | Pilot business function and representative users | Discovery, testing, adoption | Sponsor/Business owner | Pilot scope, documents, users, time commitment. |
| D-011 | Microsoft service health and roadmap monitoring | Ongoing support | Platform owner | Assigned review and response process. |

### 25.1 Implementation phasing

No contractual deadline was supplied. Dates shall be set after blocking decisions D-002 through D-010. The recommended relative sequence is:

| Phase | Exit outcome | Key dependencies |
|---|---|---|
| Phase 0 — Discover and decide | Approved governance, applicable controls, licence position, file plan, pilot scope, baseline metrics, architecture pattern. | D-001 to D-010 |
| Phase 1 — Configure foundation | Dev/Test environments, content model, security groups, pilot sites/libraries/lists, provisioning baseline. | Phase 0 decisions |
| Phase 2 — Build lifecycle | P0 workflows, portal, evidence, exceptions, reports, operating procedures. | Foundation and connection ownership |
| Phase 3 — Validate and migrate pilot | Security, functional, accessibility, performance, migration, and restore evidence accepted. | Representative source content and users |
| Phase 4 — Controlled pilot | Four-week minimum live operation plus stabilisation; 30/60/90-day metrics. | Training, support, launch approval |
| Phase 5 — Scale decision | Continue, revise, or stop; enterprise topology and migration wave plan approved. | MVP results and total-cost review |

Any fixed deadline shall force an explicit scope trade rather than silently removing controls or testing.

## 26. Risks and Mitigations

| ID | Risk statement, cause, and impact | Likelihood | Severity | Mitigation | Owner / requirement impact |
|---|---|---:|---:|---|---|
| R-01 | Governance roles remain unassigned, so workflows and exceptions have no accountable decision maker, delaying launch and weakening control. | Medium | Critical | Block production until governance charter and named deputies are approved. | Sponsor; ADM-001, D-001 |
| R-02 | Required licences or add-ons are unavailable or more expensive than expected, causing late redesign. | High | High | Complete feature-level licence assessment in Phase 0; maintain baseline and enhanced architecture options. | IT/Procurement; D-002 |
| R-03 | Retention labels are configured before the file plan is approved, causing over-retention, premature disposal, or inaccessible content. | Medium | Critical | Require Records/Legal approval, non-production tests, label change control, and sample reconciliation. | Records Manager; F-018 to F-020 |
| R-04 | Forced check-out is applied broadly, preventing co-authoring and creating abandoned locks. | Medium | Medium | Use operating-mode decision per library; stale-check-out monitoring; user training and controller override. | Document Control; F-004, F-006, F-023 |
| R-05 | Content changes after submission but approval is applied to the wrong revision, invalidating decision evidence. | Medium | Critical | Capture version and ETag; invalidate/restart on mismatch; concurrency and negative testing. | Engineering/QA; F-008 to F-010, NFR-011 |
| R-06 | Regulatory-record or Preservation Lock is enabled incorrectly and cannot be reversed. | Low | Critical | Exclude from MVP; require Legal/Records approval, isolated test, procedure, and least privilege. | Legal/Records; SEC-012 |
| R-07 | Broad groups, direct permissions, sharing links, or Teams-connected sites expose sensitive information. | Medium | Critical | Site/library boundaries, external sharing off, access reviews, permission reports, sensitivity/DLP, SAM where licensed. | Security; F-024, F-025 |
| R-08 | Poor source data causes duplicate IDs, missing owners, wrong metadata, or unverifiable migrated approvals. | High | High | Inventory, cleanse, quarantine, map provenance, preserve source, batch reconcile, business acceptance. | Migration lead; F-037, DATA-012 |
| R-09 | Personal flow ownership, connector throttling, or expired connections stops lifecycle automation. | Medium | High | Governed environment, solution-aware flows, service ownership, co-owners, retry, monitoring, offboarding test. | Platform owner; NFR-005, ADM-004 to ADM-008 |
| R-10 | Search indexing delay or poor metadata makes readers believe a current document is missing. | Medium | High | Metadata-based current view, exact-ID search, direct publication link, search monitoring, user testing. | Product Owner; F-026, NFR-017 |
| R-11 | Users continue emailing attachments or using bookmarks to superseded copies, reducing adoption and control effectiveness. | High | High | Link-only notifications, obsolete-link redirect/status, policy, onboarding, champions, adoption metrics. | Business owner; F-014, F-017, MET-013/014 |
| R-12 | Audit evidence expires before the retention obligation because the organisation relies on standard audit or flow history. | Medium | Critical | Approval Evidence register, approved retention, Audit Premium assessment, periodic evidence export/test. | Compliance/IT; F-010, F-021, NFR-012 |
| R-13 | Recovery capability is assumed rather than tested, causing unacceptable loss or outage after deletion or ransomware. | Medium | Critical | Approve RPO/RTO, select backup service, restrict restore, exercise and reconcile quarterly. | Continuity/IT; NFR-013, ADM-010 |
| R-14 | The project expands into QMS, LMS, CLM, ERP, AI, and external portals before proving the core DMS. | High | High | Enforce MVP non-goals; require scope addition to remove scope or extend budget/timeline; maintain parking lot. | Product Owner; section 11 |
| R-15 | Microsoft changes a connector, limit, or feature, causing regression. | Medium | Medium | Monitor Message Center/roadmap, pin managed dependencies where possible, regression suite, release cadence. | Platform owner; ADM-011 |
| R-16 | Stakeholders interpret SharePoint configuration as automatic regulatory compliance. | Medium | Critical | Use explicit control mapping, legal/quality assessment, validation evidence, and qualified language. | Sponsor/Legal/Quality; section 18 |
| R-17 | Custom forms or formatting create accessibility barriers. | Medium | High | Prefer native components; WCAG 2.2 AA acceptance testing with disabled users/assistive technology where possible. | Product Owner/QA; NFR-009 |
| R-18 | Personal or sensitive data is collected unnecessarily in metadata, logs, or acknowledgements and retained too long. | Medium | High | Privacy inventory, field minimisation, classification, role access, approved retention, DPIA where indicated. | Privacy; SEC-008 to SEC-010 |
| R-19 | Metrics drive incorrect behaviour because baselines, exclusions, or definitions are unclear. | Medium | Medium | Metric dictionary, owner sign-off, drill-through validation, show freshness and exclusions. | Product Owner/Data; section 20 |
| R-20 | A two-library immutable-revision design creates duplicate-source confusion, while a one-library design may not meet strict immutability needs. | Medium | High | Decide architecture from compliance evidence; prototype both if necessary; declare one authoritative reader source. | Architecture/Quality; OQ-05, F-013 |

## 27. Open Questions

| ID | Question | Status | Answer owner | Decision point / affected requirements |
|---|---|---|---|---|
| OQ-01 | Which legal, contractual, quality, safety, privacy, records, and sector-specific regimes apply to the pilot and enterprise scope? | **Blocking** | Legal, Quality, Security, Privacy | Before architecture approval; SEC, NFR-012/016, DoD. |
| OQ-02 | What Microsoft 365 licences and add-ons are owned, and which may be purchased? | **Blocking** | IT/Procurement | Before solution-option selection; Purview, Power Apps, Power BI, Backup, SAM. |
| OQ-03 | What is the approved retention schedule/file plan, including triggers, periods, disposition, and proof requirements? | **Blocking** | Records/Legal | Before production record capture; F-018 to F-020. |
| OQ-04 | Which pilot business process, document types, operational record, and user population will validate the MVP? | **Blocking** | Sponsor/Product Owner | Before detailed design and baselining. |
| OQ-05 | Is a single controlled library with approved major versions sufficient, or must each approved revision be a separate immutable artefact? | **Blocking** | Quality/Legal/Records/Architecture | Before lifecycle build; F-012 to F-014, R-20. |
| OQ-06 | What RPO, RTO, recovery scope, retention, and exercise frequency apply? | **Blocking** | Continuity/IT/Business owner | Before backup procurement and launch; NFR-013. |
| OQ-07 | What audit-evidence retention period is required, and does existing Audit licensing meet it? | **Blocking** | Compliance/Legal/IT | Before evidence design finalisation; F-010/F-021. |
| OQ-08 | What external sharing, guest, offline access, sync, print, and download scenarios are permitted? | **Blocking** | Security/Privacy/Business owner | Before security acceptance; F-025, SEC-005/006. |
| OQ-09 | Does the organisation need acknowledgement, competence-based LMS training, or legally binding electronic signatures? | **Blocking for affected processes** | Quality/HR/Legal | Before including F-029/F-036 in a release. |
| OQ-10 | What source repositories, volumes, formats, permissions, duplicate rate, and approval evidence must be migrated? | **Blocking for migration** | Migration lead/Business owner | Before pilot migration plan; F-037. |
| OQ-11 | What Document ID and business revision convention is required, and must it appear inside generated/renditioned files? | **Blocking** | Document Control/Quality | Before content type/template build; F-002/F-031. |
| OQ-12 | Which metadata fields are globally mandatory versus conditional by type, process, region, or confidentiality? | **Blocking** | Document Control/Records/Security | Before schema approval; F-001. |
| OQ-13 | What approval authorities, delegation rules, quorum, sequencing, due dates, and escalation apply by document class? | **Blocking** | Business/Quality/Legal | Before workflow build; F-009. |
| OQ-14 | Are emergency change and suspension workflows required in MVP, and what post-hoc review is authorised? | Non-blocking if excluded | Quality/Operations | F-007/F-016; may become separate P0. |
| OQ-15 | Is Power Apps required, or can native SharePoint forms meet MVP usability and accessibility? | Non-blocking | Product Owner/Design | F-033 and licensing. |
| OQ-16 | Which languages, regions, business calendars, and data-residency locations are required after MVP? | Non-blocking | Sponsor/Privacy/HR | Future architecture and NFR-020. |
| OQ-17 | What baseline values exist for search time, approval time, overdue reviews, incidents, and support effort? | Blocking for final metric targets | Product Owner/Data | OBJ and section 20 targets. |
| OQ-18 | What operating hours, support severity response, and maintenance windows are required? | Blocking for service acceptance | Business owner/IT | ADM-002, NFR-003/014. |

## 28. Acceptance Criteria

### 28.1 Functional acceptance

- [ ] One new SOP, one revised SOP, one rejected submission, one future-effective activation, one supersession, one withdrawal/suspension path, and one periodic review complete successfully.
- [ ] Exactly one current effective revision exists for each tested document/applicability context.
- [ ] Drafts remain invisible to ordinary readers while the previous approved version remains available until authorised activation.
- [ ] A content change after submission prevents approval of the changed version without a new review decision.
- [ ] Every tested lifecycle decision is attributable to the correct person, stage, timestamp, version, and outcome.
- [ ] A completed controlled form is captured as an operational record and receives the approved retention treatment.
- [ ] Stale check-out, missing approver, failed activation, and label failure create visible owned exceptions.

### 28.2 Security acceptance

- [ ] All role-based positive and negative permission tests pass.
- [ ] No production site, list, library, app, flow, or record function is accessible anonymously.
- [ ] External sharing is disabled or each exception is approved, scoped, time-bounded, and audited.
- [ ] Direct user permissions and unexpected guests are absent or documented as exceptions.
- [ ] Production automation has approved ownership and no embedded credentials.
- [ ] No unresolved Critical or High security finding remains.

### 28.3 Data acceptance

- [ ] 100% of effective pilot documents pass required-field and approval-evidence reconciliation.
- [ ] Document IDs are unique and persistent across rename/move tests.
- [ ] Current, superseded, and withdrawn relationships reconcile.
- [ ] Pilot migration counts, sizes, metadata, permissions, dates, and required sample hashes reconcile to the approved tolerance.
- [ ] Personal and sensitive fields have approved owners, access, purpose, and retention treatment.

### 28.4 Workflow acceptance

- [ ] Workflow retry and replay produce no duplicate effective revision, decision, notification assignment, or record.
- [ ] Missing route, owner departure, throttling simulation, and expired connection produce safe failure and actionable exception.
- [ ] Scheduled activation and periodic review execute at the approved date/time and business-calendar rules.
- [ ] Manual fallback and reconciliation procedures are demonstrated.

### 28.5 Reporting acceptance

- [ ] Required reports in section 20 are present and role restricted.
- [ ] Metric definitions, freshness, exclusions, and owner are displayed or linked.
- [ ] A sample dashboard and CSV export reconcile to source records.
- [ ] Threshold breach creates or links to an accountable action.

### 28.6 Performance and reliability acceptance

- [ ] NFR-001 and NFR-002 tests meet approved thresholds under pilot load.
- [ ] Workflow success meets the agreed stabilised threshold.
- [ ] Search freshness and direct-link fallback meet NFR-017.
- [ ] Configuration and views pass the agreed volume test without threshold errors.

### 28.7 Usability and accessibility acceptance

- [ ] At least 90% of representative users find the specified current document within 60 seconds without assistance.
- [ ] Authors, reviewers, approvers, and Document Controllers complete their core scenario without an undocumented workaround.
- [ ] Accessibility tests in NFR-009 pass with no unresolved critical barrier.
- [ ] Error messages and obsolete-link handling are understandable in moderated testing.

### 28.8 Administrative and recovery acceptance

- [ ] Dev/Test/Prod deployment from source-controlled artefacts is demonstrated without direct production editing.
- [ ] Configuration drift report passes after deployment.
- [ ] Service identity/co-owner offboarding test passes.
- [ ] Restore exercise meets the approved interim or final RPO/RTO and reconciles content, metadata, permissions, and evidence.
- [ ] Support, monitoring, escalation, and Microsoft-service-change procedures are operational.

### 28.9 Compliance and governance acceptance

- [ ] Applicable obligations and non-applicable regimes are documented and approved.
- [ ] File plan, classification, access model, audit retention, and external-sharing decisions are signed by accountable owners.
- [ ] Product documentation makes no unsupported certification, compliance, or electronic-signature claim.
- [ ] Document Control, Records Management, Security, Privacy/Legal as applicable, Product Owner, platform owner, and pilot business owner sign release acceptance.

### 28.10 Documentation acceptance

- [ ] User guides exist for readers, authors, reviewers/approvers, Document Controllers, and Records Managers.
- [ ] Administrator runbooks cover deployment, configuration, monitoring, connection renewal, exception repair, permissions, backup, restore, and offboarding.
- [ ] Data dictionary, state model, role matrix, file-plan mapping, integration contracts, test evidence, release notes, and known limitations are version controlled.

## 29. Definition of Done

The MVP is Done only when all of the following are true:

1. All P0 functional and non-functional requirements are implemented or have an explicitly approved exception with owner, expiry, risk, and compensating control.
2. Blocking open questions are answered and incorporated into the design, operating procedures, tests, and acceptance evidence.
3. The production environment is deployed from approved source-controlled scripts and managed solution artefacts; configuration drift validation passes.
4. Functional, negative, concurrency, security, accessibility, performance, migration, integration, and recovery tests pass at approved thresholds.
5. The lifecycle is demonstrated end to end using representative content, including rejection, future activation, supersession, an operational record, exception handling, and retention treatment.
6. Required dashboards and metric definitions are operational, baselined, and owned.
7. Document Control, Records Management, Product, Security, Privacy/Legal/Quality as applicable, IT, and the pilot business owner approve the release.
8. User training, support documentation, administrative runbooks, service catalogue, and escalation paths are published.
9. No unresolved Critical or High defect, security finding, data-reconciliation variance, or control failure remains.
10. Backup/recovery and service-owner offboarding have been exercised successfully.
11. A four-week controlled pilot and 30-day review are complete, with owners assigned for 60/90-day measures and corrective actions.
12. Enterprise rollout remains separately gated by the scale decision; MVP completion does not automatically authorise enterprise migration.

## 30. Traceability Matrix

| CONOPS source element | Research finding | Requirement(s) | User role | Workflow | Acceptance/test implication | Priority |
|---|---|---|---|---|---|---|
| SharePoint as authoritative DMS | Metadata/content types drive organisation and search. | F-001 to F-005, F-026 | Reader, Author, Controller | WF-01 to WF-04 | Schema, current-view, exact-ID, and draft-visibility tests. | P0 |
| Check-in/check-out | Check-out and co-authoring are incompatible. | F-004, F-006, F-023 | Author, Controller | WF-02, WF-06 | Exclusive-edit, co-author, stale-lock, and override tests. | P0 |
| Major/minor versions and content approval | SharePoint preserves draft/published states; ETag protects file approval. | F-004, F-008 to F-012; NFR-011 | Author, Reviewer, Approver | WF-02, WF-03 | Version-change-during-approval and reader-visibility tests. | P0 |
| Controlled policies, SOPs, work instructions, and templates | ISO 9001 guidance distinguishes maintained information and retained evidence. | F-003, DATA-001/002/006 | Author, Reader, Quality | WF-02, WF-05 | Blank-template versus completed-record test. | P0 |
| Request and change control | Traceable entry and triage are required to prevent uncontrolled work. | F-007, DATA-003 | Requester, Controller | WF-01 | Create, return, reject, duplicate, and emergency-route tests. | P0 |
| Review and accountable approval | Power Automate supports approval, but evidence must be durable. | F-009 to F-011, DATA-004 | Reviewer, Approver, Auditor | WF-02 | Route, rejection, delegation, evidence-retention tests. | P0 |
| Future effective date | Long-running wait is fragile; scheduled activation requires revalidation. | F-012, F-013; NFR-006 | Controller, Reader | WF-03 | Due/not-due, replay, version mismatch, duplicate-current tests. | P0 |
| Supersession and current-copy control | Readers need current content by default; history remains authorised. | F-013, F-014, UX-004 | Reader, Auditor | WF-03, WF-04 | Old bookmark, search filtering, relationship reconciliation. | P0 |
| Periodic review | ISO 15489 includes monitoring and assigned responsibilities. | F-015, F-016 | Owner, Controller | WF-04 | Reminder, escalation, owner departure, no silent date roll-forward. | P0 |
| Training/acknowledgement | Acknowledgement is evidence but not competence certification. | F-029, DATA-008 | Reader, Manager | WF-03 | Exact-revision assignment and response test. | P1 |
| Operational business records | Records require metadata, capture, retention, and disposition. | F-018 to F-020, F-029; DATA-006/007/011 | Records Manager, Business user | WF-05 | Capture, label, hold, disposition, proof test. | P0/P1 |
| Approval and audit history | Standard audit retention may be shorter than business obligations. | F-010, F-021; NFR-012 | Auditor, Compliance | All | Lifecycle reconstruction without email or flow history. | P0 |
| Role-based administration | NIST least privilege and Microsoft group controls. | F-024, SEC-001 to SEC-004 | All roles, Security | All | Positive/negative RBAC and separation-of-duty tests. | P0 |
| Sensitive and externally shared documents | Microsoft sharing can be enabled by default; sensitivity/DLP add controls. | F-025, SEC-005/006 | Security, Privacy, Owner | All | Guest, link, download, label, and DLP tests. | P0 |
| Search and portal | SharePoint information architecture joins navigation, metadata, search, security. | F-026, UX-001 to UX-004, NFR-008/017 | Reader | WF-03, WF-08 | 60-second findability and search-freshness tests. | P0 |
| Power Automate lifecycle | Connectors have throttling; Power Platform ALM governs deployment. | F-008 to F-017, ADM-004/005/008; NFR-005/006/015 | Platform Admin, lifecycle roles | WF-02 to WF-07 | Retry, throttling, connection, deployment, replay tests. | P0 |
| Scripting and repeatability | SharePoint site scripts are rerunnable; configuration requires baseline control. | ADM-003, ADM-006/007; NFR-019 | Admin, QA | WF-07 | Idempotent provisioning and drift detection. | P0 |
| Reporting and business improvement | Metrics must be defined, owned, and actionable. | F-027, section 20 | Manager, Product Owner | WF-08 | Source reconciliation, freshness, access, threshold action. | P0 |
| Backup and recovery | Backup capability must be selected against explicit RPO/RTO. | NFR-013, ADM-010, INT-009 | IT, Continuity | WF-07 | Site restore and evidence reconciliation. | P0 decision |
| Advanced document generation, OCR, AI, eSignature | Microsoft offers pay-as-you-go document processing, but core DMS does not depend on it. | F-031, F-034 to F-036 | Business user, Legal | Future | Accuracy, cost, signature-evidence, and failure tests before release. | P1/P2 |
| SharePoint Advanced Management | Current Microsoft capabilities include lifecycle and access-governance policies. | Future scope; ADM-011/012 | SharePoint Admin, Security | WF-07/08 | Licence and fit assessment; no MVP test unless selected. | P2 |
| SPFx/custom UI | Native-first principle; custom development only for validated gaps. | Explicit MVP non-goal; A-007 | Product Owner, Engineering | WF-07 | Fit-gap decision; no requirement generated for MVP implementation. | P3 |
| Enterprise-wide migration | Source quality and scale are unknown. | F-037, DATA-012, INT-010 | Migration lead, Business owner | WF-07 | Pilot reconciliation gates enterprise plan. | P3 until gate |

Requirements inferred rather than directly stated in the CONOPS are marked INF in section 15. CONOPS ideas intentionally not implemented in MVP—such as SPFx, enterprise migration, AI processing, full LMS, and qualified eSignature—are traced to P2/P3 or non-goal decisions instead of silently omitted.

## 31. Appendix: Research Sources

Sources were accessed on 25 August 2026 unless otherwise stated.

1. Microsoft, [Introduction to SharePoint information architecture](https://learn.microsoft.com/en-us/sharepoint/information-architecture-modern-experience).
2. Microsoft, [How versioning works in lists and libraries](https://support.microsoft.com/en-us/sharepoint/lists/documents-and-library/how-versioning-works-in-lists-and-libraries).
3. Microsoft, [Microsoft SharePoint Connector for Power Automate](https://learn.microsoft.com/en-us/sharepoint/dev/business-apps/power-automate/sharepoint-connector-actions-triggers).
4. Microsoft, [Learn about retention policies and retention labels](https://learn.microsoft.com/en-us/purview/retention).
5. Microsoft, [Records management for documents and emails in Microsoft 365](https://learn.microsoft.com/en-us/purview/records-management).
6. Microsoft, [Learn about retention for SharePoint and OneDrive](https://learn.microsoft.com/en-us/purview/retention-policies-sharepoint).
7. Microsoft, [Limits for Microsoft 365 retention policies and retention label policies](https://learn.microsoft.com/en-us/purview/retention-limits).
8. Microsoft, [Manage audit log retention policies](https://learn.microsoft.com/en-us/purview/audit-log-retention-policies).
9. Microsoft, [Audit log activities](https://learn.microsoft.com/en-us/purview/audit-log-activities).
10. Microsoft, [SharePoint limits](https://learn.microsoft.com/en-us/office365/servicedescriptions/sharepoint-online-service-description/sharepoint-online-limits).
11. Microsoft, [SharePoint site template and site script overview](https://learn.microsoft.com/en-us/sharepoint/dev/declarative-customization/site-design-overview).
12. Microsoft, [Security and governance considerations in Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/governance-considerations).
13. Microsoft, [Solution concepts with Power Platform](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm).
14. Microsoft, [Understand platform limits and avoid throttling](https://learn.microsoft.com/en-us/power-automate/guidance/coding-guidelines/understand-limits).
15. Microsoft, [Overview of document processing for Microsoft 365](https://learn.microsoft.com/en-us/microsoft-365/documentprocessing/syntex-overview).
16. Microsoft, [Automate document generation with document processing and Power Automate](https://learn.microsoft.com/en-us/microsoft-365/documentprocessing/automate-document-generation).
17. Microsoft, [SharePoint Advanced Management overview](https://learn.microsoft.com/en-us/sharepoint/advanced-management).
18. Microsoft, [SharePoint site lifecycle management](https://learn.microsoft.com/en-us/sharepoint/site-lifecycle-management).
19. Microsoft, [Restrict SharePoint site access with Microsoft 365 and Entra groups](https://learn.microsoft.com/en-us/sharepoint/restricted-access-control).
20. Microsoft, [Overview of Microsoft 365 Backup](https://learn.microsoft.com/en-us/microsoft-365/backup/backup-overview).
21. Microsoft, [Microsoft 365 Compliance Licensing Comparison](https://learn.microsoft.com/office365/servicedescriptions/downloads/microsoft-365-compliance-licensing-comparison.pdf).
22. ISO, [ISO 15489-1:2016 — Records management concepts and principles](https://www.iso.org/standard/62542.html).
23. ISO, [Guidance on ISO 9001:2015 documented information](https://www.iso.org/files/live/sites/isoorg/files/standards/docs/en/iso_9001_2015_guidance_documented_information.pdf).
24. W3C, [Web Content Accessibility Guidelines (WCAG) 2.2](https://www.w3.org/TR/WCAG22/).
25. NIST, [SP 800-171 Revision 3, Least Privilege and Audit Record Content](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/800-171r3/NIST.SP.800-171r3.html).
26. UK Information Commissioner's Office, [A guide to the data-protection principles](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/).

## 32. Appendix: Glossary

| Term | Definition |
|---|---|
| ALM | Application Lifecycle Management: controlled development, testing, deployment, versioning, and maintenance of apps and automation. |
| Approval Evidence | Durable record of a review or approval decision tied to a specific document version. |
| Authoritative source | The location and object recognised as the official current source, rather than a copied attachment or download. |
| CONOPS | Concept of Operations: description of how users, processes, and systems operate in the intended future state. |
| Content approval | SharePoint mechanism that controls whether submitted content is Approved, Rejected, or Pending and visible to readers. |
| Content type | Reusable SharePoint definition that groups document behaviour, template, and metadata columns. |
| Controlled document | Governed information whose lifecycle includes authorised creation, review, approval, publication, revision, and withdrawal. |
| Controlled copy | Authorised rendition or view whose status can be verified against the DMS; a downloaded/printed copy may become uncontrolled unless additional controls apply. |
| DLP | Data Loss Prevention policy that detects and controls specified sensitive-information handling. |
| DMS | Document Management System. In this PRD, the complete Microsoft 365 configuration, automation, governance, procedures, and support service. |
| Document Controller | Role accountable for document lifecycle administration and control integrity. |
| Document Set | SharePoint content construct for managing a related group of documents and shared metadata as a work product. |
| DMS current view | Authoritative user experience filtered to current effective documents. |
| ETag | Version identifier used to detect whether a SharePoint item/file changed between read and update/approval. |
| Effective date | Date/time from which an approved revision is authorised for use. |
| Entra ID | Microsoft Entra ID, the Microsoft cloud identity and access service. |
| File plan | Controlled set of record categories, authorities, retention triggers, periods, and disposition actions. |
| Lifecycle Status | Business state of a document independent from SharePoint's native approval status. |
| Major version | Published SharePoint version normally representing an approved milestone. |
| Metadata | Structured descriptive or control information stored with a document or record. |
| Minor version | Draft SharePoint version not normally visible to ordinary readers. |
| Operational record | Captured evidence of a completed business activity. |
| P0/P1/P2/P3 | Must Have, Should Have, Could Have, and Won't Have Initially priorities. |
| PnP PowerShell | Community-led open-source PowerShell module widely used for Microsoft 365 and SharePoint provisioning; it requires organisational dependency governance. |
| Power Platform solution | Package used to manage and deploy Power Apps, Power Automate flows, and related configuration through environments. |
| PRD | Product Requirements Document. |
| Purview | Microsoft Purview services used here for retention, records, sensitivity, DLP, audit, and eDiscovery-related controls. |
| Record label | Purview retention label that may impose record restrictions and retention/disposition behaviour. |
| Regulatory record | Purview record classification with deliberately irreversible restrictions; use requires specific approval. |
| RPO | Recovery Point Objective: maximum tolerable data-loss interval. |
| RTO | Recovery Time Objective: maximum tolerable time to restore service. |
| SOP | Standard Operating Procedure. |
| SPFx | SharePoint Framework for custom web parts and extensions. |
| Superseded | Lifecycle state for a previously effective revision replaced by a newer effective revision. |
| Taxonomy | Centrally controlled terms used to classify, filter, search, and govern content. |
| WCAG | Web Content Accessibility Guidelines. |

---

**End of PRD — Draft 0.1**
