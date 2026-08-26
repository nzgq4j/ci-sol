"use strict";

const els = {
  appShell: document.querySelector("#app-shell"),
  main: document.querySelector("#main-content"),
  nav: document.querySelector("#nav-list"),
  roleButton: document.querySelector("#role-menu-button"),
  roleMenu: document.querySelector("#role-menu"),
  roleGlyph: document.querySelector("#role-glyph"),
  roleLabel: document.querySelector("#role-label"),
  roleCaption: document.querySelector("#role-caption"),
  globalSearch: document.querySelector("#global-search-input"),
  drawer: document.querySelector("#detail-drawer"),
  drawerContent: document.querySelector("#drawer-content"),
  drawerScrim: document.querySelector("#drawer-scrim"),
  mobileButton: document.querySelector("#mobile-menu-button"),
  sidebar: document.querySelector("#sidebar"),
  mobileScrim: document.querySelector("#mobile-scrim"),
  confirmDialog: document.querySelector("#confirm-dialog"),
  confirmKicker: document.querySelector("#confirm-kicker"),
  confirmTitle: document.querySelector("#confirm-title"),
  confirmCopy: document.querySelector("#confirm-copy"),
  confirmAction: document.querySelector("#confirm-action"),
  toastRegion: document.querySelector("#toast-region"),
};

const mobileMedia = window.matchMedia("(max-width: 920px)");

const iconPaths = {
  home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5M9.5 20v-6h5v6"/>',
  library: '<path d="M5 4h12a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2Z"/><path d="M5 18a2 2 0 0 1 2-2h12M9 8h6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  star: '<path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  desk: '<path d="M4 5h16v12H4zM8 21h8M12 17v4"/><path d="m8 11 2.3 2.3L16 8"/>',
  document: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5M9 13h6M9 17h6"/>',
  change: '<path d="M4 7h11M12 4l3 3-3 3M20 17H9M12 14l-3 3 3 3"/>',
  approval: '<path d="M12 3 4 6v5c0 5.2 3.4 8.6 8 10 4.6-1.4 8-4.8 8-10V6Z"/><path d="m8.5 12 2.2 2.2 4.8-5"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/>',
  alert: '<path d="M12 3 2.8 20h18.4Z"/><path d="M12 9v5M12 17h.01"/>',
  report: '<path d="M5 20V10M12 20V4M19 20v-7"/>',
  platform: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  sites: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.2 2.4 3.3 5.4 3.3 9S14.2 18.6 12 21M12 3C9.8 5.4 8.7 8.4 8.7 12S9.8 18.6 12 21"/>',
  automation: '<path d="M4 7h8M16 7h4M14 5v4M4 17h4M12 17h8M10 15v4"/>',
  records: '<path d="M5 4h14v16H5zM8 8h8M8 12h8M8 16h5"/>',
  integration: '<path d="M8 12H3M21 12h-5M8 12a4 4 0 1 0 8 0 4 4 0 1 0-8 0Z"/>',
  deploy: '<path d="m12 3 7 4-7 4-7-4Z"/><path d="m5 12 7 4 7-4M5 17l7 4 7-4"/>',
  recovery: '<path d="M4 12a8 8 0 1 0 2.3-5.7L4 8"/><path d="M4 4v4h4"/>',
  audit: '<path d="M6 3h12v18H6zM9 8h6M9 12h6M9 16h3"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  arrow: '<path d="m9 5 7 7-7 7"/>',
  close: '<path d="m6 6 12 12M18 6 6 18"/>',
  download: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
  external: '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 13v7H4V6h7"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
};

function icon(name, extra = "") {
  return `<svg class="icon ${extra}" viewBox="0 0 24 24" aria-hidden="true">${iconPaths[name] || iconPaths.document}</svg>`;
}

const roles = {
  user: {
    label: "End user",
    caption: "Find and follow current guidance",
    glyph: "EU",
    start: "home",
    nav: [
      ["home", "Home", "home"],
      ["library", "Controlled library", "library"],
      ["acknowledgements", "My acknowledgements", "check", 2],
      ["favourites", "Favourites", "star"],
      ["recent", "Recently viewed", "clock"],
    ],
  },
  team: {
    label: "Team administrator",
    caption: "Operate the document lifecycle",
    glyph: "TA",
    start: "control",
    nav: [
      ["control", "Control desk", "desk", 7],
      ["documents", "Documents", "document"],
      ["changes", "Change requests", "change", 3],
      ["approvals", "Approvals", "approval", 4],
      ["calendar", "Review calendar", "calendar"],
      ["exceptions", "Exceptions", "alert", 2],
      ["reports", "Reports", "report"],
    ],
  },
  platform: {
    label: "Platform administrator",
    caption: "Assure the M365 control plane",
    glyph: "PA",
    start: "platform",
    nav: [
      ["platform", "Platform overview", "platform"],
      ["sites", "Sites & access", "sites"],
      ["automations", "Automations", "automation", 1],
      ["retention", "Records & retention", "records"],
      ["integrations", "Integrations", "integration"],
      ["deployments", "Deployments", "deploy"],
      ["recovery", "Recovery", "recovery"],
      ["audit", "Audit", "audit"],
    ],
  },
};

const documents = [
  { id: "SOP-OPS-014", title: "Customer escalation and service recovery", process: "Customer operations", owner: "Maya Patel", version: "4.2", status: "Effective", date: "18 Aug 2026", review: "18 Feb 2027", type: "SOP", favourite: true },
  { id: "WI-SEC-021", title: "Report and contain a suspected security incident", process: "Information security", owner: "Jon Bell", version: "3.0", status: "Effective", date: "12 Aug 2026", review: "12 Feb 2027", type: "Work instruction", acknowledge: true },
  { id: "POL-PEO-006", title: "Hybrid working and secure workspace policy", process: "People operations", owner: "Anika Shah", version: "2.3", status: "Effective", date: "04 Aug 2026", review: "04 Aug 2027", type: "Policy", favourite: true },
  { id: "SOP-FIN-008", title: "Supplier onboarding and due diligence", process: "Finance & procurement", owner: "Lewis Grant", version: "5.1", status: "Effective", date: "30 Jul 2026", review: "30 Jan 2027", type: "SOP" },
  { id: "WI-OPS-044", title: "Priority-one service outage communications", process: "Service operations", owner: "Maya Patel", version: "1.8", status: "Review due", date: "22 Jul 2026", review: "29 Aug 2026", type: "Work instruction", acknowledge: true },
  { id: "STD-DAT-003", title: "Business data classification standard", process: "Data governance", owner: "Sofia Reed", version: "3.4", status: "Effective", date: "16 Jul 2026", review: "16 Jul 2027", type: "Standard" },
  { id: "SOP-HSE-011", title: "Workplace incident reporting and investigation", process: "Health & safety", owner: "Imran Chowdhury", version: "2.0", status: "In approval", date: "09 Jul 2026", review: "—", type: "SOP" },
  { id: "TMP-QUA-002", title: "Corrective action and root cause record", process: "Quality management", owner: "Nina Walsh", version: "1.6", status: "Effective", date: "28 Jun 2026", review: "28 Jun 2027", type: "Template" },
];

