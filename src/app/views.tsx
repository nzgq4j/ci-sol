import React, { useMemo } from "react";
import type {
  ApprovalAssignment,
  ControlException,
  ControlledDocument,
  Metric,
  PlatformSnapshot,
  Role,
} from "../domain/types";
import type { WorkspaceSnapshot } from "../services/application";
import type { PageId } from "./navigation";
import {
  Button,
  DataTable,
  DocumentRows,
  EmptyState,
  formatDate,
  formatDateTime,
  MetricsStrip,
  PageHeading,
  Panel,
  Person,
  StatusBadge,
} from "../components/Primitives";
import { Icon } from "../components/Icon";

export interface ViewProps {
  page: PageId;
  role: Role;
  workspace: WorkspaceSnapshot;
  query: string;
  setQuery: (query: string) => void;
  filter: string;
  setFilter: (filter: string) => void;
  navigate: (page: PageId, query?: string) => void;
  openDocument: (document: ControlledDocument, trigger: HTMLButtonElement) => void;
  approve: (approval: ApprovalAssignment) => void;
  resolveException: (exception: ControlException) => void;
  toggleIntegration: (id: string, enabled: boolean) => void;
  actionUnavailable: (title: string, copy: string) => void;
}

const currentDocuments = (documents: ControlledDocument[]) => documents.filter((document) => ["Effective", "Review due"].includes(document.lifecycleStatus));

function ViewAction({ children, onClick, icon }: { children: React.ReactNode; onClick: () => void; icon?: string }) {
  return <Button kind="primary" icon={icon} onClick={onClick}>{children}</Button>;
}

