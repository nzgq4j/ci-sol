import React from "react";
import type { ControlledDocument, HealthStatus, LifecycleStatus, PersonRef } from "../domain/types";
import { Icon } from "./Icon";

export function formatDate(value?: string, options?: Intl.DateTimeFormatOptions): string {
  if (!value) return "Not set";
  return new Intl.DateTimeFormat("en-GB", options ?? { day: "2-digit", month: "short", year: "numeric", timeZone: "Europe/London" }).format(new Date(value));
}

export function formatDateTime(value?: string): string {
  if (!value) return "Not available";
  return new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit", timeZone: "Europe/London", timeZoneName: "short" }).format(new Date(value));
}

export function initials(name: string): string {
  return name.split(" ").map((part) => part[0]).join("").slice(0, 2).toUpperCase();
}

export function StatusBadge({ value }: { value: LifecycleStatus | HealthStatus | string }) {
  const key = value.toLowerCase().replaceAll(" ", "-");
  return <span className={`status status--${key}`}><span aria-hidden="true" />{value}</span>;
}

export function Person({ value }: { value: PersonRef }) {
  return <span className="person"><span className="person__avatar" aria-hidden="true">{initials(value.displayName)}</span><span>{value.displayName}</span></span>;
}

export function Button({ children, kind = "secondary", icon, className = "", ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & { kind?: "primary" | "secondary" | "ghost" | "danger"; icon?: string }) {
  return <button type="button" className={`button button--${kind} ${className}`} {...props}>{icon && <Icon name={icon}/>}<span>{children}</span></button>;
}

export function PageHeading({ eyebrow, title, copy, actions }: { eyebrow: string; title: string; copy: string; actions?: React.ReactNode }) {
  return <header className="page-heading"><div><span className="eyebrow">{eyebrow}</span><h1>{title}</h1><p>{copy}</p></div>{actions && <div className="page-heading__actions">{actions}</div>}</header>;
}

export function Panel({ title, subtitle, action, children, flush = false, className = "" }: { title: string; subtitle?: string; action?: React.ReactNode; children: React.ReactNode; flush?: boolean; className?: string }) {
  return <section className={`panel ${flush ? "panel--flush" : ""} ${className}`}><header className="panel__header"><div><h2>{title}</h2>{subtitle && <span>{subtitle}</span>}</div>{action}</header><div className={`panel__body ${flush ? "panel__body--flush" : ""}`}>{children}</div></section>;
}

export function MetricsStrip({ items }: { items: Array<{ label: string; value: string; note: string; state?: "positive" | "warning" | "negative" | "neutral" }> }) {
  return <div className="metrics-strip">{items.map((item) => <div className="metric-cell" key={item.label}><span className="metric-cell__label">{item.label}</span><strong>{item.value}</strong><span className={`metric-cell__note metric-cell__note--${item.state ?? "positive"}`}>{item.note}</span></div>)}</div>;
}

export function DataTable({ label, headings, children }: { label: string; headings: string[]; children: React.ReactNode }) {
  return <div className="table-wrap"><table className="data-table"><caption className="sr-only">{label}</caption><thead><tr>{headings.map((heading) => <th scope="col" key={heading}>{heading}</th>)}</tr></thead><tbody>{children}</tbody></table></div>;
}

export function EmptyState({ title, copy, action }: { title: string; copy: string; action?: React.ReactNode }) {
  return <div className="empty-state"><span className="empty-state__mark" aria-hidden="true"><Icon name="check"/></span><strong>{title}</strong><p>{copy}</p>{action}</div>;
}

export function StatePanel({ state, title, copy, action }: { state: "loading" | "error" | "permission" | "unconfigured" | "stale"; title: string; copy: string; action?: React.ReactNode }) {
  return <section className={`state-panel state-panel--${state}`} role={state === "error" ? "alert" : "status"}><span className="state-panel__mark" aria-hidden="true"><Icon name={state === "loading" ? "clock" : state === "permission" ? "approval" : state === "unconfigured" ? "integration" : "alert"}/></span><div><h2>{title}</h2><p>{copy}</p>{action}</div></section>;
}

export function DocumentRows({ documents, onOpen }: { documents: ControlledDocument[]; onOpen: (document: ControlledDocument, trigger: HTMLButtonElement) => void }) {
  if (!documents.length) return <EmptyState title="No documents found" copy="Try a different phrase or remove a filter."/>;
  return <div className="document-list">{documents.map((document) => <button key={`${document.id}-${document.businessRevision}`} type="button" className="document-row" data-document-id={document.id} data-state={document.lifecycleStatus.toLowerCase().replaceAll(" ", "-")} onClick={(event) => onOpen(document, event.currentTarget)}><span className="document-row__title"><strong>{document.title}</strong><span><code>{document.id}</code> · {document.documentType}</span></span><span className="document-row__meta"><strong>{document.process}</strong><span>Business process</span></span><span className="document-row__meta"><strong>{document.owner.displayName}</strong><span>Document owner</span></span><StatusBadge value={document.lifecycleStatus}/><Icon name="arrow" className="document-row__arrow"/></button>)}</div>;
}

export function LifecycleSpine({ events }: { events: Array<{ stage: string; title: string; detail: string; occurredAt: string; outcome: string }> }) {
  const currentIndex = Math.max(0, events.findIndex((event) => event.outcome === "Scheduled") - 1);
  return <ol className="lifecycle-spine">{events.map((event, index) => <li key={`${event.stage}-${event.occurredAt}`} className={index < currentIndex ? "is-complete" : index === currentIndex ? "is-current" : "is-future"}><span className="lifecycle-spine__node" aria-hidden="true">{index < currentIndex ? <Icon name="check"/> : index + 1}</span><span className="lifecycle-spine__copy"><strong>{event.stage}</strong><span>{event.detail}</span></span><time dateTime={event.occurredAt}>{formatDate(event.occurredAt)}</time></li>)}</ol>;
}