const changes = [
  { id: "CR-0261", title: "Update escalation thresholds for priority accounts", owner: "Maya Patel", stage: "Impact assessment", age: "2 days", status: "On track" },
  { id: "CR-0257", title: "Align supplier screening with sanctions update", owner: "Lewis Grant", stage: "Authoring", age: "5 days", status: "Attention" },
  { id: "CR-0253", title: "Clarify incident notification timings", owner: "Jon Bell", stage: "Approval", age: "8 days", status: "On track" },
  { id: "CR-0249", title: "Annual review of hybrid work policy", owner: "Anika Shah", stage: "Activation", age: "12 days", status: "On track" },
];

const approvals = [
  { id: "APR-0881", title: "Workplace incident reporting and investigation", from: "Imran Chowdhury", due: "Today, 16:00", type: "Final approval", risk: "Medium" },
  { id: "APR-0878", title: "Priority-one service outage communications", from: "Maya Patel", due: "26 Aug", type: "Process owner", risk: "High" },
  { id: "APR-0874", title: "Business continuity contact tree", from: "Sofia Reed", due: "28 Aug", type: "Compliance review", risk: "Low" },
  { id: "APR-0869", title: "Third-party access recertification", from: "Jon Bell", due: "29 Aug", type: "Control owner", risk: "Medium" },
];

const exceptions = [
  { id: "EX-0042", title: "Two effective documents missing review dates", scope: "Operations site", owner: "Maya Patel", severity: "High", age: "3 hours" },
  { id: "EX-0039", title: "Flow owner uses individual rather than service account", scope: "DMS-Notify-Expiry", owner: "Platform team", severity: "Medium", age: "2 days" },
];

const state = {
  role: "user",
  page: "home",
  query: "",
  filter: "all",
  favourites: new Set(documents.filter((d) => d.favourite).map((d) => d.id)),
  acknowledged: new Set(),
  approved: new Set(),
  resolved: new Set(),
  lastFocus: null,
  pendingConfirm: null,
};

const personInitials = (name) => name.split(" ").map((part) => part[0]).join("").slice(0, 2).toUpperCase();
const escapeHTML = (value) => String(value).replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);

function status(text) {
  const key = text.toLowerCase().replaceAll(" ", "-");
  return `<span class="status ${key}">${escapeHTML(text)}</span>`;
}

function person(name) {
  return `<span class="person"><span class="person-avatar" aria-hidden="true">${personInitials(name)}</span><span>${escapeHTML(name)}</span></span>`;
}

function button(label, options = {}) {
  const { kind = "secondary", action = "", iconName = "", attrs = "" } = options;
  return `<button class="button ${kind}" type="button" ${action ? `data-action="${action}"` : ""} ${attrs}>${iconName ? icon(iconName) : ""}${escapeHTML(label)}</button>`;
}

function heading(eyebrow, title, copy, actions = "") {
  return `<div class="page-heading"><div><span class="eyebrow">${eyebrow}</span><h1>${title}</h1><p>${copy}</p></div>${actions ? `<div class="page-actions">${actions}</div>` : ""}</div>`;
}

function panel(title, subtitle, body, actions = "", extra = "") {
  return `<section class="panel ${extra}"><div class="panel-header"><div><h2 class="panel-title">${title}</h2>${subtitle ? `<span class="panel-subtitle">${subtitle}</span>` : ""}</div>${actions}</div><div class="panel-body ${extra.includes("flush") ? "no-pad" : ""}">${body}</div></section>`;
}

function emptyState(title, copy) {
  return `<div class="empty-state"><div class="empty-state__mark" aria-hidden="true">${icon("check")}</div><strong>${title}</strong><p>${copy}</p></div>`;
}

function documentRows(items) {
  if (!items.length) return emptyState("No documents found", "Try a different phrase or remove a filter.");
  return `<div class="doc-list">${items.map((doc) => `
    <button class="doc-row" type="button" data-open-document="${doc.id}" style="--row-accent:${doc.status === "Review due" ? "var(--amber-500)" : doc.status === "In approval" ? "var(--blue-500)" : "var(--teal-600)"}">
      <span class="doc-title"><strong>${escapeHTML(doc.title)}</strong><span><span class="doc-id">${doc.id}</span> · ${doc.type}</span></span>
      <span class="doc-meta"><strong>${escapeHTML(doc.process)}</strong><span>Business process</span></span>
      <span class="doc-meta"><strong>${escapeHTML(doc.owner)}</strong><span>Document owner</span></span>
      ${status(doc.status)}
      ${icon("arrow", "row-arrow")}
    </button>`).join("")}</div>`;
}

function dataTable(columns, rows, label) {
  return `<div class="data-table-wrap"><table class="data-table"><caption class="sr-only">${label}</caption><thead><tr>${columns.map((c) => `<th scope="col">${c}</th>`).join("")}</tr></thead><tbody>${rows.join("")}</tbody></table></div>`;
}

function lifecycleSpine(active = 3) {
  const steps = [
    ["Author", "Controlled draft created", "03 Aug 2026"],
    ["Review", "Subject matter review complete", "11 Aug 2026"],
    ["Approve", "Process owner approved", "17 Aug 2026"],
    ["Effective", "Published to the controlled library", "18 Aug 2026"],
    ["Retain", "Record disposition scheduled", "18 Aug 2033"],
  ];
  return `<div class="lifecycle-spine">${steps.map((step, index) => `
    <div class="spine-step ${index < active ? "is-complete" : index === active ? "is-current" : ""}">
      <span class="spine-node" aria-hidden="true">${index < active ? icon("check") : index + 1}</span>
      <span class="spine-copy"><strong>${step[0]}</strong><span>${step[1]}</span></span>
      <span class="spine-date">${step[2]}</span>
    </div>`).join("")}</div>`;
}

function renderNav() {
  const role = roles[state.role];
  els.roleLabel.textContent = role.label;
  els.roleCaption.textContent = role.caption;
  els.roleGlyph.textContent = role.glyph;
  els.nav.innerHTML = `<span class="nav-section-label">Workspace</span>${role.nav.map(([page, label, iconName, count]) => `
    <button class="nav-item ${state.page === page ? "is-active" : ""}" type="button" data-page="${page}" ${state.page === page ? 'aria-current="page"' : ""}>
      ${icon(iconName)}<span class="nav-item__label">${label}</span>${count ? `<span class="nav-item__count">${count}</span>` : ""}
    </button>`).join("")}`;
  els.roleMenu.innerHTML = Object.entries(roles).map(([key, item]) => `
    <button class="role-option ${state.role === key ? "is-active" : ""}" type="button" role="option" aria-selected="${state.role === key}" data-role="${key}">
      <span class="role-option__glyph" aria-hidden="true">${item.glyph}</span><span><strong>${item.label}</strong><small>${item.caption}</small></span>${state.role === key ? icon("check") : ""}
    </button>`).join("");
}

function filteredDocuments(source = documents) {
  const query = state.query.trim().toLowerCase();
  return source.filter((doc) => {
    const matchesFilter = state.filter === "all" || doc.status.toLowerCase().replaceAll(" ", "-") === state.filter || doc.type.toLowerCase().replaceAll(" ", "-") === state.filter;
    const haystack = `${doc.id} ${doc.title} ${doc.process} ${doc.owner} ${doc.type}`.toLowerCase();
    return matchesFilter && (!query || haystack.includes(query));
  });
}