function TextRoute({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  return <button type="button" className="text-route" onClick={onClick}>{children}<Icon name="arrow"/></button>;
}

function TrustHero({ onSearch, assurance }: { onSearch: (value: string) => void; assurance: Metric | undefined }) {
  return <section className="trust-hero"><div className="trust-hero__main"><span className="eyebrow">Controlled knowledge · verified now</span><h1>Find the instruction<br/>you can act on.</h1><p>Search approved, effective guidance. Every result carries an owner, version and evidence trail.</p><form className="hero-search" role="search" onSubmit={(event) => { event.preventDefault(); const input = event.currentTarget.elements.namedItem("heroQuery") as HTMLInputElement; onSearch(input.value); }}><Icon name="search"/><label className="sr-only" htmlFor="hero-query">Search current guidance</label><input id="hero-query" name="heroQuery" type="search" placeholder="What do you need to do?"/><Button kind="primary" type="submit">Search</Button></form></div><aside className="trust-hero__aside" aria-label="Library assurance"><div><span>Library assurance</span><strong>{assurance?.value ?? "Unknown"}</strong><p>{assurance?.note ?? "The control completeness source is unavailable."}</p></div><div className="assurance-updated"><span aria-hidden="true"/><span>Control evidence<br/><strong>{assurance ? `Updated ${formatDateTime(assurance.updatedAt)}` : "Not configured"}</strong></span></div></aside></section>;
}

function ObligationList({ workspace, openDocument }: Pick<ViewProps, "workspace" | "openDocument">) {
  const outstanding = workspace.acknowledgements.filter((assignment) => !assignment.acknowledgedAt);
  if (!outstanding.length) return <EmptyState title="You are up to date" copy="There are no outstanding acknowledgements."/>;
  return <div className="obligation-list">{outstanding.map((assignment) => {
    const document = workspace.documents.find((item) => item.id === assignment.documentId);
    return <button type="button" className="obligation-item" key={assignment.id} onClick={(event) => document && openDocument(document, event.currentTarget)}><time className="due-tile" dateTime={assignment.dueAt}><strong>{formatDate(assignment.dueAt, { day: "2-digit", timeZone: "Europe/London" })}</strong><span>{formatDate(assignment.dueAt, { month: "short", timeZone: "Europe/London" })}</span></time><span><strong>Acknowledge {document?.documentType.toLowerCase() ?? "document"}</strong><small>{assignment.documentTitle}</small></span><Icon name="arrow"/></button>;
  })}</div>;
}

function UserHome(props: ViewProps) {
  const docs = currentDocuments(props.workspace.documents).slice(0, 4);
  const assurance = props.workspace.platform.metrics.find((metric) => metric.id === "MET-001");
  return <><TrustHero assurance={assurance} onSearch={(value) => props.navigate("library", value)}/><div className="grid grid--2-1"><Panel title="Current and recently used" subtitle="Approved documents from your work context" action={<TextRoute onClick={() => props.navigate("library")}>View library</TextRoute>} flush><DocumentRows documents={docs} onOpen={props.openDocument}/></Panel><div className="stack"><Panel title="Your obligations" subtitle={`${props.workspace.acknowledgements.filter((item) => !item.acknowledgedAt).length} actions need your attention`} flush><ObligationList workspace={props.workspace} openDocument={props.openDocument}/></Panel><Panel title="Common tasks" subtitle="Direct routes into governed work" flush><div className="quick-links"><button type="button" onClick={() => props.navigate("library")}><Icon name="library"/><strong>Browse processes</strong><span>Explore the controlled library</span><Icon name="arrow"/></button><button type="button" onClick={() => props.actionUnavailable("Change request entry", "Configure the tenant change-request form or Power App endpoint before production use.")}><Icon name="change"/><strong>Suggest a change</strong><span>Flag unclear or outdated guidance</span><Icon name="arrow"/></button><button type="button" onClick={() => props.actionUnavailable("Document issue route", "Configure the support and exception intake route for this tenant.")}><Icon name="alert"/><strong>Report an issue</strong><span>Tell document control</span><Icon name="arrow"/></button></div></Panel></div></div></>;
}

const filterOptions = [
  ["all", "All"],
  ["effective", "Effective"],
  ["review-due", "Review due"],
  ["sop", "SOPs"],
  ["policy", "Policies"],
];

function LibraryView(props: ViewProps, mode: "library" | "favourites" | "recent") {
  let documents = currentDocuments(props.workspace.documents);
  if (mode === "favourites") documents = documents.filter((document) => document.isFavourite);
  if (mode === "recent") documents = props.workspace.documents.filter((document) => Boolean(document.lastViewedAt)).sort((a, b) => (b.lastViewedAt ?? "").localeCompare(a.lastViewedAt ?? ""));
  const query = props.query.trim().toLowerCase();
  documents = documents.filter((document) => {
    const filterMatches = props.filter === "all" || document.lifecycleStatus.toLowerCase().replaceAll(" ", "-") === props.filter || document.documentType.toLowerCase().replaceAll(" ", "-") === props.filter;
    const queryMatches = !query || [document.id, document.title, document.process, document.owner.displayName, document.documentType, ...document.applicability].join(" ").toLowerCase().includes(query);
    return filterMatches && queryMatches;
  });
  const copy = mode === "library" ? "Search the approved source of truth by process, owner or document identifier." : mode === "favourites" ? "Your saved routes back to frequently used controlled guidance." : "Documents opened from your account during the last 30 days.";
  const title = mode === "library" ? "Controlled library" : mode === "favourites" ? "Favourites" : "Recently viewed";
  return <><PageHeading eyebrow="Authoritative source" title={title} copy={copy}/><Panel title="Controlled documents" subtitle="Default view excludes non-effective content" flush><div className="library-toolbar"><div className="table-search"><Icon name="search"/><label className="sr-only" htmlFor="library-query">Filter documents</label><input id="library-query" type="search" value={props.query} onChange={(event) => props.setQuery(event.target.value)} placeholder="Filter this view"/></div><span><strong>{documents.length}</strong> documents</span></div>{mode === "library" && <div className="filter-row" role="group" aria-label="Filter controlled documents">{filterOptions.map(([value, label]) => <button type="button" key={value} aria-pressed={props.filter === value} className={props.filter === value ? "is-active" : ""} onClick={() => props.setFilter(value)}>{label}</button>)}</div>}<DocumentRows documents={documents} onOpen={props.openDocument}/></Panel></>;
}

function AcknowledgementsView(props: ViewProps) {
  return <><PageHeading eyebrow="Personal evidence" title="My acknowledgements" copy="Read assigned guidance and retain a timestamped record of understanding."/><Panel title="Assigned to you" subtitle="Acknowledgement is evidence of response, not competence certification" flush>{props.workspace.acknowledgements.length ? <DataTable label="My document acknowledgements" headings={["Document", "Process", "Status", "Due / completed", "Action"]}>{props.workspace.acknowledgements.map((assignment) => {
    const document = props.workspace.documents.find((item) => item.id === assignment.documentId);
    return <tr key={assignment.id}><td><strong className="table-primary">{assignment.documentTitle}</strong><span className="table-secondary"><code>{assignment.documentId}</code> · v{assignment.documentRevision}</span></td><td>{document?.process ?? "Unavailable"}</td><td><StatusBadge value={assignment.acknowledgedAt ? "Completed" : "Outstanding"}/></td><td>{formatDate(assignment.acknowledgedAt ?? assignment.dueAt)}</td><td><button type="button" className="text-route" onClick={(event) => document && props.openDocument(document, event.currentTarget)}>{assignment.acknowledgedAt ? "View evidence" : "Read and acknowledge"}</button></td></tr>;
  })}</DataTable> : <EmptyState title="No assignments" copy="You have no document acknowledgements assigned."/>}</Panel></>;
}

function AssuranceLedger({ metrics }: { metrics: Metric[] }) {
  return <div className="assurance-ledger">{metrics.map((metric) => {
    const value = Number.parseFloat(metric.value) || 0;
    return <div className="assurance-row" key={metric.id}><span><strong>{metric.label}</strong><small>{metric.note}</small></span><span className="assurance-bar" aria-label={`${metric.label}: ${metric.value}`}><span style={{ width: `${Math.min(value, 100)}%` }} data-state={metric.state}/></span><code>{metric.value}</code></div>;
  })}</div>;
}

function ControlTrack({ workspace, navigate }: Pick<ViewProps, "workspace" | "navigate">) {
  const stages = [
    { index: "01", title: "Request", copy: "Triage and impact", items: workspace.changes.filter((item) => ["Triage", "Impact assessment", "Authoring"].includes(item.stage)), page: "changes" as PageId },
    { index: "02", title: "In review", copy: "Author, review, approve", items: workspace.approvals, page: "approvals" as PageId },
    { index: "03", title: "Activation", copy: "Publish and notify", items: workspace.changes.filter((item) => item.stage === "Activation"), page: "changes" as PageId },
    { index: "04", title: "Assurance", copy: "Acknowledge and review", items: [...workspace.acknowledgements.filter((item) => !item.acknowledgedAt), ...workspace.exceptions], page: "exceptions" as PageId },
  ];
  return <div className="control-track">{stages.map((stage) => <section key={stage.index}><header><span><code>{stage.index}</code><strong>{stage.title}</strong><small>{stage.copy}</small></span><span className="count-badge">{stage.items.length}</span></header><div>{stage.items.map((item) => {
    const id = "id" in item ? item.id : "";
    const title = "title" in item ? item.title : "documentTitle" in item ? item.documentTitle : "Controlled work";
    const owner = "owner" in item ? item.owner.displayName : "submittedBy" in item ? item.submittedBy.displayName : "assignedTo" in item ? item.assignedTo.displayName : "Document control";
    return <button type="button" className="work-slip" key={id} onClick={() => navigate(stage.page)}><code>{id}</code><strong>{title}</strong><span>{owner}</span></button>;
  })}</div></section>)}</div>;
}

function TeamControl(props: ViewProps) {
  const dueReviews = props.workspace.documents.filter((document) => document.nextReviewDate && document.nextReviewDate <= "2026-09-24").length;
  return <><PageHeading eyebrow="Lifecycle operations" title="Document control desk" copy="Move work through controlled stages and see where governance needs intervention." actions={<ViewAction icon="plus" onClick={() => props.actionUnavailable("Change request entry", "Configure the governed change-request service for this environment.")}>New change request</ViewAction>}/><MetricsStrip items={[{ label: "Open lifecycle work", value: String(props.workspace.changes.length + props.workspace.approvals.length), note: "Across governed stages" }, { label: "Documents in approval", value: String(props.workspace.approvals.length), note: "Exact versions assigned" }, { label: "Reviews due in 30 days", value: String(dueReviews), note: "Ownership required" }, { label: "Control exceptions", value: String(props.workspace.exceptions.length), note: props.workspace.exceptions.some((item) => item.severity === "High") ? "High severity present" : "Within tolerance", state: props.workspace.exceptions.some((item) => item.severity === "High") ? "negative" : "positive" }]}/><Panel title="Lifecycle control track" subtitle="Work is grouped by governance state, not file location" action={<TextRoute onClick={() => props.navigate("changes")}>Open register</TextRoute>} flush><ControlTrack workspace={props.workspace} navigate={props.navigate}/></Panel><div className="grid grid--2-1 section-gap"><Panel title="Priority queue" subtitle="Decisions and exceptions requiring a human owner" flush><div className="obligation-list"><button type="button" className="obligation-item" onClick={() => props.navigate("approvals")}><span className="due-tile"><strong>{props.workspace.approvals.length}</strong><span>APR</span></span><span><strong>Assigned approvals</strong><small>Review the exact version and change evidence</small></span><Icon name="arrow"/></button><button type="button" className="obligation-item" onClick={() => props.navigate("exceptions")}><span className="due-tile"><strong>{props.workspace.exceptions.length}</strong><span>EX</span></span><span><strong>Control exceptions open</strong><small>Blocking failures prevent unsafe publication</small></span><Icon name="arrow"/></button><button type="button" className="obligation-item" onClick={() => props.navigate("calendar")}><span className="due-tile"><strong>{dueReviews}</strong><span>REV</span></span><span><strong>Reviews need ownership</strong><small>Due within the next 30 days</small></span><Icon name="arrow"/></button></div></Panel><Panel title="Control assurance" subtitle="Source-backed health across the governed library"><AssuranceLedger metrics={props.workspace.platform.metrics}/></Panel></div></>;
}

function TeamDocuments(props: ViewProps) {
  const effective = props.workspace.documents.filter((document) => ["Effective", "Review due"].includes(document.lifecycleStatus));
  return <><PageHeading eyebrow="Controlled inventory" title="Documents" copy="Administer metadata, ownership, versions and lifecycle state across your team." actions={<ViewAction icon="plus" onClick={() => props.actionUnavailable("Controlled document creation", "Configure the approved SharePoint template and content-type service before document creation.")}>Create controlled document</ViewAction>}/><MetricsStrip items={[{ label: "Controlled in view", value: String(props.workspace.documents.length), note: "Permission-trimmed result" }, { label: "Effective", value: String(effective.length), note: "Current or review due" }, { label: "Draft / review", value: String(props.workspace.documents.length - effective.length), note: "Not reader-visible" }, { label: "Overdue review", value: String(props.workspace.documents.filter((item) => item.lifecycleStatus === "Review due").length), note: "Action required", state: "negative" }]}/><Panel title="Team document register" subtitle="Lifecycle status is distinct from native SharePoint approval" flush><DataTable label="Team document register" headings={["Document", "Lifecycle", "SP approval", "Version", "Owner", "Next review", ""]}>{props.workspace.documents.map((document) => <tr key={document.id}><td><button type="button" className="text-route table-primary" onClick={(event) => props.openDocument(document, event.currentTarget)}>{document.title}</button><span className="table-secondary"><code>{document.id}</code> · {document.documentType}</span></td><td><StatusBadge value={document.lifecycleStatus}/></td><td>{document.nativeApprovalStatus}</td><td>v{document.businessRevision}</td><td><Person value={document.owner}/></td><td>{formatDate(document.nextReviewDate)}</td><td><button className="icon-button" type="button" aria-label={`Open ${document.title}`} onClick={(event) => props.openDocument(document, event.currentTarget)}><Icon name="arrow"/></button></td></tr>)}</DataTable></Panel></>;
}

function ChangesView(props: ViewProps) {
  return <><PageHeading eyebrow="Change governance" title="Change requests" copy="Capture the reason, impact, evidence and approvals behind every controlled change." actions={<ViewAction icon="plus" onClick={() => props.actionUnavailable("Change request entry", "Configure the governed change-request service for this environment.")}>New change request</ViewAction>}/><MetricsStrip items={[{ label: "Open requests", value: String(props.workspace.changes.length), note: "All requests in scope" }, { label: "Awaiting impact", value: String(props.workspace.changes.filter((item) => item.stage === "Impact assessment").length), note: "Owner assignment visible" }, { label: "Past target", value: String(props.workspace.changes.filter((item) => item.health === "Overdue").length), note: "Escalate by rule", state: "negative" }, { label: "Emergency", value: String(props.workspace.changes.filter((item) => item.requestType === "Emergency").length), note: "Separate route required" }]}/><Panel title="Change register" subtitle="Evidence remains linked to the resulting document version" flush>{props.workspace.changes.length ? <DataTable label="Document change requests" headings={["Request", "Type", "Stage", "Owner", "Due", "Health", ""]}>{props.workspace.changes.map((item) => <tr key={item.id}><td><strong className="table-primary">{item.title}</strong><span className="table-secondary"><code>{item.id}</code> · {item.process}</span></td><td>{item.requestType}</td><td>{item.stage}</td><td><Person value={item.owner}/></td><td>{formatDate(item.dueAt)}</td><td><StatusBadge value={item.health === "Attention" ? "Review" : item.health}/></td><td><button type="button" className="text-route" onClick={() => props.actionUnavailable("Change request detail", `${item.id} requires its tenant change-register endpoint.`)}>Open</button></td></tr>)}</DataTable> : <EmptyState title="No open requests" copy="New requests will appear when the change-register service is configured."/>}</Panel></>;
}

function ApprovalsView(props: ViewProps) {
  return <><PageHeading eyebrow="Decision queue" title="Approvals" copy="Review change evidence, separation of duties and the exact version awaiting release."/><Panel title="Awaiting decision" subtitle={`${props.workspace.approvals.length} approvals assigned to this role`} flush>{props.workspace.approvals.length ? <DataTable label="Pending document approvals" headings={["Document", "Submitted by", "Risk", "Version evidence", "Due", "Decision"]}>{props.workspace.approvals.map((item) => <tr key={item.id}><td><strong className="table-primary">{item.documentTitle}</strong><span className="table-secondary"><code>{item.id}</code> · {item.stage}</span></td><td><Person value={item.submittedBy}/></td><td><StatusBadge value={item.risk === "High" ? "Review" : item.risk}/></td><td><code>v{item.documentRevision}</code><span className="table-secondary">ETag {item.documentETag}</span></td><td>{formatDateTime(item.dueAt)}</td><td><div className="inline-actions"><Button onClick={() => props.actionUnavailable("Approval evidence", item.changeSummary)}>Review</Button><Button kind="primary" onClick={() => props.approve(item)}>Approve</Button></div></td></tr>)}</DataTable> : <EmptyState title="All decisions recorded" copy="Completed approvals remain available in the audit evidence."/>}</Panel></>;
}

function CalendarView(props: ViewProps) {
  const events = props.workspace.documents.filter((document) => document.nextReviewDate).sort((a, b) => (a.nextReviewDate ?? "").localeCompare(b.nextReviewDate ?? ""));
  return <><PageHeading eyebrow="Forward assurance" title="Review calendar" copy="Plan review ownership before documents reach their due date." actions={<ViewAction onClick={() => props.actionUnavailable("Review assignment", "Configure review-frequency, business-calendar and escalation rules for this tenant.")}>Assign selected reviews</ViewAction>}/><Panel title="Upcoming lifecycle dates" subtitle="Dates are sourced from current document metadata" flush>{events.length ? <DataTable label="Upcoming document reviews" headings={["Review date", "Document", "Owner", "Lifecycle", "Applicability", ""]}>{events.map((document) => <tr key={document.id}><td>{formatDate(document.nextReviewDate)}</td><td><strong className="table-primary">{document.title}</strong><span className="table-secondary"><code>{document.id}</code> · v{document.businessRevision}</span></td><td><Person value={document.owner}/></td><td><StatusBadge value={document.lifecycleStatus}/></td><td>{document.applicability.join(", ")}</td><td><button type="button" className="text-route" onClick={(event) => props.openDocument(document, event.currentTarget)}>Open</button></td></tr>)}</DataTable> : <EmptyState title="No review dates available" copy="Effective documents must have configured next-review dates."/>}</Panel></>;
}

function ExceptionsView(props: ViewProps) {
  return <><PageHeading eyebrow="Control assurance" title="Exceptions" copy="Investigate deviations from the document control model and retain remediation evidence."/><MetricsStrip items={[{ label: "Open exceptions", value: String(props.workspace.exceptions.length), note: props.workspace.exceptions.length ? "Requires action" : "No open items", state: props.workspace.exceptions.length ? "negative" : "positive" }, { label: "Blocking", value: String(props.workspace.exceptions.filter((item) => item.blocking).length), note: "Publication prevented" }, { label: "High severity", value: String(props.workspace.exceptions.filter((item) => ["High", "Critical"].includes(item.severity)).length), note: "Escalation required", state: "warning" }, { label: "Retried", value: String(props.workspace.exceptions.filter((item) => item.retryCount > 0).length), note: "Safe retry only" }]}/><Panel title="Exception register" subtitle="Ordered by severity and age" flush>{props.workspace.exceptions.length ? <DataTable label="Control exceptions" headings={["Exception", "Severity", "Owner", "Opened", "Correlation", "Action"]}>{props.workspace.exceptions.map((item) => <tr key={item.id}><td><strong className="table-primary">{item.title}</strong><span className="table-secondary"><code>{item.id}</code> · {item.scope}</span></td><td><StatusBadge value={item.severity === "High" || item.severity === "Critical" ? "Exception" : "Review"}/></td><td><Person value={item.owner}/></td><td>{formatDateTime(item.createdAt)}</td><td><code>{item.correlationId}</code></td><td><Button onClick={() => props.resolveException(item)}>Resolve</Button></td></tr>)}</DataTable> : <EmptyState title="No open exceptions" copy="Remediation evidence is retained in the audit history."/>}</Panel></>;
}

function ReportsView(props: ViewProps) {
  return <><PageHeading eyebrow="Governance evidence" title="Reports" copy="Turn operational signals into board, audit and process-owner evidence packs." actions={<ViewAction icon="download" onClick={() => props.actionUnavailable("Governance export", "Configure the report export endpoint and role-restricted source reconciliation.")}>Export governance pack</ViewAction>}/><MetricsStrip items={props.workspace.platform.metrics.map((metric) => ({ label: metric.label, value: metric.value, note: metric.note, state: metric.state }))}/><div className="grid grid--1-1"><Panel title="Assurance by control" subtitle="Metric definitions remain visible and source-backed"><AssuranceLedger metrics={props.workspace.platform.metrics}/></Panel><Panel title="Required report families" subtitle="PRD section 20 coverage"><div className="settings-list">{["Document Control Work Queue", "Current Document Register", "Review Compliance", "Approval Performance", "Control Completeness", "Records and Disposition", "Access and Sharing Exceptions", "Product Operations", "Adoption and Findability"].map((name) => <div className="setting-row" key={name}><span><strong>{name}</strong><small>Role-restricted · freshness displayed</small></span><StatusBadge value="Configured"/></div>)}</div></Panel></div></>;
}

function TeamView(props: ViewProps) {
  switch (props.page) {
    case "documents": return <TeamDocuments {...props}/>;
    case "changes": return <ChangesView {...props}/>;
    case "approvals": return <ApprovalsView {...props}/>;
    case "calendar": return <CalendarView {...props}/>;
    case "exceptions": return <ExceptionsView {...props}/>;
    case "reports": return <ReportsView {...props}/>;
    default: return <TeamControl {...props}/>;
  }
}

function EventStream({ platform }: { platform: PlatformSnapshot }) {
  return <div className="event-stream">{platform.audit.slice(0, 5).map((event) => <div className="event-item" key={event.id}><time dateTime={event.occurredAt}>{formatDate(event.occurredAt, { hour: "2-digit", minute: "2-digit", timeZone: "Europe/London" })}</time><span><strong>{event.eventType.replaceAll(".", " ")}</strong><small>{event.object} · {event.source}</small></span></div>)}</div>;
}

function ControlMatrix({ props }: { props: ViewProps }) {
  const platform = props.workspace.platform;
  const cells = [
    ["Sites", String(platform.sites.length).padStart(2, "0"), "Managed document centres", "sites", platform.sites.some((site) => site.health !== "Healthy") ? "Review" : "Healthy"],
    ["Access", String(platform.sites.length * 3).padStart(2, "0"), "Role groups in scope", "sites", "Healthy"],
    ["Automations", String(platform.flows.length).padStart(2, "0"), `${platform.flows.filter((flow) => flow.health !== "Healthy").length} owner or run exceptions`, "automations", platform.flows.some((flow) => flow.health !== "Healthy") ? "Review" : "Healthy"],
    ["Retention", String(platform.retention.length).padStart(2, "0"), "Mappings in the file plan view", "retention", platform.retention.some((item) => item.status !== "Published") ? "Review" : "Healthy"],
    ["Recovery", platform.recovery.rpo?.split(" ")[0] ?? "—", "Planning assumption until approved", "recovery", platform.recovery.result],
    ["Configuration drift", "02", "Tenant validation required", "deployments", "Review"],
  ] as const;
  return <div className="control-matrix">{cells.map(([label, value, copy, page, health]) => <button type="button" key={label} onClick={() => props.navigate(page)}><span><span>{label}</span><i data-health={health.toLowerCase()} aria-label={health}/></span><strong>{value}</strong><small>{copy}</small></button>)}</div>;
}

function PlatformOverview(props: ViewProps) {
  const platform = props.workspace.platform;
  return <><PageHeading eyebrow="Microsoft 365 control plane" title="Platform assurance" copy="Observe the technical controls that keep governed document work reliable, recoverable and auditable." actions={<ViewAction icon="check" onClick={() => props.actionUnavailable("Control scan", "The production Power Automate control-scan operation must be configured for this tenant.")}>Run control scan</ViewAction>}/><div className={`health-banner health-banner--${platform.health.toLowerCase()}`}><span><strong>{platform.summary}</strong><small>Last complete scan: {formatDateTime(platform.lastScannedAt)} · {props.workspace.exceptions.length} visible exceptions</small></span><StatusBadge value={platform.health}/></div><div className="platform-map"><ControlMatrix props={props}/><Panel title="Live control events" subtitle="Unified audit, automation and deployment activity" action={<TextRoute onClick={() => props.navigate("audit")}>Full audit</TextRoute>}><EventStream platform={platform}/></Panel></div><div className="grid grid--1-1 section-gap"><Panel title="Site estate" subtitle="Template alignment and inventory reach" action={<TextRoute onClick={() => props.navigate("sites")}>Manage sites</TextRoute>}><div className="assurance-ledger">{platform.sites.map((site) => <div className="assurance-row" key={site.id}><span><strong>{site.displayName}</strong><small><code>{site.id}</code> · {site.documentCount} documents</small></span><span className="assurance-bar"><span style={{ width: site.health === "Healthy" ? "100%" : "86%" }} data-state={site.health === "Healthy" ? "positive" : "warning"}/></span><StatusBadge value={site.health}/></div>)}</div></Panel><Panel title="Automation runs" subtitle="Managed Power Automate flows" action={<TextRoute onClick={() => props.navigate("automations")}>Open automation</TextRoute>}><div className="settings-list">{platform.flows.slice(0, 4).map((flow) => <div className="setting-row" key={flow.id}><span><strong>{flow.displayName}</strong><small>{flow.ownership} · {flow.rollingRunCount.toLocaleString("en-GB")} runs</small></span><StatusBadge value={flow.health}/></div>)}</div></Panel></div></>;
}

function SitesView(props: ViewProps) {
  const sites = props.workspace.platform.sites;
  return <><PageHeading eyebrow="Estate management" title="Sites & access" copy="Provision consistent document centres and enforce group-based, least-privilege access." actions={<ViewAction icon="plus" onClick={() => props.actionUnavailable("Site provisioning", "Provide the approved site template, app-catalog scope and Entra group configuration before provisioning.")}>Provision document centre</ViewAction>}/><MetricsStrip items={[{ label: "Managed sites", value: String(sites.length), note: "Configuration baseline required" }, { label: "Security groups", value: String(sites.length * 3), note: "Readers, authors, approvers" }, { label: "Direct permissions", value: "0", note: "Expected control state" }, { label: "Sites for review", value: String(sites.filter((site) => site.health !== "Healthy").length), note: "Scan findings", state: "warning" }]}/><Panel title="Managed document centres" subtitle="Tenant-neutral IDs are sourced from the configured site adapter" flush><DataTable label="Managed SharePoint document centres" headings={["Site", "Documents", "Access model", "Health", "Last scan", ""]}>{sites.map((site) => <tr key={site.id}><td><strong className="table-primary">{site.displayName}</strong><span className="table-secondary"><code>{site.id}</code></span></td><td>{site.documentCount}</td><td>{site.accessModel}</td><td><StatusBadge value={site.health}/></td><td>{formatDateTime(site.lastScannedAt)}</td><td><button type="button" className="text-route" onClick={() => props.actionUnavailable("Site configuration", `${site.id} requires the tenant provisioning and permission-validation adapters.`)}>Configure</button></td></tr>)}</DataTable></Panel></>;
}

function AutomationsView(props: ViewProps) {
  const flows = props.workspace.platform.flows;
  const nonCompliant = flows.filter((flow) => flow.health !== "Healthy");
  return <><PageHeading eyebrow="Workflow control" title="Automations" copy="Monitor lifecycle flows, connection ownership, failure handling and solution deployment." actions={<ViewAction icon="check" onClick={() => props.actionUnavailable("Automation health check", "Configure the Power Automate environment and connection-reference operation.")}>Run health check</ViewAction>}/><div className={`health-banner ${nonCompliant.length ? "health-banner--review" : "health-banner--healthy"}`}><span><strong>{flows.length - nonCompliant.length} of {flows.length} flows within the current control baseline</strong><small>{nonCompliant.length ? `${nonCompliant.map((flow) => flow.displayName).join(", ")} require review.` : "No exceptions in the current result."}</small></span><StatusBadge value={nonCompliant.length ? "Review" : "Healthy"}/></div><Panel title="Managed flows" subtitle="Flow evidence must outlive transient run history" flush><DataTable label="Managed document lifecycle automations" headings={["Flow", "Ownership", "Environment", "Last run", "Health", "30d runs", ""]}>{flows.map((flow) => <tr key={flow.id}><td><strong className="table-primary">{flow.displayName}</strong><span className="table-secondary">Power Automate · solution-aware expected</span></td><td>{flow.ownership}</td><td>{flow.environment ?? "Unconfigured"}</td><td>{formatDateTime(flow.lastRunAt)}</td><td><StatusBadge value={flow.health}/></td><td>{flow.rollingRunCount.toLocaleString("en-GB")}</td><td><button type="button" className="text-route" onClick={() => props.actionUnavailable("Flow evidence", `${flow.id} requires its Power Automate management endpoint.`)}>Inspect</button></td></tr>)}</DataTable></Panel></>;
}

function RetentionView(props: ViewProps) {
  const mappings = props.workspace.platform.retention;
  return <><PageHeading eyebrow="Records governance" title="Records & retention" copy="Apply defensible retention to effective documents and their decision evidence." actions={<ViewAction onClick={() => props.actionUnavailable("Retention publication", "An approved tenant file plan and Records Management authority are required before label publication.")}>Publish label update</ViewAction>}/><MetricsStrip items={[{ label: "Mappings in view", value: String(mappings.length), note: "File-plan approval required" }, { label: "Published", value: String(mappings.filter((item) => item.status === "Published").length), note: "Adapter-reported state" }, { label: "Under review", value: String(mappings.filter((item) => item.status === "Review").length), note: "Cannot be assumed", state: "warning" }, { label: "Regulatory records", value: "0", note: "Excluded from MVP" }]}/><Panel title="Retention label map" subtitle="Purview policy state; no delete action substitutes for disposition" flush><DataTable label="Records retention label map" headings={["Label", "Retention", "Scope", "Authority", "State", ""]}>{mappings.map((mapping) => <tr key={mapping.id}><td><strong className="table-primary">{mapping.name}</strong><span className="table-secondary"><code>{mapping.id}</code></span></td><td>{mapping.retention}</td><td>{mapping.scope}</td><td>{mapping.authority ?? "Not supplied"}</td><td><StatusBadge value={mapping.status}/></td><td><button type="button" className="text-route" onClick={() => props.actionUnavailable("Retention policy", "Use the configured Purview administration route with Records Management approval.")}>View policy</button></td></tr>)}</DataTable></Panel></>;
}

function IntegrationsView(props: ViewProps) {
  return <><PageHeading eyebrow="Service boundaries" title="Integrations" copy="Understand what crosses each boundary, how it authenticates and who owns it."/><Panel title="Connected services" subtitle="Changes require an owner, impact assessment and approved deployment" flush><div className="settings-list settings-list--roomy">{props.workspace.platform.integrations.map((integration) => <div className="setting-row" key={integration.id}><span><strong>{integration.name}</strong><small>{integration.purpose}</small></span><span className="setting-row__detail"><strong>{integration.authentication}</strong><small>{integration.owner}</small></span><button className={`toggle ${integration.enabled ? "is-on" : ""}`} type="button" role="switch" aria-checked={integration.enabled} aria-label={`${integration.enabled ? "Disable" : "Enable"} ${integration.name}`} onClick={() => props.toggleIntegration(integration.id, !integration.enabled)}><span/></button></div>)}</div></Panel></>;
}

function DeploymentsView(props: ViewProps) {
  const deployments = props.workspace.platform.deployments;
  return <><PageHeading eyebrow="Configuration delivery" title="Deployments" copy="Move versioned SharePoint, Power Platform and reporting configuration through governed environments." actions={<ViewAction icon="deploy" onClick={() => props.actionUnavailable("Deployment preparation", "Set Dev/Test/Production environment mappings and an approved release pipeline first.")}>Prepare deployment</ViewAction>}/><MetricsStrip items={[{ label: "Latest release", value: deployments[0]?.id ?? "None", note: "Evidence-linked package" }, { label: "Pending review", value: String(deployments.filter((item) => item.result === "Review").length), note: "Test or release gate" }, { label: "Failed", value: String(deployments.filter((item) => item.result === "Failed").length), note: "Rollback required", state: "negative" }, { label: "Configuration drift", value: "2", note: "Tenant scan not configured", state: "warning" }]}/><Panel title="Release ledger" subtitle="Tenant-neutral artefacts and environment-owned configuration" flush><DataTable label="Configuration deployment ledger" headings={["Release", "Environment", "Scope", "Deployed", "Result", "Evidence"]}>{deployments.map((deployment) => <tr key={deployment.id}><td><strong className="table-primary">{deployment.id}</strong><span className="table-secondary">Managed solution</span></td><td>{deployment.environment}</td><td>{deployment.scope}</td><td>{formatDateTime(deployment.deployedAt)}</td><td><StatusBadge value={deployment.result}/></td><td><code>{deployment.evidenceId}</code></td></tr>)}</DataTable></Panel></>;
}

function RecoveryView(props: ViewProps) {
  const recovery = props.workspace.platform.recovery;
  return <><PageHeading eyebrow="Operational resilience" title="Recovery" copy="Prove that document content, configuration and lifecycle evidence can be restored." actions={<ViewAction onClick={() => props.actionUnavailable("Recovery exercise", "The approved backup service, RPO/RTO and tenant recovery runbook are required.")}>Start recovery exercise</ViewAction>}/><MetricsStrip items={[{ label: "RPO", value: recovery.rpo ?? "Unapproved", note: "Tenant decision required", state: recovery.rpo ? "warning" : "negative" }, { label: "RTO", value: recovery.rto ?? "Unapproved", note: "Tenant decision required", state: recovery.rto ? "warning" : "negative" }, { label: "Last restore test", value: formatDate(recovery.lastExerciseAt), note: recovery.lastExerciseDuration ?? "No duration" }, { label: "Open findings", value: String(recovery.openFindings), note: recovery.result }]}/><div className="grid grid--1-1"><Panel title="Recovery coverage" subtitle="What must be protected and reconciled"><div className="settings-list">{[["SharePoint content", "Content, versions and metadata"], ["Power Platform solutions", "Managed solution artefacts"], ["Configuration baseline", "Source-controlled templates"], ["Audit and evidence", "Durable evidence register"]].map(([name, copy]) => <div className="setting-row" key={name}><span><strong>{name}</strong><small>{copy}</small></span><StatusBadge value="Tenant configuration"/></div>)}</div></Panel><Panel title="Last exercise" subtitle={recovery.lastExerciseAt ? `${formatDate(recovery.lastExerciseAt)} · ${recovery.lastExerciseDuration}` : "No exercise evidence"}><div className="recovery-evidence"><StatusBadge value={recovery.result}/><p>Recovery evidence must reconcile content, metadata, permissions and decision records. The current values are planning assumptions until approved by the continuity owner.</p></div></Panel></div></>;
}

function AuditView(props: ViewProps) {
  const audit = props.workspace.platform.audit;
  return <><PageHeading eyebrow="Evidence trail" title="Audit" copy="Search a correlated record of user, lifecycle, configuration and automation activity." actions={<ViewAction icon="download" onClick={() => props.actionUnavailable("Audit export", "Configure the role-restricted Purview and durable evidence export operations.")}>Export filtered evidence</ViewAction>}/><Panel title="Unified audit events" subtitle="Source, correlation ID and localised timestamp remain visible" flush><DataTable label="Unified platform audit events" headings={["Time", "Event", "Actor", "Object", "Source", "Result", "Correlation"]}>{audit.map((event) => <tr key={event.id}><td>{formatDateTime(event.occurredAt)}</td><td><code>{event.eventType}</code></td><td>{event.actor}</td><td>{event.object}</td><td>{event.source}</td><td><StatusBadge value={event.result}/></td><td><code>{event.correlationId}</code></td></tr>)}</DataTable></Panel></>;
}

function PlatformView(props: ViewProps) {
  switch (props.page) {
    case "sites": return <SitesView {...props}/>;
    case "automations": return <AutomationsView {...props}/>;
    case "retention": return <RetentionView {...props}/>;
    case "integrations": return <IntegrationsView {...props}/>;
    case "deployments": return <DeploymentsView {...props}/>;
    case "recovery": return <RecoveryView {...props}/>;
    case "audit": return <AuditView {...props}/>;
    default: return <PlatformOverview {...props}/>;
  }
}

export function RoleView(props: ViewProps) {
  return useMemo(() => {
    if (props.role === "teamAdmin") return <TeamView {...props}/>;
    if (props.role === "platformAdmin") return <PlatformView {...props}/>;
    if (props.page === "library") return LibraryView(props, "library");
    if (props.page === "acknowledgements") return <AcknowledgementsView {...props}/>;
    if (props.page === "favourites") return LibraryView(props, "favourites");
    if (props.page === "recent") return LibraryView(props, "recent");
    return <UserHome {...props}/>;
  }, [props]);
}
