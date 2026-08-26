import type { ControlledDocument, LifecycleStatus } from "./types";

export const lifecycleOrder: LifecycleStatus[] = [
  "Authoring",
  "In review",
  "In approval",
  "Approved pending effective",
  "Effective",
  "Review due",
  "Superseded",
  "Withdrawn",
  "Obsolete",
];

const transitions: Record<LifecycleStatus, ReadonlySet<LifecycleStatus>> = {
  Authoring: new Set<LifecycleStatus>(["In review", "Withdrawn"]),
  Rework: new Set<LifecycleStatus>(["Authoring", "In review", "Withdrawn"]),
  "In review": new Set<LifecycleStatus>(["In approval", "Rework", "Withdrawn"]),
  "In approval": new Set<LifecycleStatus>(["Approved pending effective", "Rework", "Withdrawn"]),
  "Approved pending effective": new Set<LifecycleStatus>(["Effective", "Rework", "Withdrawn"]),
  Effective: new Set<LifecycleStatus>(["Review due", "Superseded", "Withdrawn"]),
  "Review due": new Set<LifecycleStatus>(["Effective", "Authoring", "Superseded", "Withdrawn"]),
  Superseded: new Set<LifecycleStatus>(["Obsolete"]),
  Withdrawn: new Set<LifecycleStatus>(["Obsolete"]),
  Obsolete: new Set<LifecycleStatus>(),
};

export function canTransition(from: LifecycleStatus, to: LifecycleStatus): boolean {
  return transitions[from].has(to);
}

export function assertTransition(from: LifecycleStatus, to: LifecycleStatus): void {
  if (!canTransition(from, to)) {
    throw new Error(`Invalid lifecycle transition: ${from} → ${to}`);
  }
}

export function isReaderVisible(document: ControlledDocument): boolean {
  return document.lifecycleStatus === "Effective" || document.lifecycleStatus === "Review due";
}

export function validateEffectiveDocument(document: ControlledDocument): string[] {
  const failures: string[] = [];
  if (!isReaderVisible(document)) return failures;
  if (document.nativeApprovalStatus !== "Approved") failures.push("Native approval status must be Approved");
  if (!document.owner?.objectId) failures.push("An active document owner is required");
  if (!document.effectiveDate) failures.push("An effective date is required");
  if (!document.nextReviewDate) failures.push("A next review date is required");
  if (!document.applicability.length) failures.push("Applicability is required");
  if (!document.classification) failures.push("Classification is required");
  if (!document.retentionClass) failures.push("Retention mapping is required");
  if (!document.eTag) failures.push("A version ETag is required");
  return failures;
}

export function ensureSingleEffectiveRevision(documents: ControlledDocument[], documentId: string): void {
  const current = documents.filter(
    (document) => document.id === documentId && isReaderVisible(document),
  );
  if (current.length !== 1) {
    throw new Error(`${documentId} must have exactly one current effective revision; found ${current.length}`);
  }
}
