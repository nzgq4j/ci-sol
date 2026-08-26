import { validateEffectiveDocument } from "../domain/lifecycle";
import type {
  AcknowledgementAssignment,
  ApprovalAssignment,
  AuditEvent,
  AutomationFlow,
  ChangeRequest,
  ControlException,
  ControlledDocument,
  CurrentUserContext,
  DeploymentRecord,
  DocumentDetail,
  EvidenceOutcome,
  EvidenceReceipt,
  IntegrationBoundary,
  LifecycleEvent,
  ManagedSite,
  Metric,
  PersonRef,
  PlatformSnapshot,
  RecoveryStatus,
  RetentionMapping,
  Role,
  ServiceMeta,
  ServiceResult,
} from "../domain/types";
import type { DmsServices, GovernedAction } from "./contracts";

const now = "2026-08-25T09:49:00Z";
const person = (objectId: string, displayName: string, email?: string): PersonRef => ({ objectId, displayName, email });
const david = person("demo-user-dk", "David Kolb", "david.kolb@example.invalid");
const maya = person("demo-user-mp", "Maya Patel");
const jon = person("demo-user-jb", "Jon Bell");
const anika = person("demo-user-as", "Anika Shah");
const lewis = person("demo-user-lg", "Lewis Grant");
const sofia = person("demo-user-sr", "Sofia Reed");
const imran = person("demo-user-ic", "Imran Chowdhury");
const nina = person("demo-user-nw", "Nina Walsh");
const platformTeam = person("demo-group-platform", "Platform team");

const documentsSeed: ControlledDocument[] = [
  ["SOP-OPS-014", "Customer escalation and service recovery", "SOP", "Customer operations", maya, "4.2", "Effective", "2026-08-18", "2027-02-18", true, false],
  ["WI-SEC-021", "Report and contain a suspected security incident", "Work instruction", "Information security", jon, "3.0", "Effective", "2026-08-12", "2027-02-12", false, true],
  ["POL-PEO-006", "Hybrid working and secure workspace policy", "Policy", "People operations", anika, "2.3", "Effective", "2026-08-04", "2027-08-04", true, false],
  ["SOP-FIN-008", "Supplier onboarding and due diligence", "SOP", "Finance & procurement", lewis, "5.1", "Effective", "2026-07-30", "2027-01-30", false, false],
  ["WI-OPS-044", "Priority-one service outage communications", "Work instruction", "Service operations", maya, "1.8", "Review due", "2026-07-22", "2026-08-29", false, true],
  ["STD-DAT-003", "Business data classification standard", "Standard", "Data governance", sofia, "3.4", "Effective", "2026-07-16", "2027-07-16", false, false],
  ["SOP-HSE-011", "Workplace incident reporting and investigation", "SOP", "Health & safety", imran, "2.0", "In approval", undefined, undefined, false, false],
  ["TMP-QUA-002", "Corrective action and root cause record", "Template", "Quality management", nina, "1.6", "Effective", "2026-06-28", "2027-06-28", false, false],
].map(([id, title, documentType, process, owner, revision, status, effectiveDate, nextReviewDate, isFavourite, acknowledgementRequired]) => ({
  id: id as string,
  title: title as string,
  documentType: documentType as string,
  process: process as string,
  owner: owner as PersonRef,
  businessRevision: revision as string,
  sharePointVersion: `${revision}.0`,
  eTag: `\"${id}-${revision}\"`,
  lifecycleStatus: status as ControlledDocument["lifecycleStatus"],
  nativeApprovalStatus: status === "In approval" ? "Pending" : "Approved",
  effectiveDate: effectiveDate as string | undefined,
  nextReviewDate: nextReviewDate as string | undefined,
  applicability: ["UK operations"],
  classification: "Internal",
  retentionClass: "Controlled business document · 7 years",
  authoritativeUrl: undefined,
  acknowledgementRequired: acknowledgementRequired as boolean,
  isFavourite: isFavourite as boolean,
  lastViewedAt: id === "SOP-OPS-014" ? "2026-08-25T08:12:00Z" : id === "WI-OPS-044" ? "2026-08-24T16:05:00Z" : undefined,
  dataUpdatedAt: now,
}));

