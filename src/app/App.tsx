import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { ApprovalAssignment, ControlException, ControlledDocument, DocumentDetail, EvidenceReceipt, Role } from "../domain/types";
import type { DmsServices } from "../services/contracts";
import { DmsApplication, type WorkspaceSnapshot } from "../services/application";
import { Icon } from "../components/Icon";
import { ConfirmationDialog, DetailDrawer, type ConfirmationRequest, ToastRegion, type ToastMessage } from "../components/Overlays";
import { StatePanel } from "../components/Primitives";
import { roleDefinitions, type PageId } from "./navigation";
import { RoleView } from "./views";

function countFor(workspace: WorkspaceSnapshot, key?: "acknowledgements" | "approvals" | "exceptions" | "changes"): number | undefined {
  if (!key) return undefined;
  if (key === "acknowledgements") return workspace.acknowledgements.filter((item) => !item.acknowledgedAt).length;
  return workspace[key].length;
}

function serviceError(error: unknown): { code?: string; message: string; correlationId?: string } {
  if (error && typeof error === "object" && "serviceError" in error) {
    const detail = (error as { serviceError?: { code?: string; message?: string; correlationId?: string } }).serviceError;
    return { code: detail?.code, message: detail?.message ?? "The configured service could not load this workspace.", correlationId: detail?.correlationId };
  }
  return { message: error instanceof Error ? error.message : "The document control workspace could not be loaded." };
}

