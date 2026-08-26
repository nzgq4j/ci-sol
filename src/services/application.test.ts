import { describe, expect, it } from "vitest";
import { DmsApplication } from "./application";
import { createDemoServices } from "./demo";

describe("DmsApplication governed actions", () => {
  it("loads all three role workspaces through typed boundaries", async () => {
    const snapshot = await new DmsApplication(createDemoServices()).loadWorkspace();
    expect(snapshot.context.allowedRoles).toEqual(["endUser", "teamAdmin", "platformAdmin"]);
    expect(snapshot.documents.length).toBeGreaterThan(0);
    expect(snapshot.platform.sites.length).toBeGreaterThan(0);
    expect(snapshot.staleSources).toEqual([]);
  });

  it("records acknowledgement against the exact version and ETag", async () => {
    const application = new DmsApplication(createDemoServices());
    const before = await application.loadWorkspace();
    const assignment = before.acknowledgements[0];
    const result = await application.acknowledge(assignment, "endUser");
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.outcome).toBe("Acknowledged");
      expect(result.data.boundVersion).toBe(assignment.documentRevision);
      expect(result.data.boundETag).toBe(assignment.documentETag);
    }
    const after = await application.loadWorkspace();
    expect(after.acknowledgements.find((item) => item.id === assignment.id)?.evidenceId).toBeTruthy();
  });

  it("enforces role authorisation before a governed adapter call", async () => {
    const application = new DmsApplication(createDemoServices());
    const assignment = (await application.loadWorkspace()).approvals[0];
    const denied = await application.approve(assignment, "endUser");
    expect(denied).toMatchObject({ ok: false, error: { code: "PERMISSION_DENIED" } });
    const allowed = await application.approve(assignment, "teamAdmin");
    expect(allowed.ok).toBe(true);
  });

  it("removes resolved exceptions from the open register", async () => {
    const application = new DmsApplication(createDemoServices());
    const before = await application.loadWorkspace();
    const resolved = await application.resolveException(before.exceptions[0], "teamAdmin");
    expect(resolved.ok).toBe(true);
    const after = await application.loadWorkspace();
    expect(after.exceptions).toHaveLength(before.exceptions.length - 1);
  });
});