const changesSeed: ChangeRequest[] = [
  ["CR-0261", "Update escalation thresholds for priority accounts", "Revision", "Customer operations", maya, "Impact assessment", "On track", "SOP-OPS-014"],
  ["CR-0257", "Align supplier screening with sanctions update", "Revision", "Finance & procurement", lewis, "Authoring", "Attention", "SOP-FIN-008"],
  ["CR-0253", "Clarify incident notification timings", "Revision", "Information security", jon, "Approval", "On track", "WI-SEC-021"],
  ["CR-0249", "Annual review of hybrid work policy", "Revision", "People operations", anika, "Activation", "On track", "POL-PEO-006"],
].map(([id, title, requestType, process, owner, stage, health, linkedDocumentId], index) => ({
  id: id as string,
  title: title as string,
  requestType: requestType as ChangeRequest["requestType"],
  justification: "Controlled change requested and awaiting the next accountable lifecycle action.",
  process: process as string,
  owner: owner as PersonRef,
  stage: stage as ChangeRequest["stage"],
  createdAt: `2026-08-${String(23 - index * 3).padStart(2, "0")}T09:00:00Z`,
  dueAt: `2026-08-${String(28 + index).padStart(2, "0")}T16:00:00Z`,
  health: health as ChangeRequest["health"],
  linkedDocumentId: linkedDocumentId as string,
}));

const approvalsSeed: ApprovalAssignment[] = [
  ["APR-0881", "SOP-HSE-011", "Workplace incident reporting and investigation", "2.0", imran, "Final approval", "Medium", "2026-08-25T16:00:00Z"],
  ["APR-0878", "WI-OPS-044", "Priority-one service outage communications", "1.8", maya, "Process owner", "High", "2026-08-26T16:00:00Z"],
  ["APR-0874", "BCP-OPS-003", "Business continuity contact tree", "1.3", sofia, "Compliance review", "Low", "2026-08-28T16:00:00Z"],
  ["APR-0869", "STD-SEC-009", "Third-party access recertification", "2.1", jon, "Control owner", "Medium", "2026-08-29T16:00:00Z"],
].map(([id, documentId, documentTitle, documentRevision, submittedBy, stage, risk, dueAt]) => ({
  id: id as string,
  documentId: documentId as string,
  documentTitle: documentTitle as string,
  documentRevision: documentRevision as string,
  documentETag: `\"${documentId}-${documentRevision}\"`,
  submittedBy: submittedBy as PersonRef,
  stage: stage as string,
  risk: risk as ApprovalAssignment["risk"],
  dueAt: dueAt as string,
  changeSummary: "Process and control wording updated following the approved change request.",
  priorRevision: String(Math.max(1, Number(documentRevision) - 0.1).toFixed(1)),
  separationOfDutiesConfirmed: true,
}));

const acknowledgementsSeed: AcknowledgementAssignment[] = [
  {
    id: "ACK-0184",
    documentId: "WI-SEC-021",
    documentTitle: "Report and contain a suspected security incident",
    documentRevision: "3.0",
    documentETag: "\"WI-SEC-021-3.0\"",
    assignedTo: david,
    assignedAt: "2026-08-20T09:00:00Z",
    dueAt: "2026-08-27T17:00:00Z",
  },
  {
    id: "ACK-0189",
    documentId: "WI-OPS-044",
    documentTitle: "Priority-one service outage communications",
    documentRevision: "1.8",
    documentETag: "\"WI-OPS-044-1.8\"",
    assignedTo: david,
    assignedAt: "2026-08-22T09:00:00Z",
    dueAt: "2026-08-29T17:00:00Z",
  },
];

const exceptionsSeed: ControlException[] = [
  {
    id: "EX-0042",
    title: "Two effective documents missing review dates",
    scope: "Operations document centre",
    owner: maya,
    severity: "High",
    createdAt: "2026-08-25T06:42:00Z",
    correlationId: "corr-ex-0042",
    blocking: true,
    status: "Open",
    retryCount: 0,
  },
  {
    id: "EX-0039",
    title: "Flow owner uses individual rather than service account",
    scope: "DMS-Notify-Expiry",
    owner: platformTeam,
    severity: "Medium",
    createdAt: "2026-08-23T09:00:00Z",
    correlationId: "corr-ex-0039",
    blocking: false,
    status: "Open",
    retryCount: 1,
  },
];

