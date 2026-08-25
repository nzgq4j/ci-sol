# Backlog

Work identified but deliberately not started, with enough detail to pick up cold.

---

## BL-01 — Production UI implementation from the DMS prototype

**Status:** Not started. Recorded 25 August 2026 at the product owner's direction.
**Blocks:** nothing currently in flight. Depends on the SharePoint layer applying cleanly first.

### What this is

A three-layer handoff for building the production user interface, supplied by the product owner:

1. **The working prototype is the visual authority** — `dms-ui-prototype/` (index.html, styles.css,
   app.js, `preview-*.png`, `verify-ui.cjs`).
2. **A project-root `CLAUDE.md`** holding permanent design rules, using `@path` imports so the PRD
   and prototype README load automatically.
3. **A task-specific implementation prompt** carrying the delivery objective.

The prototype lives outside this repository, at
`C:\Users\david\OneDrive - Proposal-Foundry.com\03 - SOL`. There is also a copy at
`https://propfound.sharepoint.com/sites/SOLEngineering/Shared Documents/dms-ui-prototype`.

### Authority order supplied by the product owner

1. `SharePoint_DMS_PRD.md` — requirements, permissions, lifecycle behaviour, business rules.
2. `dms-ui-prototype/` — information architecture, visual design, interaction, responsive behaviour.
3. The production repository — engineering conventions and deployment architecture.
4. On conflict: stop and document it before changing intended behaviour.

This is consistent with the source-of-truth order already in `CLAUDE.md`; the prototype slots in as
design authority, subordinate to the PRD.

### Design constraints to carry forward

- Lifecycle state is the primary visual language; the "controlled knowledge desk" aesthetic is kept.
- Quiet document-paper surfaces, deep navy navigation, teal assurance, cobalt actions, amber
  warnings, red exceptions. Aptos / Segoe UI / Cascadia Mono fallbacks.
- Not a generic Fluent dashboard, and not interchangeable cards.
- Document identity, version, owner, effective state and review date visible at decision points.
- Authoritative, draft, in-review, effective, superseded and retained states clearly distinguished.
- Progressive disclosure for metadata and evidence; lifecycle spine preserved in document details.

### Three role experiences

| Role | Surface |
|---|---|
| End user | Discovery, controlled library, favourites, recents, acknowledgements |
| Team administrator | Lifecycle control desk, register, change requests, approvals, reviews, exceptions, reports |
| Platform administrator | Sites, access, automation, retention, integrations, deployment, recovery, audit |

**Access must be enforced by the identity and permission layer, not hidden in the interface.** That
matches the role model already in `config/security-roles.json`, whose negative assertions are the
test basis.

### Accessibility and responsiveness

Keyboard-only operation, visible focus, semantic landmarks, focus trapping in dialogs and drawers,
off-canvas navigation inert while closed, `prefers-reduced-motion` honoured, no document-level
horizontal overflow at 390px (tables may scroll inside bounded containers), and **lifecycle state
never conveyed by colour alone** — the rule already applied in `src/list-formatting/`.

### Engineering constraints

- Mock data and mock state management must not become production architecture.
- Separate presentation, domain logic and Microsoft 365 integrations.
- Centralised design tokens; reusable components for status, document rows, lifecycle spine,
  metrics, evidence history, tables, drawers, confirmation dialogs.
- Governed or destructive actions require explicit confirmation and produce evidence-friendly results.
- Never bypass SharePoint, Entra ID, Purview or Power Platform security controls in client code.
- Where a production integration is unavailable, use a typed adapter with clearly separated fixtures.
- Do not invent API endpoints, tenant identifiers, list GUIDs, credentials or security behaviour.

### Open decision before this can start

**Target stack is unspecified** — the prompt carries a `[INSERT TARGET STACK]` placeholder. The
candidate named is SPFx + React + TypeScript + Fluent UI + PnPjs.

This needs a decision recorded as an ADR, because **ADR-013 currently rejects SPFx**: the PRD makes
SPFx an explicit MVP non-goal (A-007, section 11.2) pending a documented fit-gap analysis proving P0
requirements cannot be met natively. Building the prototype as SPFx would supersede ADR-013 and
requires that analysis first.

Alternatives that would not disturb ADR-013: native SharePoint pages with JSON formatting (current
approach), or a Power Apps interface (F-033, P1, contingent on usability evidence per ADR-004).

### Acceptance gate supplied by the product owner

Build and type-check · run automated tests · exercise all three roles · test document opening,
search, acknowledgement, approval and exception resolution · inspect desktop and 390px layouts ·
check keyboard focus and modal behaviour · compare against the reference screenshots · report
intentional differences with rationale.

Browser tests and screenshot comparison are the real acceptance gate, since `CLAUDE.md` guides
behaviour rather than enforcing it.

### Why it is not started

The SharePoint layer is still being applied to the dev tenant and is not yet clean. A user interface
built against an incomplete schema would need reworking. This starts once
`Deploy-Dms.ps1 -Mode Plan` reports all Compliant, and once the stack decision above is recorded.