function userHome() {
  const currentDocs = documents.filter((doc) => doc.status === "Effective").slice(0, 4);
  const outstanding = documents.filter((doc) => doc.acknowledge && !state.acknowledged.has(doc.id));
  return `
    <section class="trust-hero">
      <div class="trust-hero__main">
        <span class="eyebrow">Controlled knowledge · verified now</span>
        <h1>Find the instruction<br>you can act on.</h1>
        <p class="trust-hero__intro">Search only approved, effective guidance. Every result carries an owner, version and evidence trail.</p>
        <form class="hero-search" id="hero-search-form" role="search">${icon("search")}<label class="sr-only" for="hero-search-input">Search current guidance</label><input id="hero-search-input" type="search" placeholder="What do you need to do?"/><button class="button primary" type="submit">Search</button></form>
      </div>
      <aside class="trust-hero__aside">
        <div><span class="hero-assurance-label">Library assurance</span><p class="hero-assurance-value">99.8<span>%</span></p><p class="hero-assurance-copy">of visible documents are effective, owned and within review.</p></div>
        <div class="hero-assurance-foot"><span class="pulse-dot" aria-hidden="true"></span><span>Last control scan<br><strong>7 minutes ago</strong></span></div>
      </aside>
    </section>
    <div class="grid-2-1">
      ${panel("Current and recently used", "Approved documents from your work context", documentRows(currentDocs), '<button class="text-button" type="button" data-page="library">View library ' + icon("arrow") + '</button>', "flush")}
      <div>
        ${panel("Your obligations", `${outstanding.length} actions need your attention`, outstanding.length ? `<div class="obligation-list">${outstanding.map((doc) => `
          <button class="obligation-item" type="button" data-open-document="${doc.id}"><span class="due-tile"><strong>${doc.id === "WI-SEC-021" ? "27" : "29"}</strong><span>Aug</span></span><span class="obligation-copy"><strong>Acknowledge ${doc.type.toLowerCase()}</strong><span>${doc.title}</span></span>${icon("arrow")}</button>`).join("")}</div>` : emptyState("You are up to date", "There are no outstanding acknowledgements."), "", "flush")}
        <div style="height:20px"></div>
        ${panel("Common tasks", "Direct routes into governed work", `<div class="quick-link-grid">
          <button class="quick-link" type="button" data-page="library">${icon("library")}<span><strong>Browse processes</strong><small>Explore the controlled library</small></span>${icon("arrow")}</button>
          <button class="quick-link" type="button" data-action="request-change">${icon("change")}<span><strong>Suggest a change</strong><small>Flag unclear or outdated guidance</small></span>${icon("arrow")}</button>
          <button class="quick-link" type="button" data-action="open-help">${icon("alert")}<span><strong>Report an issue</strong><small>Tell document control</small></span>${icon("arrow")}</button>
        </div>`, "", "flush")}
      </div>
    </div>`;
}

function userLibrary(title = "Controlled library", source = documents, copy = "Search the approved source of truth by process, owner or document identifier.") {
  const items = filteredDocuments(source);
  const filters = [["all", "All"], ["effective", "Effective"], ["review-due", "Review due"], ["sop", "SOPs"], ["policy", "Policies"]];
  return `${heading("Authoritative source", title, copy)}
    <section class="panel flush">
      <div class="table-toolbar"><div class="table-search">${icon("search")}<label class="sr-only" for="library-search">Filter documents</label><input id="library-search" type="search" value="${escapeHTML(state.query)}" placeholder="Filter this view"/></div><span class="table-secondary">${items.length} documents</span></div>
      <div class="panel-body"><div class="filter-row">${filters.map(([key, label]) => `<button class="filter-chip ${state.filter === key ? "is-active" : ""}" type="button" data-filter="${key}">${label}</button>`).join("")}</div></div>
      ${documentRows(items)}
    </section>`;
}

function acknowledgementsPage() {
  const rows = documents.filter((doc) => doc.acknowledge).map((doc) => `<tr><td><span class="table-primary">${doc.title}</span><span class="table-secondary">${doc.id} · v${doc.version}</span></td><td>${doc.process}</td><td>${state.acknowledged.has(doc.id) ? status("Complete") : status("Outstanding")}</td><td>${state.acknowledged.has(doc.id) ? "25 Aug 2026" : doc.id === "WI-SEC-021" ? "27 Aug 2026" : "29 Aug 2026"}</td><td><button class="text-button" type="button" data-open-document="${doc.id}">${state.acknowledged.has(doc.id) ? "View evidence" : "Read and acknowledge"}</button></td></tr>`);
  return `${heading("Personal evidence", "My acknowledgements", "Read assigned guidance and retain a timestamped record of understanding.")}${panel("Assigned to you", "Evidence is retained with the document version you read", dataTable(["Document", "Process", "Status", "Due / completed", "Action"], rows, "My document acknowledgements"), "", "flush")}`;
}

function userPage() {
  if (state.page === "home") return userHome();
  if (state.page === "library") return userLibrary();
  if (state.page === "acknowledgements") return acknowledgementsPage();
  if (state.page === "favourites") return userLibrary("Favourites", documents.filter((doc) => state.favourites.has(doc.id)), "Your saved routes back to frequently used controlled guidance.");
  if (state.page === "recent") return userLibrary("Recently viewed", [documents[0], documents[4], documents[1], documents[7]], "Documents opened from your account during the last 30 days.");
  return userHome();
}

function metricsStrip(items) {
  return `<div class="metrics-strip">${items.map(([label, value, delta, bad]) => `<div class="metric-cell"><span class="metric-cell__label">${label}</span><strong class="metric-cell__value">${value}</strong><span class="metric-cell__delta ${bad ? "bad" : ""}">${delta}</span></div>`).join("")}</div>`;
}

function workSlip(item, accent = "var(--teal-600)") {
  return `<button class="work-slip" type="button" data-action="inspect-work" data-id="${item.id}" style="--slip-accent:${accent}"><span class="work-slip__id">${item.id}</span><strong>${escapeHTML(item.title)}</strong><span class="work-slip__foot"><span>${escapeHTML(item.owner || item.from || "Document control")}</span><span>${escapeHTML(item.age || item.due || "")}</span></span></button>`;
}

function controlTrack() {
  const stages = [
    ["01", "Request", "Triage and impact", [changes[0], changes[1]]],
    ["02", "In review", "Author, review, approve", [changes[2], { id: "DOC-482", title: "P1 outage communications v1.8", owner: "Maya Patel", age: "Due today" }]],
    ["03", "Activation", "Publish and notify", [changes[3]]],
    ["04", "Assurance", "Acknowledge and review", [{ id: "ACK-184", title: "Security instruction acknowledgement", owner: "Jon Bell", age: "84%" }, { id: "REV-392", title: "Quarterly operations document review", owner: "Maya Patel", age: "6 days" }]],
  ];
  return `<div class="control-track">${stages.map((stage, index) => `<section class="control-stage"><div class="control-stage__head"><span><span class="stage-index">${stage[0]}</span><strong>${stage[1]}</strong><small>${stage[2]}</small></span><span class="nav-item__count">${stage[3].length}</span></div><div class="stage-stack">${stage[3].map((item) => workSlip(item, index === 1 ? "var(--cobalt-500)" : index === 3 ? "var(--amber-500)" : "var(--teal-600)" )).join("")}</div></section>`).join("")}</div>`;
}

function assuranceLedger() {
  const items = [
    ["Effective documents", "98.7%", 98.7, "Within review and assigned"],
    ["Metadata completeness", "99.4%", 99.4, "Required fields populated"],
    ["Acknowledgement", "84.0%", 84, "Assigned readers complete"],
    ["Review timeliness", "96.2%", 96.2, "Reviews completed before due"],
  ];
  return `<div class="assurance-ledger">${items.map(([label, value, bar, help]) => `<div class="assurance-row"><span><strong>${label}</strong><span class="table-secondary">${help}</span></span><span class="assurance-bar" style="--bar:${bar}%;--bar-color:${bar < 90 ? "var(--amber-500)" : "var(--teal-600)"}"><span></span></span><span class="assurance-value">${value}</span></div>`).join("")}</div>`;
}