const sites: ManagedSite[] = [
  ["OP-DMS-01", "Operations document centre", 184, "Healthy", "2026-08-25T09:42:00Z"],
  ["IS-DMS-02", "Information security", 96, "Healthy", "2026-08-25T09:38:00Z"],
  ["HR-DMS-01", "People operations", 72, "Healthy", "2026-08-25T09:31:00Z"],
  ["QM-DMS-01", "Quality management", 128, "Review", "2026-08-25T09:29:00Z"],
].map(([id, displayName, documentCount, health, lastScannedAt]) => ({
  id: id as string,
  displayName: displayName as string,
  documentCount: documentCount as number,
  accessModel: "Document Owners · Approvers · Readers",
  health: health as ManagedSite["health"],
  lastScannedAt: lastScannedAt as string,
}));

const flows: AutomationFlow[] = [
  ["DMS-Change-Control", "Solution-aware", "2026-08-25T08:54:00Z", "Healthy", 1284],
  ["DMS-Publish-Effective", "Service account", "2026-08-25T09:18:00Z", "Healthy", 602],
  ["DMS-Notify-Expiry", "Individual owner", "2026-08-25T08:01:00Z", "Exception", 421],
  ["DMS-Acknowledgement", "Service account", "2026-08-25T09:26:00Z", "Healthy", 3918],
  ["DMS-Control-Scan", "Service account", "2026-08-25T09:42:00Z", "Healthy", 8412],
].map(([displayName, ownership, lastRunAt, health, rollingRunCount]) => ({
  id: displayName as string,
  displayName: displayName as string,
  ownership: ownership as string,
  lastRunAt: lastRunAt as string,
  health: health as AutomationFlow["health"],
  rollingRunCount: rollingRunCount as number,
  environment: "Production",
}));

const retention: RetentionMapping[] = [
  ["RET-001", "Controlled business document", "7 years after superseded", "All document centres", "Published"],
  ["RET-002", "Policy and standard", "7 years after superseded", "Policy content types", "Published"],
  ["RET-003", "Approval evidence", "7 years after decision", "Approval evidence register", "Published"],
  ["RET-004", "Change request evidence", "7 years after closure", "Change request register", "Published"],
  ["RET-005", "Temporary working draft", "Delete after 180 days", "Draft libraries", "Review"],
].map(([id, name, retentionValue, scope, status]) => ({ id, name, retention: retentionValue, scope, status, authority: "Pending tenant confirmation" } as RetentionMapping));

const integrationsSeed: IntegrationBoundary[] = [
  ["purview", "Microsoft Purview", "Retention labels, audit and eDiscovery", "Microsoft identity · approved roles", "Records management", true, "Healthy"],
  ["entra", "Microsoft Entra ID", "Groups, Conditional Access and identity", "Native tenant integration", "Identity platform", true, "Healthy"],
  ["power-bi", "Power BI", "Governance reporting semantic model", "Workspace service identity", "Product operations", true, "Healthy"],
  ["teams", "Microsoft Teams", "Approval and acknowledgement notifications", "Microsoft identity", "Document control", true, "Healthy"],
  ["esignature", "Electronic signature", "Optional external signature for selected records", "Not configured", "Legal decision required", false, "Unknown"],
].map(([id, name, purpose, authentication, owner, enabled, health]) => ({ id, name, purpose, authentication, owner, enabled, health } as IntegrationBoundary));

const deployments: DeploymentRecord[] = [
  ["REL-2026.08.3", "Production", "Metadata validation and dashboard fix", "2026-08-25T07:30:00Z", "Successful", "EVD-REL-083"],
  ["REL-2026.08.2", "Production", "Acknowledgement evidence schema", "2026-08-18T06:45:00Z", "Successful", "EVD-REL-082"],
  ["REL-2026.08.1", "Production", "Content type baseline v3.6", "2026-08-04T07:10:00Z", "Successful", "EVD-REL-081"],
  ["REL-2026.09-RC1", "Test", "Review delegation and escalation", "2026-08-24T14:20:00Z", "Review", "EVD-REL-091"],
].map(([id, environment, scope, deployedAt, result, evidenceId]) => ({ id, environment, scope, deployedAt, result, evidenceId } as DeploymentRecord));

