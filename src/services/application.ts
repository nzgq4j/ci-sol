import type {
  AcknowledgementAssignment,
  ApprovalAssignment,
  ChangeRequest,
  ControlException,
  ControlledDocument,
  CurrentUserContext,
  DocumentQuery,
  EvidenceReceipt,
  PlatformSnapshot,
  ServiceResult,
} from "../domain/types";
import type { DmsServices, GovernedAction } from "./contracts";

export interface WorkspaceSnapshot {
  context: CurrentUserContext;
  documents: ControlledDocument[];
  acknowledgements: AcknowledgementAssignment[];
  approvals: ApprovalAssignment[];
  changes: ChangeRequest[];
  exceptions: ControlException[];
  platform: PlatformSnapshot;
  staleSources: string[];
  setupIssues: WorkspaceSetupIssue[];
}

export interface WorkspaceSetupIssue {
  source: string;
  message: string;
}

function valueOrThrow<T>(result: ServiceResult<T>): T {
  if (!result.ok) throw Object.assign(new Error(result.error.message), { serviceError: result.error });
  return result.data;
}

function sourceIsStale<T>(result: ServiceResult<T>): string | undefined {
  return result.ok && result.meta.freshness !== "current" ? result.meta.source : undefined;
}

function optionalValue<T>(
  source: string,
  result: ServiceResult<T>,
  fallback: T,
  setupIssues: WorkspaceSetupIssue[],
): T {
  if (result.ok) return result.data;
  if (result.error.code !== "UNCONFIGURED") {
    throw Object.assign(new Error(result.error.message), { serviceError: result.error });
  }
  setupIssues.push({ source, message: result.error.message });
  return fallback;
}

function unconfiguredPlatform(): PlatformSnapshot {
  return {
    health: "Unknown",
    summary: "Platform assurance sources have not been configured.",
    sites: [],
    flows: [],
    retention: [],
    integrations: [],
    deployments: [],
    recovery: { result: "Unknown", openFindings: 0 },
    audit: [],
    metrics: [],
  };
}

export class DmsApplication {
  constructor(private readonly services: DmsServices) {}

  async loadWorkspace(): Promise<WorkspaceSnapshot> {
    const setupIssues: WorkspaceSetupIssue[] = [];
    const [context, documents, acknowledgements, approvals, changes, exceptions, platform] = await Promise.all([
      this.services.entraId.getUserContext(),
      this.services.sharePointDocuments.search({}),
      this.services.acknowledgements.listAssigned(),
      this.services.approvals.listAssigned(),
      this.services.changeRequests.list(),
      this.services.exceptions.listOpen(),
      this.services.platformHealth.getSnapshot(),
    ]);
    return {
      context: valueOrThrow(context),
      // Identity is required to establish a safe baseline role. The remaining
      // read models are independently optional during tenant commissioning so
      // one missing integration cannot blank the entire application shell.
      // Governed writes continue to fail closed at their service boundaries.
      documents: optionalValue("Controlled Documents", documents, [], setupIssues),
      acknowledgements: optionalValue("Acknowledgement Evidence", acknowledgements, [], setupIssues),
      approvals: optionalValue("Approval Evidence", approvals, [], setupIssues),
      changes: optionalValue("Change Requests", changes, [], setupIssues),
      exceptions: optionalValue("Exception Register", exceptions, [], setupIssues),
      platform: optionalValue("Platform assurance", platform, unconfiguredPlatform(), setupIssues),
      staleSources: [
        sourceIsStale(context),
        sourceIsStale(documents),
        sourceIsStale(acknowledgements),
        sourceIsStale(approvals),
        sourceIsStale(changes),
        sourceIsStale(exceptions),
        sourceIsStale(platform),
      ].filter((source): source is string => Boolean(source)),
      setupIssues,
    };
  }

  searchDocuments(query: DocumentQuery) {
    return this.services.sharePointDocuments.search(query);
  }

  getDocument(documentId: string) {
    return this.services.sharePointDocuments.getDetail(documentId);
  }

  setFavourite(documentId: string, favourite: boolean) {
    return this.services.sharePointDocuments.setFavourite(documentId, favourite);
  }

  async acknowledge(assignment: AcknowledgementAssignment, role: CurrentUserContext["activeRole"]): Promise<ServiceResult<EvidenceReceipt>> {
    const access = await this.authorize(role, "acknowledgeDocument", assignment.documentId);
    if (!access.ok) return access;
    return this.services.acknowledgements.acknowledge({
      assignmentId: assignment.id,
      documentId: assignment.documentId,
      expectedVersion: assignment.documentRevision,
      expectedETag: assignment.documentETag,
    });
  }

  async approve(assignment: ApprovalAssignment, role: CurrentUserContext["activeRole"]): Promise<ServiceResult<EvidenceReceipt>> {
    const access = await this.authorize(role, "approveDocument", assignment.documentId);
    if (!access.ok) return access;
    return this.services.approvals.recordDecision({
      assignmentId: assignment.id,
      expectedVersion: assignment.documentRevision,
      expectedETag: assignment.documentETag,
      outcome: "Approved",
      comments: "Approved through the controlled SOL decision experience.",
    });
  }

  async resolveException(exception: ControlException, role: CurrentUserContext["activeRole"]): Promise<ServiceResult<EvidenceReceipt>> {
    const access = await this.authorize(role, "resolveException", exception.scope);
    if (!access.ok) return access;
    return this.services.exceptions.resolve({
      exceptionId: exception.id,
      resolution: "Corrective evidence attached and control re-tested.",
    });
  }

  async setIntegration(id: string, enabled: boolean, role: CurrentUserContext["activeRole"]): Promise<ServiceResult<EvidenceReceipt>> {
    const access = await this.authorize(role, "administerPlatform", id);
    if (!access.ok) return access;
    return this.services.platformHealth.setIntegrationEnabled(id, enabled);
  }

  private async authorize(role: CurrentUserContext["activeRole"], action: GovernedAction, scope?: string): Promise<ServiceResult<boolean>> {
    const result = await this.services.permissions.canPerform(role, action, scope);
    if (!result.ok) return result;
    if (!result.data) {
      return {
        ok: false,
        error: {
          code: "PERMISSION_DENIED",
          message: "Your current role is not authorised to perform this governed action.",
          recoverable: false,
        },
      };
    }
    return result;
  }
}