function teamControl() {
  return `${heading("Lifecycle operations", "Document control desk", "Move work through controlled stages and see where governance needs intervention.", button("New change request", { kind: "primary", action: "request-change", iconName: "plus" }))}
    ${metricsStrip([["Open lifecycle work", "7", "2 due today"], ["Documents in approval", "4", "Median 1.8 days"], ["Reviews due in 30 days", "12", "3 assigned this week"], ["Control exceptions", "2", "1 high priority", true]])}
    <section class="panel flush"><div class="panel-header"><div><h2 class="panel-title">Lifecycle control track</h2><span class="panel-subtitle">Work is grouped by governance state, not file location</span></div><button class="text-button" type="button" data-page="changes">Open register ${icon("arrow")}</button></div>${controlTrack()}</section>
    <div style="height:20px"></div>
    <div class="grid-2-1">
      ${panel("Priority queue", "Decisions and exceptions requiring a human owner", `<div class="obligation-list">
        <button class="obligation-item" type="button" data-page="approvals"><span class="due-tile"><strong>16</strong><span>00</span></span><span class="obligation-copy"><strong>Final approval due today</strong><span>Workplace incident reporting and investigation</span></span>${icon("arrow")}</button>
        <button class="obligation-item" type="button" data-page="exceptions"><span class="due-tile"><strong>02</strong><span>EX</span></span><span class="obligation-copy"><strong>Control exceptions open</strong><span>One high-severity metadata gap</span></span>${icon("arrow")}</button>
        <button class="obligation-item" type="button" data-page="calendar"><span class="due-tile"><strong>03</strong><span>REV</span></span><span class="obligation-copy"><strong>Reviews need assignment</strong><span>Due within the next seven days</span></span>${icon("arrow")}</button>
      </div>`, "", "flush")}
      ${panel("Control assurance", "Live health across your governed library", assuranceLedger())}
    </div>`;
}

function teamDocuments() {
  const rows = documents.map((doc) => `<tr><td><button class="text-button table-primary" type="button" data-open-document="${doc.id}">${doc.title}</button><span class="table-secondary">${doc.id} · ${doc.type}</span></td><td>${status(doc.status)}</td><td>v${doc.version}</td><td>${person(doc.owner)}</td><td>${doc.review}</td><td><button class="icon-button" type="button" data-open-document="${doc.id}" aria-label="Open ${escapeHTML(doc.title)}">${icon("arrow")}</button></td></tr>`);
  return `${heading("Controlled inventory", "Documents", "Administer metadata, ownership, versions and lifecycle state across your team.", button("Create controlled document", { kind: "primary", action: "new-document", iconName: "plus" }))}${metricsStrip([["Total controlled", "184", "+6 this quarter"], ["Effective", "169", "91.8% of library"], ["Draft / review", "13", "4 awaiting approval"], ["Overdue review", "2", "Action required", true]])}${panel("Team document register", "Operations, security, people and quality document sets", dataTable(["Document", "State", "Version", "Owner", "Next review", ""], rows, "Team document register"), "", "flush")}`;
}

function changesPage() {
  const rows = changes.map((item) => `<tr><td><span class="table-primary">${item.title}</span><span class="table-secondary">${item.id}</span></td><td>${item.stage}</td><td>${person(item.owner)}</td><td>${item.age}</td><td>${status(item.status === "Attention" ? "Review" : "On track")}</td><td><button class="text-button" type="button" data-action="inspect-work" data-id="${item.id}">Open</button></td></tr>`);
  return `${heading("Change governance", "Change requests", "Capture the reason, impact, evidence and approvals behind every controlled change.", button("New change request", { kind: "primary", action: "request-change", iconName: "plus" }))}${metricsStrip([["Open requests", "14", "+3 this week"], ["Median cycle time", "8.4d", "1.2d faster"], ["Awaiting impact", "3", "All assigned"], ["Past target", "1", "Escalated", true]])}${panel("Change register", "Evidence remains linked to the resulting document version", dataTable(["Request", "Stage", "Owner", "Age", "Health", ""], rows, "Document change requests"), "", "flush")}`;
}

function approvalsPage() {
  const remaining = approvals.filter((item) => !state.approved.has(item.id));
  const rows = remaining.map((item) => `<tr><td><span class="table-primary">${item.title}</span><span class="table-secondary">${item.id} · ${item.type}</span></td><td>${person(item.from)}</td><td>${item.risk === "High" ? status("Review") : status(item.risk)}</td><td>${item.due}</td><td><div class="inline-actions"><button class="button secondary" type="button" data-action="view-approval" data-id="${item.id}">Review</button><button class="button primary" type="button" data-action="approve" data-id="${item.id}">Approve</button></div></td></tr>`);
  return `${heading("Decision queue", "Approvals", "Review change evidence, separation of duties and the exact version awaiting release.")}${remaining.length ? panel("Awaiting decision", `${remaining.length} approvals assigned to your role`, dataTable(["Document", "Submitted by", "Risk", "Due", "Decision"], rows, "Pending document approvals"), "", "flush") : panel("Awaiting decision", "Your queue is clear", emptyState("All decisions recorded", "Completed approvals remain available in the audit history."))}`;
}

function calendarPage() {
  const labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const events = { 4: ["OPS-044 review"], 7: ["SEC-021 attest"], 10: ["FIN-008 review", "QUA-002 owner check"], 15: ["HSE-011 effective"], 18: ["PEO-006 review"], 24: ["Monthly control scan"] };
  const cells = Array.from({ length: 35 }, (_, i) => { const day = i < 3 ? 29 + i : i - 2; const muted = i < 3 || day > 30; const display = day > 30 ? day - 30 : day; return `<div class="calendar-cell ${muted ? "is-muted" : ""}"><span class="calendar-date">${display}</span>${(events[day] || []).map((event) => `<span class="calendar-event">${event}</span>`).join("")}</div>`; });
  return `${heading("Forward assurance", "Review calendar", "Plan review ownership before documents reach their due date.", button("Assign selected reviews", { kind: "primary", action: "assign-reviews" }))}<section class="panel flush"><div class="panel-header"><div><h2 class="panel-title">September 2026</h2><span class="panel-subtitle">Six lifecycle events · three require assignment</span></div><div class="inline-actions">${button("Previous", { action: "calendar-previous" })}${button("Next", { action: "calendar-next" })}</div></div><div class="data-table-wrap"><div class="calendar-grid">${labels.map((label) => `<div class="calendar-day-label">${label}</div>`).join("")}${cells.join("")}</div></div></section>`;
}

