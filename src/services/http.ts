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
  ServiceResult,
} from "../domain/types";
import type { DmsServices } from "./contracts";

export interface OperationEndpoint {
  url: string;
  auth?: "browser" | "sharePoint" | "entra";
  resource?: string;
}

export type EndpointDefinition = string | OperationEndpoint;

export interface OperationEndpoints {
  listSites?: EndpointDefinition;
  searchDocuments?: EndpointDefinition;
  getDocumentDetail?: EndpointDefinition;
  setFavourite?: EndpointDefinition;
  listContentTypes?: EndpointDefinition;
  validateMetadata?: EndpointDefinition;
  currentUser?: EndpointDefinition;
  searchPeople?: EndpointDefinition;
  userContext?: EndpointDefinition;
  groupHealth?: EndpointDefinition;
  authorize?: EndpointDefinition;
  listFlows?: EndpointDefinition;
  startControlScan?: EndpointDefinition;
  listRetentionMappings?: EndpointDefinition;
  recoveryStatus?: EndpointDefinition;
  listChangeRequests?: EndpointDefinition;
  listApprovals?: EndpointDefinition;
  recordApproval?: EndpointDefinition;
  listAcknowledgements?: EndpointDefinition;
  recordAcknowledgement?: EndpointDefinition;
  listAudit?: EndpointDefinition;
  listDeployments?: EndpointDefinition;
  platformSnapshot?: EndpointDefinition;
  listIntegrations?: EndpointDefinition;
  setIntegration?: EndpointDefinition;
  listExceptions?: EndpointDefinition;
  resolveException?: EndpointDefinition;
}

export interface SolDmsRuntimeConfig {
  mode: "http";
  endpoints: OperationEndpoints;
}

declare global {
  interface Window {
    __SOL_DMS_CONFIG__?: SolDmsRuntimeConfig;
  }
}

export interface HttpRequestExecutor {
  execute(endpoint: OperationEndpoint, init: RequestInit): Promise<Response>;
}

const browserExecutor: HttpRequestExecutor = {
  async execute(endpoint, init) {
    const url = new URL(endpoint.url, window.location.href);
    if (endpoint.auth && endpoint.auth !== "browser") {
      throw new Error(`The ${endpoint.auth} transport is only available from the SharePoint package.`);
    }
    if (url.origin !== window.location.origin) {
      throw new Error("Browser transport is restricted to the current origin. Use an Entra-protected SPFx endpoint for cross-origin services.");
    }
    return fetch(url, { credentials: "same-origin", ...init });
  },
};

function normalizeEndpoint(endpoint: EndpointDefinition): OperationEndpoint {
  return typeof endpoint === "string" ? { url: endpoint, auth: "browser" } : endpoint;
}

class HttpTransport {
  constructor(private readonly config: SolDmsRuntimeConfig, private readonly executor: HttpRequestExecutor) {}

  async request<T>(operation: keyof OperationEndpoints, init?: RequestInit): Promise<ServiceResult<T>> {
    const configuredEndpoint = this.config.endpoints[operation];
    if (!configuredEndpoint) {
      return {
        ok: false,
        error: {
          code: "UNCONFIGURED",
          message: `The ${operation} service operation has not been configured for this SharePoint environment.`,
          recoverable: false,
        },
      };
    }
    const endpoint = normalizeEndpoint(configuredEndpoint);
    if (!endpoint.url) {
      return {
        ok: false,
        error: {
          code: "UNCONFIGURED",
          message: `The ${operation} service operation has not been configured for this SharePoint environment.`,
          recoverable: false,
        },
      };
    }
    try {
      const response = await this.executor.execute(endpoint, {
        ...init,
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...init?.headers,
        },
      });
      const correlationId = response.headers.get("request-id") ?? response.headers.get("sprequestguid") ?? undefined;
      if (!response.ok) {
        return {
          ok: false,
          error: {
            code: response.status === 401 || response.status === 403 ? "PERMISSION_DENIED" : response.status === 404 ? "NOT_FOUND" : response.status === 409 || response.status === 412 ? "CONFLICT" : "UNAVAILABLE",
            message: response.status === 401 || response.status === 403 ? "The production service denied this operation." : `The production service returned HTTP ${response.status}.`,
            correlationId,
            recoverable: response.status >= 500 || response.status === 409 || response.status === 412,
          },
        };
      }
      const body = response.status === 204 ? undefined : await response.json();
      return {
        ok: true,
        data: body as T,
        meta: {
          source: endpoint.url,
          retrievedAt: new Date().toISOString(),
          freshness: response.headers.get("x-sol-data-stale") === "true" ? "stale" : "current",
          correlationId,
        },
      };
    } catch (error) {
      return {
        ok: false,
        error: {
          code: "UNAVAILABLE",
          message: error instanceof Error ? error.message : "The production service is unavailable.",
          recoverable: true,
        },
      };
    }
  }
}

