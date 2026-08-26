import { describe, expect, it } from "vitest";
import { createHttpServices } from "./http";
import { withSharePointIdentity } from "./sharePointBootstrap";

describe("SharePoint identity bootstrap", () => {
  it("loads a fail-closed end-user baseline without inventing admin roles", async () => {
    const services = withSharePointIdentity(
      createHttpServices({ mode: "http", endpoints: {} }),
      { id: "user-1", displayName: "David Daniel", email: "david@example.com" },
    );

    const result = await services.entraId.getUserContext();
    expect(result).toMatchObject({
      ok: true,
      data: {
        user: { objectId: "user-1", displayName: "David Daniel" },
        allowedRoles: ["endUser"],
        activeRole: "endUser",
      },
    });
  });
});