function exceptionsPage() {
  const open = exceptions.filter((item) => !state.resolved.has(item.id));
  const rows = open.map((item) => `<tr><td><span class="table-primary">${item.title}</span><span class="table-secondary">${item.id} · ${item.scope}</span></td><td>${item.severity === "High" ? status("Exception") : status("Review")}</td><td>${person(item.owner)}</td><td>${item.age}</td><td><button class="button secondary" type="button" data-action="resolve" data-id="${item.id}">Resolve</button></td></tr>`);
  return `${heading("Control assurance", "Exceptions", "Investigate deviations from the document control model and retain remediation evidence.")}${metricsStrip([["Open exceptions", String(open.length), open.length ? "Requires action" : "No open items", Boolean(open.length)], ["High severity", String(open.filter((i) => i.severity === "High").length), "Escalation threshold: 4h"], ["Median resolution", "1.7d", "Within 3d target"], ["30-day recurrence", "0", "No repeated controls"]])}${open.length ? panel("Exception register", "Ordered by severity and age", dataTable(["Exception", "Severity", "Owner", "Age", "Action"], rows, "Control exceptions"), "", "flush") : panel("Exception register", "All controls are within tolerance", emptyState("No open exceptions", "Remediation evidence is retained in the audit log."))}`;
}

function reportsPage() {
  return `${heading("Governance evidence", "Reports", "Turn operational signals into board, audit and process-owner evidence packs.", button("Export governance pack", { kind: "primary", action: "export", iconName: "download" }))}${metricsStrip([["Lifecycle compliance", "98.7%", "+0.8 points"], ["Approval SLA", "94.2%", "+2.1 points"], ["Acknowledgement", "84.0%", "Target 90%", true], ["Review on time", "96.2%", "+1.4 points"]])}<div class="grid-1-1">${panel("Assurance by control", "Current month · target shown at 95%", assuranceLedger())}${panel("Scheduled evidence packs", "Automatically produced and retained", `<div class="settings-list">${[["Monthly DMS control report", "Process owners · 1 Sep", "Active"], ["Quarterly audit evidence pack", "Internal audit · 30 Sep", "Active"], ["Acknowledgement exception digest", "Document control · Every Monday", "Active"]].map(([a,b,c]) => `<div class="setting-row"><span class="setting-copy"><strong>${a}</strong><span>${b}</span></span><span class="setting-value">PDF + Excel evidence</span>${status(c)}</div>`).join("")}</div>`)}</div>`;
}

function teamPage() {
  const pages = { control: teamControl, documents: teamDocuments, changes: changesPage, approvals: approvalsPage, calendar: calendarPage, exceptions: exceptionsPage, reports: reportsPage };
  return (pages[state.page] || teamControl)();
}

const sites = [
  ["Operations document centre", "OP-DMS-01", "184", "Healthy", "25 Aug · 09:42"],
  ["Information security", "IS-DMS-02", "96", "Healthy", "25 Aug · 09:38"],
  ["People operations", "HR-DMS-01", "72", "Healthy", "25 Aug · 09:31"],
  ["Quality management", "QM-DMS-01", "128", "Review", "25 Aug · 09:29"],
];

const flows = [
  ["DMS-Change-Control", "Solution-aware", "08:54", "Healthy", "1,284"],
  ["DMS-Publish-Effective", "Service account", "09:18", "Healthy", "602"],
  ["DMS-Notify-Expiry", "Individual owner", "08:01", "Exception", "421"],
  ["DMS-Acknowledgement", "Service account", "09:26", "Healthy", "3,918"],
  ["DMS-Control-Scan", "Service account", "09:42", "Healthy", "8,412"],
];

function eventStream() {
  const events = [
    ["09:42", "Control scan completed", "1,146 documents checked · 2 exceptions"],
    ["09:31", "Site owner recertified", "People operations · Anika Shah"],
    ["09:18", "Release activated", "SOP-OPS-014 v4.2 became effective"],
    ["08:54", "Automation policy evaluated", "All solution-aware flows compliant"],
    ["08:36", "Retention event registered", "12 superseded records entered retention"],
  ];
  return `<div class="event-stream">${events.map(([time, title, copy]) => `<div class="event-item"><span class="event-time">${time}</span><span class="event-copy"><strong>${title}</strong><span>${copy}</span></span></div>`).join("")}</div>`;
}

function controlMatrix() {
  const cells = [
    ["Sites", "04", "All provisioned from pattern", "sites", "Healthy"],
    ["Access", "12", "Groups reviewed this quarter", "sites", "Healthy"],
    ["Automations", "05", "One owner exception", "automations", "Review"],
    ["Retention", "07y", "Labels published and enforced", "retention", "Healthy"],
    ["Recovery", "4h", "Last restore test: 18 Aug", "recovery", "Healthy"],
    ["Configuration drift", "02", "Non-blocking deviations", "deployments", "Review"],
  ];
  return `<div class="control-matrix">${cells.map(([label, value, copy, page, stateLabel]) => `<button class="matrix-cell" type="button" data-page="${page}"><span class="matrix-cell__top"><span class="matrix-cell__label">${label}</span><span class="matrix-cell__signal ${stateLabel === "Review" ? "warning" : ""}" aria-label="${stateLabel}"></span></span><strong>${value}</strong><span>${copy}</span></button>`).join("")}</div>`;
}

function platformOverview() {
  return `${heading("Microsoft 365 control plane", "Platform assurance", "Observe the technical controls that keep governed document work reliable, recoverable and auditable.", button("Run control scan", { kind: "primary", action: "run-scan", iconName: "check" }))}
    <div class="health-banner"><span><strong>Platform operating within control tolerances</strong><span>Last complete scan: 25 Aug 2026 at 09:42 BST · 2 non-blocking exceptions</span></span>${status("Healthy")}</div>
    <div class="platform-map"><div>${controlMatrix()}</div>${panel("Live control events", "Unified audit, automation and deployment activity", eventStream(), '<button class="text-button" type="button" data-page="audit">Full audit ' + icon("arrow") + '</button>')}</div>
    <div style="height:20px"></div>
    <div class="grid-1-1">
      ${panel("Site estate", "Template alignment and inventory reach", `<div class="assurance-ledger">${sites.map((site) => `<div class="assurance-row"><span><strong>${site[0]}</strong><span class="table-secondary">${site[1]} · ${site[2]} documents</span></span><span class="assurance-bar" style="--bar:${site[3] === "Healthy" ? 100 : 86}%;--bar-color:${site[3] === "Healthy" ? "var(--teal-600)" : "var(--amber-500)"}"><span></span></span>${status(site[3])}</div>`).join("")}</div>`, '<button class="text-button" type="button" data-page="sites">Manage sites ' + icon("arrow") + '</button>')}
      ${panel("Automation runs", "Last 24 hours across managed flows", `<div class="settings-list">${flows.slice(0,4).map((flow) => `<div class="setting-row"><span class="setting-copy"><strong>${flow[0]}</strong><span>Last run ${flow[2]} · ${flow[4]} runs</span></span><span class="setting-value">${flow[1]}</span>${status(flow[3])}</div>`).join("")}</div>`, '<button class="text-button" type="button" data-page="automations">Open automation ' + icon("arrow") + '</button>')}
    </div>`;
}

function sitesPage() {
  const rows = sites.map((site) => `<tr><td><span class="table-primary">${site[0]}</span><span class="table-secondary">${site[1]}</span></td><td>${site[2]}</td><td>Document Owners · Approvers · Readers</td><td>${status(site[3])}</td><td>${site[4]}</td><td><button class="text-button" type="button" data-action="configure-site" data-id="${site[1]}">Configure</button></td></tr>`);
  return `${heading("Estate management", "Sites & access", "Provision consistent document centres and enforce group-based, least-privilege access.", button("Provision document centre", { kind: "primary", action: "provision-site", iconName: "plus" }))}${metricsStrip([["Managed sites", "4", "All template-linked"], ["Security groups", "12", "100% owner assigned"], ["Guest accounts", "3", "All expire in 30d"], ["Unique item permissions", "0", "Control satisfied"]])}${panel("Managed document centres", "Configuration baseline v3.6", dataTable(["Site", "Documents", "Access model", "Health", "Last scan", ""], rows, "Managed SharePoint document centres"), "", "flush")}`;
}

