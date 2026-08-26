import { describe, expect, it } from "vitest";
import type { ControlledDocument, LifecycleStatus } from "./types";
import { assertTransition, canTransition, ensureSingleEffectiveRevision, isReaderVisible, validateEffectiveDocument } from "./lifecycle";

function document(status: LifecycleStatus, overrides: Partial<ControlledDocument> = {}): ControlledDocument {
  return {
    id: "SOP-001",
    title: "Controlled test",
    documentType: "SOP",
    process: "Quality",
    owner: { objectId: "owner-1", displayName: "Owner" },
    businessRevision: "1.0",
    sharePointVersion: "1.0",
    eTag: '"etag-1"',
    lifecycleStatus: status,
    nativeApprovalStatus: "Approved",
    effectiveDate: "2026-08-01",
    nextReviewDate: "2027-08-01",
    applicability: ["Operations"],
    classification: "Internal",
    retentionClass: "Approved mapping",
    acknowledgementRequired: false,
    isFavourite: false,
    dataUpdatedAt: "2026-08-01T00:00:00Z",
    ...overrides,
  };
}

describe("controlled document lifecycle", () => {
  it("permits only declared transitions", () => {
    expect(canTransition("In review", "In approval")).toBe(true);
    expect(canTransition("Effective", "Authoring")).toBe(false);
    expect(() => assertTransition("Effective", "Authoring")).toThrow(/Invalid lifecycle transition/);
  });

  it("shows only effective and review-due releases to readers", () => {
    expect(isReaderVisible(document("Effective"))).toBe(true);
    expect(isReaderVisible(document("Review due"))).toBe(true);
    expect(isReaderVisible(document("In approval"))).toBe(false);
  });

  it("requires complete control metadata for an effective release", () => {
    expect(validateEffectiveDocument(document("Effective"))).toEqual([]);
    expect(validateEffectiveDocument(document("Effective", { owner: { objectId: "", displayName: "Unowned" }, eTag: "", retentionClass: undefined }))).toEqual([
      "An active document owner is required",
      "Retention mapping is required",
      "A version ETag is required",
    ]);
  });

  it("rejects zero or multiple reader-visible revisions", () => {
    expect(() => ensureSingleEffectiveRevision([document("Authoring")], "SOP-001")).toThrow(/found 0/);
    expect(() => ensureSingleEffectiveRevision([document("Effective"), document("Review due")], "SOP-001")).toThrow(/found 2/);
    expect(() => ensureSingleEffectiveRevision([document("Effective")], "SOP-001")).not.toThrow();
  });
});
