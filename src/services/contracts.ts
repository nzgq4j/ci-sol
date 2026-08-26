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
  DocumentQuery,
  EvidenceReceipt,
  IntegrationBoundary,
  ManagedSite,
  Metric,
  PersonRef,
  PlatformSnapshot,
  RecoveryStatus,
  RetentionMapping,
  Role,
  ServiceResult,
} from "../domain/types";

export interface SharePointSitesAdapter {
  listSites(): Promise<ServiceResult<ManagedSite[]>>;
}

export interface SharePointDocumentsAdapter {
  search(query: DocumentQuery): Promise<ServiceResult<ControlledDocument[]>>;
  getDetail(documentId: string): Promise<ServiceResult<DocumentDetail>>;
  setFavourite(documentId: string, favourite: boolean): Promise<ServiceResult<void>>;
}

export interface SharePointMetadataAdapter {
  listContentTypes(): Promise<ServiceResult<Array<{ id: string; name: string }>>>;
  validateForActivation(document: ControlledDocument): Promise<ServiceResult<string[]>>;
}

export interface MicrosoftGraphAdapter {
  getCurrentUser(): Promise<ServiceResult<PersonRef>>;
  searchPeople(query: string): Promise<ServiceResult<PersonRef[]>>;
}

export interface EntraIdAdapter {
  getUserContext(): Promise<ServiceResult<CurrentUserContext>>;
  getGroupHealth(): Promise<ServiceResult<Metric[]>>;
}

export interface SharePointPermissionsAdapter {
  canPerform(role: Role, action: GovernedAction, scope?: string): Promise<ServiceResult<boolean>>;
}

export type GovernedAction =
  | "readCurrentDocument"
  | "acknowledgeDocument"
  | "approveDocument"
  | "resolveException"
  | "administerRetention"
  | "administerPlatform";

export interface PowerAutomateAdapter {
  listFlows(): Promise<ServiceResult<AutomationFlow[]>>;
  startControlScan(): Promise<ServiceResult<EvidenceReceipt>>;
}

export interface MicrosoftPurviewAdapter {
  listRetentionMappings(): Promise<ServiceResult<RetentionMapping[]>>;
  getRecoveryStatus(): Promise<ServiceResult<RecoveryStatus>>;
}

export interface ChangeRequestsAdapter {
  list(): Promise<ServiceResult<ChangeRequest[]>>;
}

export interface ApprovalEvidenceAdapter {
  listAssigned(): Promise<ServiceResult<ApprovalAssignment[]>>;
  recordDecision(input: {
    assignmentId: string;
    expectedVersion: string;
    expectedETag: string;
    outcome: "Approved" | "Rejected" | "Returned";
    comments: string;
  }): Promise<ServiceResult<EvidenceReceipt>>;
}

export interface AcknowledgementEvidenceAdapter {
  listAssigned(): Promise<ServiceResult<AcknowledgementAssignment[]>>;
  acknowledge(input: {
    assignmentId: string;
    documentId: string;
    expectedVersion: string;
    expectedETag: string;
  }): Promise<ServiceResult<EvidenceReceipt>>;
}

export interface AuditRecordsAdapter {
  list(limit?: number): Promise<ServiceResult<AuditEvent[]>>;
  listDeployments(): Promise<ServiceResult<DeploymentRecord[]>>;
}

export interface PlatformHealthAdapter {
  getSnapshot(): Promise<ServiceResult<PlatformSnapshot>>;
  listIntegrations(): Promise<ServiceResult<IntegrationBoundary[]>>;
  setIntegrationEnabled(id: string, enabled: boolean): Promise<ServiceResult<EvidenceReceipt>>;
}

export interface ExceptionRecordsAdapter {
  listOpen(): Promise<ServiceResult<ControlException[]>>;
  resolve(input: { exceptionId: string; resolution: string }): Promise<ServiceResult<EvidenceReceipt>>;
}

export interface DmsServices {
  sharePointSites: SharePointSitesAdapter;
  sharePointDocuments: SharePointDocumentsAdapter;
  sharePointMetadata: SharePointMetadataAdapter;
  graph: MicrosoftGraphAdapter;
  entraId: EntraIdAdapter;
  permissions: SharePointPermissionsAdapter;
  powerAutomate: PowerAutomateAdapter;
  purview: MicrosoftPurviewAdapter;
  changeRequests: ChangeRequestsAdapter;
  approvals: ApprovalEvidenceAdapter;
  acknowledgements: AcknowledgementEvidenceAdapter;
  audit: AuditRecordsAdapter;
  platformHealth: PlatformHealthAdapter;
  exceptions: ExceptionRecordsAdapter;
}