function automationsPage() {
  const rows = flows.map((flow) => `<tr><td><span class="table-primary">${flow[0]}</span><span class="table-secondary">Power Automate · managed solution</span></td><td>${flow[1]}</td><td>${flow[2]}</td><td>${status(flow[3])}</td><td>${flow[4]}</td><td><button class="text-button" type="button" data-action="inspect-flow" data-id="${flow[0]}">Inspect</button></td></tr>`);
  return `${heading("Workflow control", "Automations", "Monitor lifecycle flows, connection ownership, failure handling and solution deployment.", button("Run health check", { kind: "primary", action: "run-scan", iconName: "check" }))}<div class="health-banner"><span><strong>4 of 5 flows fully compliant</strong><span>DMS-Notify-Expiry requires migration to the document control service account.</span></span>${status("Review")}</div>${panel("Managed flows", "Production environment · rolling 30-day run count", dataTable(["Flow", "Ownership", "Last run", "Health", "30d runs", ""], rows, "Managed document lifecycle automations"), "", "flush")}`;
}

function retentionPage() {
  const rows = [
    ["Controlled business document", "7 years after superseded", "All document centres", "Published"],
    ["Policy and standard", "7 years after superseded", "Policy content types", "Published"],
    ["Approval evidence", "7 years after decision", "Approval register", "Published"],
    ["Change request evidence", "7 years after closure", "Change register", "Published"],
    ["Temporary working draft", "Delete after 180 days", "Draft libraries", "Review"],
  ].map((row) => `<tr><td><span class="table-primary">${row[0]}</span><span class="table-secondary">Microsoft Purview retention label</span></td><td>${row[1]}</td><td>${row[2]}</td><td>${status(row[3])}</td><td><button class="text-button" type="button" data-action="configure-label">View policy</button></td></tr>`);
  return `${heading("Records governance", "Records & retention", "Apply defensible retention to effective documents and their decision evidence.", button("Publish label update", { kind: "primary", action: "publish-label" }))}${metricsStrip([["Published labels", "5", "All sites synchronised"], ["Retained records", "1,462", "+38 this month"], ["Disposition due", "0", "Next: 14 Sep"], ["Policy conflicts", "0", "Control satisfied"]])}${panel("Retention label map", "Purview policies aligned to business lifecycle events", dataTable(["Label", "Retention", "Scope", "State", ""], rows, "Records retention label map"), "", "flush")}`;
}

function integrationsPage() {
  const items = [
    ["Microsoft Purview", "Retention labels, audit and eDiscovery", "Connected", "Service principal · least privilege"],
    ["Microsoft Entra ID", "Groups, conditional access and identity", "Connected", "Native tenant integration"],
    ["Power BI", "Governance reporting semantic model", "Connected", "Workspace service account"],
    ["Microsoft Teams", "Approval and acknowledgement notifications", "Connected", "Adaptive cards"],
    ["DocuSign", "External signature for selected records", "Disabled", "Optional integration"],
  ];
  return `${heading("Service boundaries", "Integrations", "Understand what crosses each boundary, how it authenticates and who owns it.")}${panel("Connected services", "Production tenant integration register", `<div class="settings-list">${items.map(([name, copy, value, detail], index) => `<div class="setting-row"><span class="setting-copy"><strong>${name}</strong><span>${copy}</span></span><span class="setting-value">${detail}</span><button class="toggle ${value === "Connected" ? "is-on" : ""}" type="button" role="switch" aria-checked="${value === "Connected"}" aria-label="${value === "Connected" ? "Disable" : "Enable"} ${name}" data-action="toggle-integration" data-id="${index}"><span></span></button></div>`).join("")}</div>`)}`;
}

function deploymentsPage() {
  const rows = [
    ["REL-2026.08.3", "Production", "Metadata validation + dashboard fix", "25 Aug · 07:30", "Successful"],
    ["REL-2026.08.2", "Production", "Acknowledgement evidence schema", "18 Aug · 06:45", "Successful"],
    ["REL-2026.08.1", "Production", "Content type baseline v3.6", "04 Aug · 07:10", "Successful"],
    ["REL-2026.09-RC1", "Test", "Review delegation and escalation", "24 Aug · 14:20", "Review"],
  ].map((row) => `<tr><td><span class="table-primary">${row[0]}</span><span class="table-secondary">Managed solution</span></td><td>${row[1]}</td><td>${row[2]}</td><td>${row[3]}</td><td>${status(row[4])}</td><td><button class="text-button" type="button" data-action="view-release">Evidence</button></td></tr>`);
  return `${heading("Configuration delivery", "Deployments", "Move versioned SharePoint, Power Platform and reporting configuration through governed environments.", button("Prepare deployment", { kind: "primary", action: "prepare-release", iconName: "deploy" }))}${metricsStrip([["Production baseline", "v3.6", "Aligned across 4 sites"], ["Pending release", "1", "In test validation"], ["Deployment success", "100%", "Last 12 months"], ["Configuration drift", "2", "Non-blocking", true]])}${panel("Release ledger", "Evidence-linked solution deployments", dataTable(["Release", "Environment", "Scope", "Deployed", "Result", ""], rows, "Configuration deployment ledger"), "", "flush")}`;
}

function recoveryPage() {
  return `${heading("Operational resilience", "Recovery", "Prove that document content, configuration and lifecycle evidence can be restored.", button("Start recovery exercise", { kind: "primary", action: "recovery-test" }))}
    ${metricsStrip([["Recovery point objective", "24h", "Current: 6h"], ["Recovery time objective", "4h", "Test result: 2h 14m"], ["Last restore test", "18 Aug", "Passed all checks"], ["Open findings", "0", "No remediation due"]])}
    <div class="grid-1-1">${panel("Recovery coverage", "What is protected and how it returns", `<div class="settings-list">${[["SharePoint content", "Microsoft 365 native recovery + backup", "Daily"], ["Power Platform solutions", "Versioned managed solutions", "Each release"], ["Configuration baseline", "PnP templates and source control", "Each change"], ["Audit and evidence exports", "Immutable evidence repository", "Daily"]].map(([a,b,c]) => `<div class="setting-row"><span class="setting-copy"><strong>${a}</strong><span>${b}</span></span><span class="setting-value">${c}</span>${status("Healthy")}</div>`).join("")}</div>`) }${panel("Last exercise · REX-2026-03", "18 August 2026 · completed in 2h 14m", lifecycleSpine(5))}</div>`;
}

function auditPage() {
  const rows = [
    ["09:42:17", "DMS.ControlScan.Completed", "svc-dms-platform", "Tenant", "Success"],
    ["09:31:04", "DMS.Access.Recertified", "anika.shah", "HR-DMS-01", "Success"],
    ["09:18:33", "DMS.Document.Activated", "svc-dms-release", "SOP-OPS-014", "Success"],
    ["08:54:11", "DMS.Flow.PolicyEvaluated", "svc-dms-platform", "Power Platform", "Success"],
    ["08:36:49", "DMS.Retention.Registered", "svc-purview", "12 records", "Success"],
    ["08:01:22", "DMS.Flow.OwnerException", "svc-dms-platform", "DMS-Notify-Expiry", "Review"],
  ].map((row) => `<tr><td><span class="table-primary">${row[0]}</span><span class="table-secondary">25 Aug 2026 BST</span></td><td><span class="doc-id">${row[1]}</span></td><td>${row[2]}</td><td>${row[3]}</td><td>${status(row[4])}</td><td><button class="text-button" type="button" data-action="audit-detail">Inspect</button></td></tr>`);
  return `${heading("Evidence trail", "Audit", "Search a correlated record of user, lifecycle, configuration and automation activity.", button("Export filtered evidence", { kind: "primary", action: "export", iconName: "download" }))}${panel("Unified audit events", "Microsoft Purview + DMS evidence register · timestamps shown in BST", dataTable(["Time", "Event", "Actor", "Object", "Result", ""], rows, "Unified platform audit events"), "", "flush")}`;
}