export function App({ services }: { services: DmsServices }) {
  const application = useMemo(() => new DmsApplication(services), [services]);
  const [workspace, setWorkspace] = useState<WorkspaceSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<ReturnType<typeof serviceError> | null>(null);
  const [role, setRole] = useState<Role>("endUser");
  const [page, setPage] = useState<PageId>("home");
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [roleMenuOpen, setRoleMenuOpen] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(() => typeof window !== "undefined" && window.matchMedia("(max-width: 920px)").matches);
  const [detail, setDetail] = useState<DocumentDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailTrigger, setDetailTrigger] = useState<HTMLElement | null>(null);
  const [confirmation, setConfirmation] = useState<ConfirmationRequest | null>(null);
  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const appShellRef = useRef<HTMLDivElement>(null);
  const sidebarRef = useRef<HTMLElement>(null);
  const globalSearchRef = useRef<HTMLInputElement>(null);

  const addToast = useCallback((title: string, copy: string, tone: ToastMessage["tone"] = "success") => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    setToasts((current) => [...current, { id, title, copy, tone }]);
    window.setTimeout(() => setToasts((current) => current.filter((message) => message.id !== id)), 5200);
  }, []);

  const reload = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const next = await application.loadWorkspace();
      setWorkspace(next);
      setRole((current) => next.context.allowedRoles.includes(current) ? current : next.context.allowedRoles[0] ?? "endUser");
    } catch (error) {
      setLoadError(serviceError(error));
    } finally {
      setLoading(false);
    }
  }, [application]);

  useEffect(() => { void reload(); }, [reload]);

  useEffect(() => {
    const media = window.matchMedia("(max-width: 920px)");
    const update = () => { setIsMobile(media.matches); if (!media.matches) setMobileOpen(false); };
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  useEffect(() => {
    const sidebar = sidebarRef.current;
    if (!sidebar) return;
    const hidden = isMobile && !mobileOpen;
    sidebar.inert = hidden;
    sidebar.setAttribute("aria-hidden", String(hidden));
  }, [isMobile, mobileOpen]);

  useEffect(() => {
    const shell = appShellRef.current;
    if (!shell) return;
    shell.inert = Boolean(detail || detailLoading || confirmation);
    const drawer = document.querySelector<HTMLElement>(".detail-drawer");
    if (drawer) drawer.inert = Boolean(confirmation) || (!detail && !detailLoading);
  }, [detail, detailLoading, confirmation]);

  useEffect(() => {
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === "/" && !event.ctrlKey && !event.metaKey && !["INPUT", "TEXTAREA", "SELECT"].includes((document.activeElement as HTMLElement | null)?.tagName ?? "")) {
        event.preventDefault();
        globalSearchRef.current?.focus();
      }
      if (event.key === "Escape") {
        setRoleMenuOpen(false);
        setMobileOpen(false);
      }
    };
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, []);

  const navigate = useCallback((nextPage: PageId, nextQuery = "") => {
    setPage(nextPage);
    setQuery(nextQuery);
    setFilter("all");
    setRoleMenuOpen(false);
    setMobileOpen(false);
    window.scrollTo({ top: 0, behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    window.requestAnimationFrame(() => document.getElementById("main-content")?.focus({ preventScroll: true }));
  }, []);

  const switchRole = (nextRole: Role) => {
    if (!workspace?.context.allowedRoles.includes(nextRole)) return;
    setRole(nextRole);
    navigate(roleDefinitions[nextRole].start);
  };

  const openDocument = useCallback(async (document: ControlledDocument, trigger: HTMLButtonElement) => {
    setDetailTrigger(trigger);
    setDetailLoading(true);
    const result = await application.getDocument(document.id);
    setDetailLoading(false);
    if (!result.ok) {
      addToast("Document details unavailable", `${result.error.message}${result.error.correlationId ? ` Correlation: ${result.error.correlationId}` : ""}`, "error");
      return;
    }
    setDetail(result.data);
  }, [addToast, application]);

  const showReceipt = (title: string, receipt: EvidenceReceipt) => addToast(title, `${receipt.evidenceId} · correlation ${receipt.correlationId}`);

  const acknowledgeDetail = () => {
    if (!detail || !workspace) return;
    const assignment = workspace.acknowledgements.find((item) => item.documentId === detail.document.id && !item.acknowledgedAt);
    if (!assignment) return;
    setConfirmation({
      kicker: "Attestation",
      title: `Acknowledge version ${assignment.documentRevision}?`,
      copy: "You confirm that you have read and understood this controlled instruction. Your identity, exact version, ETag and timestamp will be retained.",
      actionLabel: "Record acknowledgement",
      onConfirm: async () => {
        const result = await application.acknowledge(assignment, role);
        if (!result.ok) { addToast("Acknowledgement not recorded", result.error.message, "error"); return; }
        showReceipt("Acknowledgement recorded", result.data);
        setDetail(null);
        await reload();
      },
    });
  };

  const approve = (assignment: ApprovalAssignment) => {
    setConfirmation({
      kicker: "Controlled decision",
      title: "Approve this exact release?",
      copy: `Your approval is bound to ${assignment.documentId} v${assignment.documentRevision}, ETag ${assignment.documentETag}. Any content change invalidates this decision.`,
      actionLabel: "Approve release",
      onConfirm: async () => {
        const result = await application.approve(assignment, role);
        if (!result.ok) { addToast("Approval not recorded", result.error.message, "error"); return; }
        showReceipt("Approval recorded", result.data);
        await reload();
      },
    });
  };

  const resolveException = (exception: ControlException) => {
    setConfirmation({
      kicker: "Exception remediation",
      title: "Record this exception as resolved?",
      copy: "Continue only after corrective evidence has been attached and the affected control has been re-tested. Closure creates a durable evidence receipt.",
      actionLabel: "Record resolution",
      onConfirm: async () => {
        const result = await application.resolveException(exception, role);
        if (!result.ok) { addToast("Exception not resolved", result.error.message, "error"); return; }
        showReceipt("Exception resolved", result.data);
        await reload();
      },
    });
  };

  const toggleIntegration = (id: string, enabled: boolean) => {
    setConfirmation({
      kicker: "Integration boundary",
      title: `${enabled ? "Enable" : "Disable"} this integration?`,
      copy: "A production change requires an accountable owner, impact assessment, approved credentials and a controlled deployment window.",
      actionLabel: "Record proposed change",
      onConfirm: async () => {
        const result = await application.setIntegration(id, enabled, role);
        if (!result.ok) { addToast("Integration change not recorded", result.error.message, "error"); return; }
        showReceipt("Integration change recorded", result.data);
        await reload();
      },
    });
  };

  const toggleFavourite = async () => {
    if (!detail) return;
    const result = await application.setFavourite(detail.document.id, !detail.document.isFavourite);
    if (!result.ok) { addToast("Favourite not updated", result.error.message, "error"); return; }
    const nextDetail = { ...detail, document: { ...detail.document, isFavourite: !detail.document.isFavourite } };
    setDetail(nextDetail);
    addToast(nextDetail.document.isFavourite ? "Saved to favourites" : "Removed from favourites", detail.document.id);
    await reload();
  };

  const roleDefinition = roleDefinitions[role];
  const actionUnavailable = (title: string, copy: string) => addToast(title, copy, "warning");

  return <>
    <a className="skip-link" href="#main-content">Skip to content</a>
    <div className="app-shell" ref={appShellRef}>
      <aside id="primary-sidebar" className={`sidebar ${mobileOpen ? "is-open" : ""}`} aria-label="Primary navigation" ref={sidebarRef}>
        <div className="brand-block"><div className="brand-mark" aria-hidden="true"><span/><span/><span/></div><div><p>SOL Operations</p><strong>Document Control</strong></div></div>
        <div className="role-context"><span>Working as</span><button type="button" aria-haspopup="listbox" aria-expanded={roleMenuOpen} onClick={() => setRoleMenuOpen((open) => !open)}><span className="role-glyph" aria-hidden="true">{roleDefinition.glyph}</span><span><strong>{roleDefinition.label}</strong><small>{roleDefinition.caption}</small></span><Icon name="arrow"/></button>{roleMenuOpen && <div className="role-menu" role="listbox" aria-label="Select working role">{workspace?.context.allowedRoles.map((allowedRole) => { const definition = roleDefinitions[allowedRole]; return <button type="button" role="option" data-role={allowedRole} aria-selected={allowedRole === role} key={allowedRole} onClick={() => switchRole(allowedRole)}><span className="role-glyph" aria-hidden="true">{definition.glyph}</span><span><strong>{definition.label}</strong><small>{definition.caption}</small></span>{allowedRole === role && <Icon name="check"/>}</button>; })}</div>}</div>
        <nav className="nav-list"><span>Workspace</span>{workspace && roleDefinition.navigation.map((item) => { const count = countFor(workspace, item.countKey); return <button type="button" data-page={item.page} className={page === item.page ? "is-active" : ""} aria-current={page === item.page ? "page" : undefined} key={item.page} onClick={() => navigate(item.page)}><Icon name={item.icon}/><span>{item.label}</span>{count ? <span className="count-badge">{count}</span> : null}</button>; })}</nav>
        <div className="sidebar-foot"><div className="control-current"><i aria-hidden="true"/><span><strong>{workspace?.setupIssues.length ? "Setup incomplete" : workspace?.staleSources.length ? "Stale control sources" : "Control checks current"}</strong><small>{workspace?.platform.lastScannedAt ? formatDateTimeSafe(workspace.platform.lastScannedAt) : "Awaiting configured sources"}</small></span></div><button type="button" className="sidebar-help" onClick={() => actionUnavailable("Help and glossary", "Configure the role-aware help and service-support route for this environment.")}><Icon name="help"/>Help and glossary</button></div>
      </aside>
      <section className="workspace">
        <header className="topbar"><button className="icon-button mobile-menu" type="button" aria-label="Open navigation" aria-controls="primary-sidebar" aria-expanded={mobileOpen} onClick={() => setMobileOpen((open) => !open)}><Icon name="menu"/></button><form className="global-search" role="search" onSubmit={(event) => { event.preventDefault(); const input = event.currentTarget.elements.namedItem("query") as HTMLInputElement; setRole("endUser"); navigate("library", input.value); }}><Icon name="search"/><label className="sr-only" htmlFor="global-search">Search controlled documents</label><input id="global-search" name="query" type="search" placeholder="Search by title, document ID, process or owner" ref={globalSearchRef}/><kbd>/</kbd></form><div className="topbar-actions"><button className="icon-button notification-button" type="button" aria-label="Notifications" onClick={() => actionUnavailable("Notifications", "Configure Microsoft Graph or Teams notification sources for this tenant.")}><Icon name="bell"/><span>{workspace ? workspace.acknowledgements.filter((item) => !item.acknowledgedAt).length + workspace.approvals.length : 0}</span></button><button className="profile-button" type="button" onClick={() => actionUnavailable("Account menu", "Identity and account actions are managed by Microsoft Entra ID.")}><span>{workspace ? initialsSafe(workspace.context.user.displayName) : "—"}</span><span><strong>{workspace?.context.user.displayName ?? "Loading identity"}</strong><small>{workspace?.context.department ?? "Microsoft 365"}</small></span></button></div></header>
        <main id="main-content" tabIndex={-1}>{loading && !workspace ? <StatePanel state="loading" title="Loading controlled workspace" copy="Reading permission-trimmed documents and evidence from configured service boundaries."/> : loadError ? <StatePanel state={loadError.code === "UNCONFIGURED" ? "unconfigured" : loadError.code === "PERMISSION_DENIED" ? "permission" : "error"} title={loadError.code === "UNCONFIGURED" ? "Tenant services are not configured" : loadError.code === "PERMISSION_DENIED" ? "This role does not have access" : "The controlled workspace could not be loaded"} copy={`${loadError.message}${loadError.correlationId ? ` Correlation: ${loadError.correlationId}` : ""}`} action={<button type="button" className="button button--primary" onClick={() => void reload()}>Try again</button>}/> : workspace ? <><RoleView page={page} role={role} workspace={workspace} query={query} setQuery={setQuery} filter={filter} setFilter={setFilter} navigate={navigate} openDocument={openDocument} approve={approve} resolveException={resolveException} toggleIntegration={toggleIntegration} actionUnavailable={actionUnavailable}/>{workspace.setupIssues.length > 0 && <StatePanel state="unconfigured" title="Tenant integration setup is incomplete" copy={`${workspace.setupIssues.map((issue) => issue.source).join(", ")} ${workspace.setupIssues.length === 1 ? "is" : "are"} not configured. The signed-in end-user shell remains available; administrator roles and governed actions remain fail-closed until their production services are connected.`}/>} {workspace.staleSources.length > 0 && <StatePanel state="stale" title="Some sources are stale" copy={`Last known data is shown for: ${workspace.staleSources.join(", ")}. Governed actions still revalidate against production services.`}/>}</> : null}</main>
      </section>
    </div>
    {isMobile && <button className={`mobile-scrim ${mobileOpen ? "is-open" : ""}`} type="button" aria-label="Close navigation" onClick={() => setMobileOpen(false)}/>} 
    <DetailDrawer detail={detail} loading={detailLoading} onClose={() => { setDetail(null); setDetailLoading(false); }} onAcknowledge={detail && workspace?.acknowledgements.some((item) => item.documentId === detail.document.id && !item.acknowledgedAt) ? acknowledgeDetail : undefined} onFavourite={() => void toggleFavourite()} trigger={detailTrigger}/>
    <ConfirmationDialog request={confirmation} onClose={() => setConfirmation(null)}/>
    <ToastRegion messages={toasts} dismiss={(id) => setToasts((current) => current.filter((message) => message.id !== id))}/>
  </>;
}

function initialsSafe(name: string): string {
  return name.split(" ").map((part) => part[0]).join("").slice(0, 2).toUpperCase();
}

function formatDateTimeSafe(value: string): string {
  return new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", timeZone: "Europe/London" }).format(new Date(value));
}
