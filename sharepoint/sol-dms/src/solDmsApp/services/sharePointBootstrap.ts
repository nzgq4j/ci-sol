import type { CurrentUserContext, PersonRef, ServiceResult } from "../domain/types";
import type { DmsServices } from "./contracts";

export interface SharePointBootstrapIdentity {
  id: string;
  displayName: string;
  email?: string;
}

function current<T>(source: string, data: T): ServiceResult<T> {
  return {
    ok: true,
    data,
    meta: {
      source,
      retrievedAt: new Date().toISOString(),
      freshness: "current",
    },
  };
}

/**
 * Supplies the signed-in SharePoint identity and the safe end-user baseline.
 *
 * Team and platform roles are deliberately not inferred from site ownership or
 * page visibility. Those roles are added only by the configured Entra service,
 * where group membership and governed permissions can be revalidated.
 */
export function withSharePointIdentity(
  services: DmsServices,
  identity: SharePointBootstrapIdentity,
): DmsServices {
  const user: PersonRef = {
    objectId: identity.id,
    displayName: identity.displayName,
    email: identity.email,
  };
  const context: CurrentUserContext = {
    user,
    allowedRoles: ["endUser"],
    activeRole: "endUser",
  };

  return {
    ...services,
    graph: {
      ...services.graph,
      getCurrentUser: async () => current("SharePoint signed-in user", user),
    },
    entraId: {
      ...services.entraId,
      getUserContext: async () => current("SharePoint end-user baseline", context),
    },
  };
}