function platformPage() {
  const pages = { platform: platformOverview, sites: sitesPage, automations: automationsPage, retention: retentionPage, integrations: integrationsPage, deployments: deploymentsPage, recovery: recoveryPage, audit: auditPage };
  return (pages[state.page] || platformOverview)();
}

function render() {
  renderNav();
  const content = state.role === "user" ? userPage() : state.role === "team" ? teamPage() : platformPage();
  els.main.innerHTML = `<div class="page-enter">${content}</div>`;
  document.title = `${roles[state.role].label} · SOL Document Control`;
}

function closeRoleMenu() {
  els.roleMenu.classList.remove("is-open");
  els.roleButton.setAttribute("aria-expanded", "false");
}

function closeMobileNav() {
  els.sidebar.classList.remove("is-open");
  els.mobileButton.setAttribute("aria-expanded", "false");
  els.mobileScrim.hidden = true;
  if (mobileMedia.matches) {
    els.sidebar.inert = true;
    els.sidebar.setAttribute("aria-hidden", "true");
  }
}

function syncSidebarAccess() {
  const mobileAndClosed = mobileMedia.matches && !els.sidebar.classList.contains("is-open");
  els.sidebar.inert = mobileAndClosed;
  if (mobileAndClosed) els.sidebar.setAttribute("aria-hidden", "true");
  else els.sidebar.removeAttribute("aria-hidden");
}

function showToast(title, copy = "") {
  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `<span class="toast-mark">${icon("check")}</span><span><strong>${escapeHTML(title)}</strong>${copy ? `<span>${escapeHTML(copy)}</span>` : ""}</span><button class="toast-close" type="button" aria-label="Dismiss notification">${icon("close")}</button>`;
  els.toastRegion.append(toast);
  toast.querySelector("button").addEventListener("click", () => toast.remove());
  window.setTimeout(() => toast.remove(), 4600);
}

function requestConfirmation({ kicker = "Confirm action", title, copy, actionLabel = "Continue", onConfirm }) {
  els.confirmKicker.textContent = kicker;
  els.confirmTitle.textContent = title;
  els.confirmCopy.textContent = copy;
  els.confirmAction.textContent = actionLabel;
  state.pendingConfirm = onConfirm;
  els.confirmDialog.showModal();
}

function drawerDocument(doc) {
  const acknowledged = state.acknowledged.has(doc.id);
  const favourite = state.favourites.has(doc.id);
  const actionButton = doc.acknowledge && !acknowledged
    ? `<button class="button primary" type="button" data-action="acknowledge" data-id="${doc.id}">${icon("check")}Acknowledge v${doc.version}</button>`
    : `<button class="button primary" type="button" data-action="open-file">${icon("external")}Open document</button>`;
  return `<header class="drawer-head">
      <button class="icon-button drawer-close" type="button" data-action="close-drawer" aria-label="Close document details">${icon("close")}</button>
      <span class="eyebrow">${doc.type} · ${doc.id}</span><h2 id="drawer-title">${escapeHTML(doc.title)}</h2>
      <div class="drawer-action-row">${actionButton}<button class="button ghost" type="button" data-action="favourite" data-id="${doc.id}">${icon("star")}${favourite ? "Saved" : "Save"}</button></div>
    </header>
    <div class="drawer-body">
      <section class="drawer-section"><div class="inline-actions" style="justify-content:space-between"><div><span class="eyebrow">Current controlled release</span><h3>Version ${doc.version}</h3></div>${status(doc.status)}</div><p>This is the authoritative release for ${doc.process.toLowerCase()}. Printed or downloaded copies may become uncontrolled.</p></section>
      <section class="drawer-section"><h3>Control metadata</h3><div class="metadata-grid">
        <div class="metadata-item"><span>Document owner</span><strong>${doc.owner}</strong></div><div class="metadata-item"><span>Business process</span><strong>${doc.process}</strong></div>
        <div class="metadata-item"><span>Effective date</span><strong>${doc.date}</strong></div><div class="metadata-item"><span>Next review</span><strong>${doc.review}</strong></div>
        <div class="metadata-item"><span>Content type</span><strong>${doc.type}</strong></div><div class="metadata-item"><span>Record label</span><strong>Controlled · 7 years</strong></div>
      </div></section>
      <section class="drawer-section"><h3>Lifecycle evidence</h3>${lifecycleSpine(doc.status === "Effective" || doc.status === "Review due" ? 3 : 2)}</section>
      <section class="drawer-section"><h3>Version history</h3><div class="version-list">
        <div class="version-row"><span class="version-number">v${doc.version}</span><span><strong>Current release</strong><small>Approved by the process owner · ${doc.date}</small></span>${status(doc.status)}</div>
        <div class="version-row"><span class="version-number">v${Math.max(1, Number(doc.version) - 0.1).toFixed(1)}</span><span><strong>Superseded release</strong><small>Retained as a controlled record</small></span>${status("Superseded")}</div>
      </div></section>
    </div>`;
}

function openDocument(id, trigger) {
  const doc = documents.find((item) => item.id === id);
  if (!doc) return;
  state.lastFocus = trigger || document.activeElement;
  els.drawerContent.innerHTML = drawerDocument(doc);
  els.drawer.inert = false;
  els.appShell.inert = true;
  els.drawer.classList.add("is-open");
  els.drawer.setAttribute("aria-hidden", "false");
  els.drawerScrim.hidden = false;
  document.body.classList.add("drawer-open");
  window.requestAnimationFrame(() => els.drawer.querySelector(".drawer-close")?.focus());
}

function closeDrawer() {
  els.drawer.classList.remove("is-open");
  els.drawer.setAttribute("aria-hidden", "true");
  els.drawerScrim.hidden = true;
  els.drawer.inert = true;
  els.appShell.inert = false;
  document.body.classList.remove("drawer-open");
  state.lastFocus?.focus?.();
}