const recovery: RecoveryStatus = {
  rpo: "24h planning assumption",
  rto: "8 business hours planning assumption",
  lastExerciseAt: "2026-08-18T09:00:00Z",
  lastExerciseDuration: "2h 14m",
  result: "Healthy",
  openFindings: 0,
};

const auditSeed: AuditEvent[] = [
  ["AUD-094217", "DMS.ControlScan.Completed", "svc-dms-platform", "Tenant", "2026-08-25T09:42:17Z", "Success", "corr-scan-0942", "DMS evidence register"],
  ["AUD-093104", "DMS.Access.Recertified", "anika.shah", "HR-DMS-01", "2026-08-25T09:31:04Z", "Success", "corr-access-0931", "Microsoft Purview Audit"],
  ["AUD-091833", "DMS.Document.Activated", "svc-dms-release", "SOP-OPS-014", "2026-08-25T09:18:33Z", "Success", "corr-activation-0918", "Approval evidence register"],
  ["AUD-085411", "DMS.Flow.PolicyEvaluated", "svc-dms-platform", "Power Platform", "2026-08-25T08:54:11Z", "Success", "corr-flow-0854", "Power Platform"],
  ["AUD-083649", "DMS.Retention.Registered", "svc-purview", "12 records", "2026-08-25T08:36:49Z", "Success", "corr-retain-0836", "Microsoft Purview"],
  ["AUD-080122", "DMS.Flow.OwnerException", "svc-dms-platform", "DMS-Notify-Expiry", "2026-08-25T08:01:22Z", "Review", "corr-flow-0801", "Exception register"],
].map(([id, eventType, actor, object, occurredAt, result, correlationId, source]) => ({ id, eventType, actor, object, occurredAt, result, correlationId, source } as AuditEvent));

const metrics: Metric[] = [
  { id: "MET-001", label: "Control completeness", value: "99.4%", note: "Required metadata and evidence", state: "positive", definition: "Effective documents passing all required metadata and approval evidence checks.", updatedAt: now },
  { id: "MET-004", label: "Review on time", value: "96.2%", note: "12 due in 30 days", state: "positive", definition: "Effective documents reviewed before the next review date.", updatedAt: now },
  { id: "MET-006", label: "Workflow success", value: "99.8%", note: "Rolling 30 days", state: "positive", definition: "Eligible lifecycle runs reaching a successful terminal state.", updatedAt: now },
  { id: "MET-012", label: "Acknowledgement", value: "84.0%", note: "Target 95%", state: "warning", definition: "Assigned acknowledgements completed by the due date.", updatedAt: now },
];

function meta(source: string): ServiceMeta {
  return { source, retrievedAt: now, freshness: "current", correlationId: `demo-${source.toLowerCase().replaceAll(" ", "-")}` };
}

function success<T>(source: string, data: T): ServiceResult<T> {
  return { ok: true, data, meta: meta(source) };
}

function notFound(message: string): ServiceResult<never> {
  return { ok: false, error: { code: "NOT_FOUND", message, recoverable: false } };
}

function receipt(outcome: EvidenceOutcome, version?: string, eTag?: string): EvidenceReceipt {
  const suffix = Math.random().toString(36).slice(2, 9).toUpperCase();
  return {
    evidenceId: `EVD-${suffix}`,
    correlationId: `corr-${suffix.toLowerCase()}`,
    recordedAt: new Date().toISOString(),
    outcome,
    boundVersion: version,
    boundETag: eTag,
  };
}