export function createHttpServices(config: SolDmsRuntimeConfig, executor: HttpRequestExecutor = browserExecutor): DmsServices {
  const http = new HttpTransport(config, executor);
  const post = <T>(operation: keyof OperationEndpoints, body?: unknown) => http.request<T>(operation, { method: "POST", body: body === undefined ? undefined : JSON.stringify(body) });
  const getWithQuery = <T>(operation: keyof OperationEndpoints, query?: Record<string, unknown>) => {
    const endpoint = config.endpoints[operation];
    if (!endpoint || !query) return http.request<T>(operation);
    const normalized = normalizeEndpoint(endpoint);
    const url = new URL(normalized.url, window.location.href);
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== "") url.searchParams.set(key, typeof value === "string" ? value : JSON.stringify(value));
    }
    const overridden = { ...config, endpoints: { ...config.endpoints, [operation]: { ...normalized, url: url.toString() } } };
    return new HttpTransport(overridden, executor).request<T>(operation);
  };

  return {
    sharePointSites: {
      listSites: () => http.request<ManagedSite[]>("listSites"),
    },
    sharePointDocuments: {
      search: (query: DocumentQuery) => getWithQuery<ControlledDocument[]>("searchDocuments", query as Record<string, unknown>),
      getDetail: (documentId: string) => getWithQuery<DocumentDetail>("getDocumentDetail", { documentId }),
      setFavourite: (documentId: string, favourite: boolean) => post<void>("setFavourite", { documentId, favourite }),
    },
    sharePointMetadata: {
      listContentTypes: () => http.request<Array<{ id: string; name: string }>>("listContentTypes"),
      validateForActivation: (document: ControlledDocument) => post<string[]>("validateMetadata", { document }),
    },
    graph: {
      getCurrentUser: () => http.request<PersonRef>("currentUser"),
      searchPeople: (query: string) => getWithQuery<PersonRef[]>("searchPeople", { query }),
    },
    entraId: {
      getUserContext: () => http.request<CurrentUserContext>("userContext"),
      getGroupHealth: () => http.request<Metric[]>("groupHealth"),
    },
    permissions: {
      canPerform: (role, action, scope) => post<boolean>("authorize", { role, action, scope }),
    },
    powerAutomate: {
      listFlows: () => http.request<AutomationFlow[]>("listFlows"),
      startControlScan: () => post<EvidenceReceipt>("startControlScan"),
    },
    purview: {
      listRetentionMappings: () => http.request<RetentionMapping[]>("listRetentionMappings"),
      getRecoveryStatus: () => http.request<RecoveryStatus>("recoveryStatus"),
    },
    changeRequests: {
      list: () => http.request<ChangeRequest[]>("listChangeRequests"),
    },
    approvals: {
      listAssigned: () => http.request<ApprovalAssignment[]>("listApprovals"),
      recordDecision: (input) => post<EvidenceReceipt>("recordApproval", input),
    },
    acknowledgements: {
      listAssigned: () => http.request<AcknowledgementAssignment[]>("listAcknowledgements"),
      acknowledge: (input) => post<EvidenceReceipt>("recordAcknowledgement", input),
    },
    audit: {
      list: (limit?: number) => getWithQuery<AuditEvent[]>("listAudit", { limit }),
      listDeployments: () => http.request<DeploymentRecord[]>("listDeployments"),
    },
    platformHealth: {
      getSnapshot: () => http.request<PlatformSnapshot>("platformSnapshot"),
      listIntegrations: () => http.request<IntegrationBoundary[]>("listIntegrations"),
      setIntegrationEnabled: (id, enabled) => post<EvidenceReceipt>("setIntegration", { id, enabled }),
    },
    exceptions: {
      listOpen: () => http.request<ControlException[]>("listExceptions"),
      resolve: (input) => post<EvidenceReceipt>("resolveException", input),
    },
  };
}