function navigate(page, focus = true) {
  state.page = page;
  state.query = "";
  state.filter = "all";
  els.globalSearch.value = "";
  closeMobileNav();
  render();
  if (focus) els.main.focus({ preventScroll: true });
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function genericAction(action, id) {
  const messages = {
    "request-change": ["Change request started", "A governed request form would open in the production system."],
    "new-document": ["Controlled document workspace prepared", "The production version would create a draft from an approved template."],
    "assign-reviews": ["Review assignment opened", "Select owners and due dates in the production workflow."],
    "calendar-previous": ["Previous month selected", "Calendar navigation is represented in this prototype."],
    "calendar-next": ["Next month selected", "Calendar navigation is represented in this prototype."],
    "export": ["Evidence pack queued", "The export will preserve active filters and control timestamps."],
    "run-scan": ["Control scan started", "Site, access, automation and retention controls are being evaluated."],
    "provision-site": ["Provisioning workflow opened", "A production request would apply the approved site template and access model."],
    "configure-site": ["Site configuration opened", `${id || "The site"} remains protected by the production baseline.`],
    "inspect-flow": ["Automation evidence opened", `${id || "The selected flow"} includes run history, ownership and exception handling.`],
    "configure-label": ["Retention policy opened", "Changes require records-management approval before publication."],
    "publish-label": ["Publication gate opened", "The label update requires a records-owner decision."],
    "view-release": ["Release evidence opened", "Validation, approval and deployment logs remain linked."],
    "prepare-release": ["Deployment plan prepared", "The production workflow would promote a versioned managed solution."],
    "recovery-test": ["Recovery exercise opened", "A timed runbook and evidence checklist would now start."],
    "audit-detail": ["Correlated audit event opened", "The production view would include the source record and correlation identifier."],
    "open-help": ["Help centre opened", "Role-aware guidance and the document control glossary would appear here."],
    "inspect-work": ["Lifecycle work item opened", `${id || "The selected item"} remains linked to its evidence and owner.`],
    "view-approval": ["Approval evidence opened", "Review the exact release, change rationale and separation-of-duties checks."],
    "open-file": ["Opening authoritative document", "In Microsoft 365 this launches the effective SharePoint file."],
  };
  const [title, copy] = messages[action] || ["Action represented", "This interaction would connect to the governed Microsoft 365 service."];
  showToast(title, copy);
}

function handleAction(action, id, trigger) {
  if (action === "close-drawer") return closeDrawer();
  if (action === "acknowledge") {
    const doc = documents.find((item) => item.id === id);
    return requestConfirmation({ kicker: "Attestation", title: `Acknowledge version ${doc.version}?`, copy: "You confirm that you have read and understood this controlled instruction. Your identity, document version and timestamp will be retained.", actionLabel: "Record acknowledgement", onConfirm: () => { state.acknowledged.add(id); closeDrawer(); render(); showToast("Acknowledgement recorded", `${id} v${doc.version} is now in your evidence history.`); } });
  }
  if (action === "approve") {
    const item = approvals.find((approval) => approval.id === id);
    return requestConfirmation({ kicker: "Controlled decision", title: "Approve this release?", copy: `Your approval will be bound to ${item.id}, the reviewed version and its change evidence.`, actionLabel: "Approve release", onConfirm: () => { state.approved.add(id); render(); showToast("Approval recorded", `${item.id} has advanced to the next lifecycle stage.`); } });
  }
  if (action === "resolve") {
    const item = exceptions.find((exception) => exception.id === id);
    return requestConfirmation({ kicker: "Exception remediation", title: "Mark this exception resolved?", copy: "Resolution should only be recorded after corrective evidence has been attached and the control has been re-tested.", actionLabel: "Record resolution", onConfirm: () => { state.resolved.add(id); render(); showToast("Exception resolved", `${item.id} is retained with its remediation evidence.`); } });
  }
  if (action === "favourite") {
    if (state.favourites.has(id)) state.favourites.delete(id); else state.favourites.add(id);
    const doc = documents.find((item) => item.id === id);
    els.drawerContent.innerHTML = drawerDocument(doc);
    showToast(state.favourites.has(id) ? "Saved to favourites" : "Removed from favourites", id);
    return;
  }
  if (action === "toggle-integration") {
    const toggle = trigger.closest("[role=switch]");
    const turningOn = toggle.getAttribute("aria-checked") !== "true";
    return requestConfirmation({ kicker: "Integration boundary", title: `${turningOn ? "Enable" : "Disable"} this integration?`, copy: "A production change requires an owner, impact assessment and approved deployment window.", actionLabel: "Record proposed change", onConfirm: () => { toggle.setAttribute("aria-checked", String(turningOn)); toggle.classList.toggle("is-on", turningOn); showToast("Proposed integration change recorded", "No live tenant connection was changed in this prototype."); } });
  }
  genericAction(action, id);
}

document.addEventListener("click", (event) => {
  const roleTarget = event.target.closest("[data-role]");
  if (roleTarget) {
    state.role = roleTarget.dataset.role;
    state.page = roles[state.role].start;
    state.query = "";
    state.filter = "all";
    closeRoleMenu();
    render();
    els.main.focus({ preventScroll: true });
    return;
  }
  const pageTarget = event.target.closest("[data-page]");
  if (pageTarget) return navigate(pageTarget.dataset.page);
  const docTarget = event.target.closest("[data-open-document]");
  if (docTarget) return openDocument(docTarget.dataset.openDocument, docTarget);
  const actionTarget = event.target.closest("[data-action]");
  if (actionTarget) return handleAction(actionTarget.dataset.action, actionTarget.dataset.id, actionTarget);
  if (!event.target.closest(".role-context")) closeRoleMenu();
});

els.roleButton.addEventListener("click", () => {
  const open = !els.roleMenu.classList.contains("is-open");
  els.roleMenu.classList.toggle("is-open", open);
  els.roleButton.setAttribute("aria-expanded", String(open));
  if (open) els.roleMenu.querySelector('[aria-selected="true"]')?.focus();
});

els.globalSearch.addEventListener("keydown", (event) => {
  if (event.key !== "Enter") return;
  event.preventDefault();
  state.query = els.globalSearch.value;
  if (state.role !== "user") state.role = "user";
  state.page = "library";
  state.filter = "all";
  render();
  els.main.focus({ preventScroll: true });
});

els.mobileButton.addEventListener("click", () => {
  const open = !els.sidebar.classList.contains("is-open");
  els.sidebar.classList.toggle("is-open", open);
  els.mobileButton.setAttribute("aria-expanded", String(open));
  els.mobileScrim.hidden = !open;
  els.sidebar.inert = !open;
  if (open) els.sidebar.removeAttribute("aria-hidden");
  else els.sidebar.setAttribute("aria-hidden", "true");
});

els.mobileScrim.addEventListener("click", closeMobileNav);
els.drawerScrim.addEventListener("click", closeDrawer);

els.confirmDialog.addEventListener("close", () => {
  if (els.confirmDialog.returnValue === "confirm" && state.pendingConfirm) state.pendingConfirm();
  state.pendingConfirm = null;
});

document.addEventListener("submit", (event) => {
  if (event.target.id !== "hero-search-form") return;
  event.preventDefault();
  state.query = event.target.querySelector("input").value;
  state.page = "library";
  render();
  els.main.focus({ preventScroll: true });
});

document.addEventListener("input", (event) => {
  if (event.target.id !== "library-search") return;
  state.query = event.target.value;
  const position = event.target.selectionStart;
  render();
  const next = document.querySelector("#library-search");
  next?.focus();
  next?.setSelectionRange(position, position);
});

document.addEventListener("click", (event) => {
  const filter = event.target.closest("[data-filter]");
  if (!filter) return;
  state.filter = filter.dataset.filter;
  render();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeRoleMenu();
    closeMobileNav();
    if (els.drawer.classList.contains("is-open")) closeDrawer();
  }
  if (event.key === "/" && !event.ctrlKey && !event.metaKey && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement.tagName)) {
    event.preventDefault();
    els.globalSearch.focus();
  }
  if (event.key === "Tab" && els.drawer.classList.contains("is-open")) {
    const focusable = [...els.drawer.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')].filter((el) => !el.disabled);
    if (!focusable.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
});

mobileMedia.addEventListener("change", syncSidebarAccess);
els.drawer.inert = true;
syncSidebarAccess();
render();