function detailFor(document: ControlledDocument): DocumentDetail {
  const event = (stage: LifecycleEvent["stage"], title: string, detail: string, occurredAt: string, outcome: LifecycleEvent["outcome"], actor: PersonRef): LifecycleEvent => ({
    id: `EVT-${document.id}-${stage}`,
    documentId: document.id,
    stage,
    title,
    detail,
    actor,
    occurredAt,
    outcome,
    correlationId: `corr-${document.id.toLowerCase()}-${stage.toLowerCase()}`,
    version: document.businessRevision,
    eTag: document.eTag,
  });
  const lifecycle = [
    event("Author", "Controlled draft created", "Approved template and content type applied", "2026-08-03T09:00:00Z", "Completed", document.owner),
    event("Review", "Subject-matter review complete", "Version and ETag captured", "2026-08-11T15:22:00Z", "Approved", jon),
    event("Approve", "Process owner approved", "Decision retained in approval evidence", "2026-08-17T13:04:00Z", "Approved", maya),
  ];
  if (document.effectiveDate) lifecycle.push(event("Effective", "Published to the controlled library", "Current authoritative revision activated", `${document.effectiveDate}T08:00:00Z`, "Completed", platformTeam));
  lifecycle.push(event("Retain", "Disposition scheduled", document.retentionClass ?? "Retention mapping required", "2033-08-18T08:00:00Z", "Scheduled", platformTeam));
  return {
    document,
    lifecycle,
    versionHistory: [
      { businessRevision: document.businessRevision, lifecycleStatus: document.lifecycleStatus, effectiveDate: document.effectiveDate, evidenceId: `EVD-${document.id}-CURRENT` },
      { businessRevision: Math.max(1, Number(document.businessRevision) - 0.1).toFixed(1), lifecycleStatus: "Superseded", effectiveDate: "2025-08-18", evidenceId: `EVD-${document.id}-PRIOR` },
    ],
  };
}

class DemoStore {
  documents = structuredClone(documentsSeed);
  changes = structuredClone(changesSeed);
  approvals = structuredClone(approvalsSeed);
  acknowledgements = structuredClone(acknowledgementsSeed);
  exceptions = structuredClone(exceptionsSeed);
  integrations = structuredClone(integrationsSeed);
  audit = structuredClone(auditSeed);
}

