import React, { useCallback, useEffect, useLayoutEffect, useRef } from "react";
import type { DocumentDetail } from "../domain/types";
import { Button, formatDate, LifecycleSpine, StatusBadge } from "./Primitives";
import { Icon } from "./Icon";

function focusable(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])')).filter((element) => element.getClientRects().length > 0 || element === document.activeElement);
}

function useFocusTrap(open: boolean, onEscape: () => void, returnFocus?: HTMLElement | null) {
  const ref = useRef<HTMLElement | null>(null);
  const escapeRef = useRef(onEscape);
  const assignRef = useCallback((element: HTMLElement | null) => {
    ref.current = element;
    if (open && element) {
      window.setTimeout(() => {
        const elements = focusable(element);
        (elements[0] ?? element).focus();
      }, 0);
    }
  }, [open]);
  useEffect(() => { escapeRef.current = onEscape; }, [onEscape]);
  useLayoutEffect(() => {
    if (!open || !ref.current) return;
    const container = ref.current;
    const focusFrame = window.requestAnimationFrame(() => {
      const elements = focusable(container);
      (elements[0] ?? container).focus();
    });
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        escapeRef.current();
        return;
      }
      if (event.key !== "Tab") return;
      const current = focusable(container);
      if (!current.length) return;
      const first = current[0];
      const last = current[current.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    document.addEventListener("keydown", onKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("keydown", onKeyDown);
      if (returnFocus) window.requestAnimationFrame(() => returnFocus.focus());
    };
  }, [open, returnFocus]);
  return assignRef;
}

export interface ConfirmationRequest {
  kicker: string;
  title: string;
  copy: string;
  actionLabel: string;
  dangerous?: boolean;
  onConfirm: () => Promise<void> | void;
}

export function ConfirmationDialog({ request, onClose }: { request: ConfirmationRequest | null; onClose: () => void }) {
  const ref = useFocusTrap(Boolean(request), onClose);
  if (!request) return null;
  return <div className="overlay overlay--dialog" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><div className="confirm-dialog" role="alertdialog" aria-modal="true" aria-labelledby="confirm-title" aria-describedby="confirm-copy" tabIndex={-1} ref={ref}><span className="eyebrow">{request.kicker}</span><h2 id="confirm-title">{request.title}</h2><p id="confirm-copy">{request.copy}</p><div className="confirm-dialog__actions"><Button onClick={onClose}>Cancel</Button><Button kind={request.dangerous ? "danger" : "primary"} onClick={async () => { await request.onConfirm(); onClose(); }}>{request.actionLabel}</Button></div></div></div>;
}

export function DetailDrawer({ detail, loading, onClose, onAcknowledge, onFavourite, trigger }: { detail: DocumentDetail | null; loading: boolean; onClose: () => void; onAcknowledge?: () => void; onFavourite: () => void; trigger?: HTMLElement | null }) {
  const open = loading || Boolean(detail);
  const ref = useFocusTrap(open, onClose, trigger);
  const document = detail?.document;
  return <><div className={`drawer-scrim ${open ? "is-open" : ""}`} aria-hidden="true" hidden={!open} onMouseDown={onClose}/><aside className={`detail-drawer ${open ? "is-open" : ""}`} aria-hidden={!open} hidden={!open} aria-labelledby="drawer-title" tabIndex={-1} ref={ref}><header className="drawer-head"><button className="icon-button drawer-close" type="button" aria-label="Close document details" onClick={onClose}><Icon name="close"/></button>{loading || !document ? <><span className="eyebrow">Controlled document</span><h2 id="drawer-title">Loading document evidence…</h2></> : <><span className="eyebrow">{document.documentType} · {document.id}</span><h2 id="drawer-title">{document.title}</h2><div className="drawer-head__actions">{onAcknowledge ? <Button kind="primary" icon="check" onClick={onAcknowledge}>Acknowledge v{document.businessRevision}</Button> : <Button kind="primary" icon="external" onClick={() => document.authoritativeUrl ? window.open(document.authoritativeUrl, "_blank", "noopener,noreferrer") : undefined} disabled={!document.authoritativeUrl}>Open document</Button>}<Button kind="ghost" icon="star" onClick={onFavourite}>{document.isFavourite ? "Saved" : "Save"}</Button></div></>}</header>{detail && document && <div className="drawer-body"><section className="drawer-section"><div className="drawer-release"><div><span className="eyebrow">Current controlled release</span><h3>Version {document.businessRevision}</h3></div><StatusBadge value={document.lifecycleStatus}/></div><p>This is the authoritative release for {document.process.toLowerCase()}. Printed or downloaded copies may become uncontrolled.</p>{!document.authoritativeUrl && <p className="inline-notice">The authoritative SharePoint file URL is not configured in this environment.</p>}</section><section className="drawer-section"><h3>Control metadata</h3><dl className="metadata-grid"><div><dt>Document owner</dt><dd>{document.owner.displayName}</dd></div><div><dt>Business process</dt><dd>{document.process}</dd></div><div><dt>Effective date</dt><dd>{formatDate(document.effectiveDate)}</dd></div><div><dt>Next review</dt><dd>{formatDate(document.nextReviewDate)}</dd></div><div><dt>Classification</dt><dd>{document.classification}</dd></div><div><dt>Record label</dt><dd>{document.retentionClass ?? "Unconfigured"}</dd></div><div><dt>SharePoint version</dt><dd><code>{document.sharePointVersion}</code></dd></div><div><dt>Evidence ETag</dt><dd><code>{document.eTag}</code></dd></div></dl></section><section className="drawer-section"><h3>Lifecycle evidence</h3><LifecycleSpine events={detail.lifecycle}/></section><section className="drawer-section"><h3>Version history</h3><div className="version-list">{detail.versionHistory.map((version) => <div className="version-row" key={`${version.businessRevision}-${version.lifecycleStatus}`}><code>v{version.businessRevision}</code><span><strong>{version.lifecycleStatus === document.lifecycleStatus ? "Current release" : "Historical release"}</strong><small>{version.evidenceId ?? "Evidence reference unavailable"}</small></span><StatusBadge value={version.lifecycleStatus}/></div>)}</div></section></div>}</aside></>;
}

export interface ToastMessage {
  id: string;
  title: string;
  copy: string;
  tone?: "success" | "warning" | "error";
}

export function ToastRegion({ messages, dismiss }: { messages: ToastMessage[]; dismiss: (id: string) => void }) {
  return <div className="toast-region" aria-live="polite" aria-atomic="false">{messages.map((message) => <div className={`toast toast--${message.tone ?? "success"}`} role={message.tone === "error" ? "alert" : "status"} key={message.id}><span className="toast__mark" aria-hidden="true"><Icon name={message.tone === "error" ? "alert" : "check"}/></span><span><strong>{message.title}</strong><small>{message.copy}</small></span><button type="button" aria-label="Dismiss notification" onClick={() => dismiss(message.id)}><Icon name="close"/></button></div>)}</div>;
}
