import { describe, expect, it, vi } from "vitest";
import { createHttpServices, type HttpRequestExecutor, type OperationEndpoint } from "./http";

describe("configured HTTP service boundary", () => {
  it("preserves typed auth metadata and query values for the host executor", async () => {
    let observed: OperationEndpoint | undefined;
    const executor: HttpRequestExecutor = {
      execute: vi.fn(async (endpoint) => {
        observed = endpoint;
        return new Response(JSON.stringify([]), { status: 200, headers: { "Content-Type": "application/json" } });
      }),
    };
    const services = createHttpServices({
      mode: "http",
      endpoints: {
        searchDocuments: { url: "/api/documents", auth: "entra", resource: "api://approved-resource" },
      },
    }, executor);
    const result = await services.sharePointDocuments.search({ text: "incident", currentOnly: true });
    expect(result.ok).toBe(true);
    expect(observed).toMatchObject({ auth: "entra", resource: "api://approved-resource" });
    expect(new URL(observed?.url ?? "", window.location.href).searchParams.get("text")).toBe("incident");
  });

  it("returns an explicit unconfigured state instead of mock data", async () => {
    const services = createHttpServices({ mode: "http", endpoints: {} });
    const result = await services.entraId.getUserContext();
    expect(result).toMatchObject({ ok: false, error: { code: "UNCONFIGURED" } });
  });
});