export function createDemoServices(): DmsServices {
  const store = new DemoStore();
  const context: CurrentUserContext = {
    user: david,
    department: "Operations",
    allowedRoles: ["endUser", "teamAdmin", "platformAdmin"],
    activeRole: "endUser",
  };

  const platformSnapshot = (): PlatformSnapshot => ({
    health: store.exceptions.some((item) => item.status === "Open" && item.severity === "Critical") ? "Exception" : "Healthy",
    lastScannedAt: "2026-08-25T09:42:00Z",
    summary: "Platform operating within control tolerances",
    sites,
    flows,
    retention,
    integrations: store.integrations,
    deployments,
    recovery,
    audit: store.audit,
    metrics,
  });

  const permissionsByRole: Record<Role, ReadonlySet<GovernedAction>> = {
    endUser: new Set(["readCurrentDocument", "acknowledgeDocument"]),
    teamAdmin: new Set(["readCurrentDocument", "approveDocument", "resolveException"]),
    platformAdmin: new Set(["readCurrentDocument", "administerPlatform"]),
  };

  return {
    sharePointSites: {
      async listSites() { return success("SharePoint sites", sites); },
    },
    sharePointDocuments: {
      async search(query) {
        const text = query.text?.trim().toLowerCase();
        let data = store.documents.filter((document) => {
          if (query.currentOnly && !["Effective", "Review due"].includes(document.lifecycleStatus)) return false;
          if (query.lifecycle?.length && !query.lifecycle.includes(document.lifecycleStatus)) return false;
          if (query.documentTypes?.length && !query.documentTypes.includes(document.documentType)) return false;
          if (query.favouritesOnly && !document.isFavourite) return false;
          if (query.recentOnly && !document.lastViewedAt) return false;
          if (!text) return true;
          return [document.id, document.title, document.process, document.owner.displayName, document.documentType, ...document.applicability]
            .join(" ")
            .toLowerCase()
            .includes(text);
        });
        if (query.recentOnly) data = data.sort((a, b) => (b.lastViewedAt ?? "").localeCompare(a.lastViewedAt ?? ""));
        if (query.limit) data = data.slice(0, query.limit);
        return success("SharePoint documents", structuredClone(data));
      },
      async getDetail(documentId) {
        const document = store.documents.find((item) => item.id === documentId);
        return document ? success("SharePoint documents", detailFor(structuredClone(document))) : notFound(`Document ${documentId} was not found.`);
      },
      async setFavourite(documentId, favourite) {
        const document = store.documents.find((item) => item.id === documentId);
        if (!document) return notFound(`Document ${documentId} was not found.`);
        document.isFavourite = favourite;
        return success("Microsoft Graph favourites", undefined);
      },
    },
    sharePointMetadata: {
      async listContentTypes() {
        return success("SharePoint content types", ["Controlled Document", "Operational Record", "External Document"].map((name, index) => ({ id: `demo-ct-${index + 1}`, name })));
      },
      async validateForActivation(document) {
        return success("SharePoint metadata", validateEffectiveDocument(document));
      },
    },
    graph: {
      async getCurrentUser() { return success("Microsoft Graph", david); },
      async searchPeople(query) {
        const people = [david, maya, jon, anika, lewis, sofia, imran, nina].filter((item) => item.displayName.toLowerCase().includes(query.toLowerCase()));
        return success("Microsoft Graph", people);
      },
    },
    entraId: {
      async getUserContext() { return success("Microsoft Entra ID", structuredClone(context)); },
      async getGroupHealth() { return success("Microsoft Entra ID", metrics.slice(0, 2)); },
    },
    permissions: {
      async canPerform(role, action) { return success("SharePoint permissions", permissionsByRole[role].has(action)); },
    },
    powerAutomate: {
      async listFlows() { return success("Power Automate", flows); },
      async startControlScan() { return success("Power Automate", receipt("Resolved")); },
    },
    purview: {
      async listRetentionMappings() { return success("Microsoft Purview", retention); },
      async getRecoveryStatus() { return success("Microsoft Purview", recovery); },
    },
    changeRequests: {
      async list() { return success("Change request register", structuredClone(store.changes)); },
    },
    approvals: {
      async listAssigned() { return success("Approval evidence register", structuredClone(store.approvals)); },
      async recordDecision(input) {
        const assignment = store.approvals.find((item) => item.id === input.assignmentId);
        if (!assignment) return notFound(`Approval ${input.assignmentId} was not found.`);
        if (assignment.documentRevision !== input.expectedVersion || assignment.documentETag !== input.expectedETag) {
          return { ok: false, error: { code: "CONFLICT", message: "The document changed after submission. A new review is required.", correlationId: `corr-${input.assignmentId}`, recoverable: true } };
        }
        store.approvals = store.approvals.filter((item) => item.id !== input.assignmentId);
        return success("Approval evidence register", receipt(input.outcome, input.expectedVersion, input.expectedETag));
      },
    },
    acknowledgements: {
      async listAssigned() { return success("Acknowledgement evidence register", structuredClone(store.acknowledgements)); },
      async acknowledge(input) {
        const assignment = store.acknowledgements.find((item) => item.id === input.assignmentId);
        if (!assignment) return notFound(`Acknowledgement ${input.assignmentId} was not found.`);
        if (assignment.documentRevision !== input.expectedVersion || assignment.documentETag !== input.expectedETag) {
          return { ok: false, error: { code: "CONFLICT", message: "This assignment no longer matches the current document revision.", correlationId: `corr-${input.assignmentId}`, recoverable: true } };
        }
        const evidence = receipt("Acknowledged", input.expectedVersion, input.expectedETag);
        assignment.acknowledgedAt = evidence.recordedAt;
        assignment.evidenceId = evidence.evidenceId;
        return success("Acknowledgement evidence register", evidence);
      },
    },
    audit: {
      async list(limit = 100) { return success("Unified audit", structuredClone(store.audit.slice(0, limit))); },
      async listDeployments() { return success("Deployment evidence", deployments); },
    },
    platformHealth: {
      async getSnapshot() { return success("Platform health", structuredClone(platformSnapshot())); },
      async listIntegrations() { return success("Integration register", structuredClone(store.integrations)); },
      async setIntegrationEnabled(id, enabled) {
        const integration = store.integrations.find((item) => item.id === id);
        if (!integration) return notFound(`Integration ${id} was not found.`);
        integration.enabled = enabled;
        integration.health = enabled ? "Review" : "Unknown";
        return success("Integration register", receipt("Resolved"));
      },
    },
    exceptions: {
      async listOpen() { return success("Exception register", structuredClone(store.exceptions.filter((item) => item.status === "Open"))); },
      async resolve(input) {
        const item = store.exceptions.find((exception) => exception.id === input.exceptionId);
        if (!item) return notFound(`Exception ${input.exceptionId} was not found.`);
        const evidence = receipt("Resolved");
        item.status = "Resolved";
        item.resolutionEvidenceId = evidence.evidenceId;
        return success("Exception register", evidence);
      },
    },
  };
}
