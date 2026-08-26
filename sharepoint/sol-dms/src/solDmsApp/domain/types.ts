export type Role = "endUser" | "teamAdmin" | "platformAdmin";

export type LifecycleStatus =
  | "Authoring"
  | "Rework"
  | "In review"
  | "In approval"
  | "Approved pending effective"
  | "Effective"
  | "Review due"
  | "Superseded"
  | "Withdrawn"
  | "Obsolete";

export type NativeApprovalStatus = "Draft" | "Pending" | "Approved" | "Rejected";
export type HealthStatus = "Healthy" | "Review" | "Exception" | "Stale" | "Unknown";
export type RequestStatus = "Triage" | "Impact assessment" | "Authoring" | "Approval" | "Activation" | "Closed";
export type EvidenceOutcome = "Approved" | "Rejected" | "Returned" | "Acknowledged" | "Resolved";

export interface PersonRef {
  objectId: string;
  displayName: string;
  email?: string;
}

export interface ControlledDocument {
  id: string;
  title: string;
  documentType: string;
  process: string;
  owner: PersonRef;
  businessRevision: string;
  sharePointVersion: string;
  eTag: string;
  lifecycleStatus: LifecycleStatus;
  nativeApprovalStatus: NativeApprovalStatus;
  effectiveDate?: string;
  nextReviewDate?: string;
  applicability: string[];
  classification: string;
  retentionClass?: string;
  authoritativeUrl?: string;
  supersedes?: string;
  supersededBy?: string;
  acknowledgementRequired: boolean;
  isFavourite: boolean;
  lastViewedAt?: string;
  dataUpdatedAt: string;
}

export interface LifecycleEvent {
  id: string;
  documentId: string;
  stage: "Request" | "Author" | "Review" | "Approve" | "Effective" | "Retain" | "Exception";
  title: string;
  detail: string;
  actor: PersonRef;
  occurredAt: string;
  outcome: EvidenceOutcome | "Completed" | "Scheduled";
  correlationId: string;
  version?: string;
  eTag?: string;
}

export interface DocumentDetail {
  document: ControlledDocument;
  lifecycle: LifecycleEvent[];
  versionHistory: Array<{
    businessRevision: string;
    lifecycleStatus: LifecycleStatus;
    effectiveDate?: string;
    evidenceId?: string;
  }>;
}

export interface DocumentQuery {
  text?: string;
  lifecycle?: LifecycleStatus[];
  documentTypes?: string[];
  favouritesOnly?: boolean;
  recentOnly?: boolean;
  currentOnly?: boolean;
  limit?: number;
}

export interface AcknowledgementAssignment {
  id: string;
  documentId: string;
  documentTitle: string;
  documentRevision: string;
  documentETag: string;
  assignedTo: PersonRef;
  assignedAt: string;
  dueAt: string;
  acknowledgedAt?: string;
  evidenceId?: string;
}

export interface ApprovalAssignment {
  id: string;
  documentId: string;
  documentTitle: string;
  documentRevision: string;
  documentETag: string;
  submittedBy: PersonRef;
  stage: string;
  risk: "Low" | "Medium" | "High";
  dueAt: string;
  changeSummary: string;
  priorRevision?: string;
  separationOfDutiesConfirmed: boolean;
}

export interface ChangeRequest {
  id: string;
  title: string;
  requestType: "New" | "Revision" | "Withdrawal" | "Emergency";
  justification: string;
  process: string;
  owner: PersonRef;
  stage: RequestStatus;
  createdAt: string;
  dueAt: string;
  health: "On track" | "Attention" | "Overdue";
  linkedDocumentId?: string;
}

export interface ControlException {
  id: string;
  title: string;
  scope: string;
  owner: PersonRef;
  severity: "Low" | "Medium" | "High" | "Critical";
  createdAt: string;
  correlationId: string;
  blocking: boolean;
  status: "Open" | "Resolved";
  retryCount: number;
  resolutionEvidenceId?: string;
}

export interface ManagedSite {
  id: string;
  displayName: string;
  url?: string;
  documentCount: number;
  accessModel: string;
  health: HealthStatus;
  lastScannedAt: string;
}

export interface AutomationFlow {
  id: string;
  displayName: string;
  ownership: string;
  lastRunAt?: string;
  health: HealthStatus;
  rollingRunCount: number;
  environment?: string;
}

export interface RetentionMapping {
  id: string;
  name: string;
  retention: string;
  scope: string;
  status: "Published" | "Review" | "Unconfigured";
  authority?: string;
}

export interface IntegrationBoundary {
  id: string;
  name: string;
  purpose: string;
  authentication: string;
  owner: string;
  enabled: boolean;
  health: HealthStatus;
}

export interface DeploymentRecord {
  id: string;
  environment: string;
  scope: string;
  deployedAt: string;
  result: "Successful" | "Review" | "Failed";
  evidenceId: string;
}

export interface RecoveryStatus {
  rpo?: string;
  rto?: string;
  lastExerciseAt?: string;
  lastExerciseDuration?: string;
  result: HealthStatus;
  openFindings: number;
}

export interface AuditEvent {
  id: string;
  eventType: string;
  actor: string;
  object: string;
  occurredAt: string;
  result: "Success" | "Review" | "Failed";
  correlationId: string;
  source: string;
}

export interface Metric {
  id: string;
  label: string;
  value: string;
  note: string;
  state: "positive" | "warning" | "negative" | "neutral";
  definition: string;
  updatedAt: string;
}

export interface PlatformSnapshot {
  health: HealthStatus;
  lastScannedAt?: string;
  summary: string;
  sites: ManagedSite[];
  flows: AutomationFlow[];
  retention: RetentionMapping[];
  integrations: IntegrationBoundary[];
  deployments: DeploymentRecord[];
  recovery: RecoveryStatus;
  audit: AuditEvent[];
  metrics: Metric[];
}

export interface CurrentUserContext {
  user: PersonRef;
  department?: string;
  allowedRoles: Role[];
  activeRole: Role;
}

export type DataFreshness = "current" | "stale" | "unknown";

export interface ServiceMeta {
  source: string;
  retrievedAt: string;
  freshness: DataFreshness;
  correlationId?: string;
}

export type ServiceResult<T> =
  | { ok: true; data: T; meta: ServiceMeta }
  | {
      ok: false;
      error: {
        code: "UNCONFIGURED" | "PERMISSION_DENIED" | "NOT_FOUND" | "CONFLICT" | "VALIDATION" | "UNAVAILABLE";
        message: string;
        correlationId?: string;
        recoverable: boolean;
      };
    };

export interface EvidenceReceipt {
  evidenceId: string;
  correlationId: string;
  recordedAt: string;
  outcome: EvidenceOutcome;
  boundVersion?: string;
  boundETag?: string;
}
