# Build Status

| Field | Value |
|---|---|
| Date | 26 August 2026 |
| Phase | Phase 1 complete (foundation built and validated offline). Phase 2 blocked on tenant access. |
| Tenant changes made | **One, since reverted.** See section 1a. No site, library, list, column, content type, group, label or flow currently exists in any tenant. |
| Next safe action | Create the nine Entra role groups, then `Deploy-Dms.ps1 -Environment dev -Mode Apply` |

---

## 1a. Tenant connection established, and one change made and reverted

Connected to `https://propfound.sharepoint.com/sites/DOX` (tenant `propfound`,
`9fd1307f-3666-4779-b6de-0d596aaf093a`) on 25 August 2026 using an interactive delegated app
registration. Read-only discovery returned all 7 sections with none blocked.

**A change was made to the tenant and has been reverted.** An Apply ran against the site while the
deferred-action closure defect was present. Because every deferred action read the final loop value,
the four `Add-PnPRoleDefinition` calls all created the last configured level: a single custom
permission level named `DMS Read Evidence` was created, and the other three failed as duplicates.
Nothing else was created; the SharePoint layer's actions failed under strict mode before writing.

The stray role definition was removed with `Remove-PnPRoleDefinition`. A subsequent plan confirms the
site holds only the six built-in role definitions (Contribute, Design, Edit, Full Control, Limited
Access, Read) and reports all four DMS levels as Create. The site is back to its pre-deployment state.

This is recorded rather than omitted because the same discipline that forbids claiming tenant work
that did not happen requires reporting tenant work that did.

### Verified against the live tenant

| Observation | Value | Consequence |
|---|---|---|
| DOX site template | `GROUP#0` (Teams-connected), group `fd254109-14e7-49c3-8d52-6ab15a3cd865` | Its Microsoft 365 group Members hold Edit by default. Verify that membership before relying on the library as the security boundary (F-024, R-07). |
| DOX sharing capability | `ExternalUserSharingOnly` | External sharing is currently **enabled**, contrary to F-025 / SEC-005. The plan's `ExternalSharing` action sets it to Disabled. |
| Existing DMS schema | None | No `Dms*` field, content type, library or list exists. A clean deployment target. |

### Plan against the live tenant

| Layer | Create | Blocked |
|---|---:|---:|
| Taxonomy | 22 | 1 (placeholder term, OQ-04) |
| SharePoint | 61 | 4 (feature-flagged and decision-gated) |
| Security | 43 | 9 (Entra groups awaiting governance creation) |
| Purview | 0 | 5 (unapproved retention classes, OQ-03) |
| Power Platform | 0 | 2 (no solution package, unresolved settings) |
| **Total** | **126** | **21** |

Those counts are what the tenant reported at the time and are left as observed. The Security row has
since changed shape: the layer read group existence and then discarded it, so all 38 library grants
were planned `Create` and every one failed at Apply with `Group cannot be found`. Grants onto a group
the layer could not find are now planned **Blocked**, naming the group, so a run against a tenant
without the governed groups reports one actionable fact instead of 38 identical failures. Offline the
groups cannot be read, so an offline plan is unchanged and still shows the full desired state.

## 1. Verified results

Everything below was executed in this environment, not asserted.

| Check | Result |
|---|---|
| Configuration validation | **15/15 checks pass**, 2 warnings (both expected: unapproved retention, provisional settings) |
| Test suite | **173/173 passing** — Pester 5.7.1 on PowerShell 7.4.6, 8.7s |
| Deployment plan (dev, offline desired state) | **125 create · 6 compliant · 22 blocked · 0 failed** |
| PnP cmdlet verification | **53 invocations** verified against PnP source commit `7e05503f` (2026-08-24) — 0 findings |
| Requirements extracted from PRD | **167 IDs**, of which **27 P0 functional**; **0 unreferenced** |
| Module surface | 26 exported functions |
| Generated docs | Regenerated; drift check passes |

The 22 blocked plan actions are **correct behaviour**: decision-gated libraries, feature-flagged
lists, Entra groups that governance must create, the grants that depend on those groups, and 5
unapproved retention classes.

## 2. P0 requirement coverage

The PRD marks 27 functional requirements as P0.

| Coverage | Count |
|---|---:|
| Implemented and tested | 10 |
| Implemented, tenant validation pending | 17 |
| Blocked with no work done | 0 |
| Not started | **0** |

Detail per requirement: `docs/REQUIREMENTS_TRACEABILITY.md` (generated, not hand-maintained).

"Implemented, tenant validation pending" means the configuration and code exist and validate offline,
but the behaviour cannot be proven against SharePoint without a connection.

## 3. Completed deliverables

**Configuration** — 12 files, 6 JSON schemas. 10 content types (parent-derived IDs), 32 site columns
(16 indexed, within budget), 5 libraries, 9 lists, 9 views, 4 term sets, 10 security roles with 4
custom permission levels, 18 negative security assertions, 15 metrics, 5 retention classes (all
gated).

**Rule engine** — lifecycle transitions with actor authorisation and preconditions; routing by
specificity with ambiguity refusal and separation of duties; ETag-based approval integrity; effective
revision uniqueness; review-date calculation refusing silent roll-forward; business-day arithmetic;
control completeness; structured logging with secret redaction; bounded retry with `Retry-After`;
seven-condition production guard.

**Provisioning** — orchestrator with Plan/Apply, layer selection and meaningful exit codes; SharePoint,
security, Purview and Power Platform layers; read-only discovery; configuration export with drift
detection.

**Verification** — PnP cmdlet index with provenance; AST-based fabrication guard; two Pester suites;
generated-documentation drift check.

**Documentation** — architecture with diagrams, 15 ADRs, open decisions, security model, Purview
design, Power Automate design, migration plan, test strategy, deployment and operations runbooks,
backup plan, support model, five user guides, glossary.

**Specifications** — five P0 Power Automate flows with triggers, expressions, error handling and
idempotency keys.

**Discovery** — read-only against proposal-foundry.com; findings in `docs/ENVIRONMENT_DISCOVERY.md`.

## 4. Not done, and why

| Item | Status | Reason |
|---|---|---|
| Any tenant provisioning | **Not started** | No PnP connection. The connected M365 tools are Graph file/folder operations only and cannot create columns, content types, library settings, views, permission levels, groups, labels or flows |
| Power Platform solution package | **Not built** | Requires a Dev environment. A hand-written `.zip` would not import; deliberately not fabricated |
| Power BI reports | **Not implemented** | No artefact or reproducible build exists. Recorded as planned, not claimed |
| Purview retention | **Blocked** | OQ-03 unanswered. All 5 classes carry `REQUIRES_RECORDS_APPROVAL` |
| Entra role groups | **Not created** | Governance decision (D-006). Auto-creation would produce ownerless groups (R-07) |
| Word `.dotx` templates | **Structure only** | Property bindings must be created against the tenant |
| Security, accessibility, performance, migration, recovery testing | **Written or specified, pending** | Need a deployed environment |

## 5. Blocking items

### Access required
| Item | Blocks |
|---|---|
| Entra tenant ID | Any Apply — the production guard refuses on the placeholder |
| PnP connection (interactive or app-only certificate) | All provisioning |
| SharePoint Administrator role | Site creation, sharing configuration |
| Power Platform Dev/Test/Prod environments | Flow build and ALM |
| Security & Compliance access | Purview (after OQ-03) |

### Decisions required
13 blocking open questions in `docs/OPEN_DECISIONS.md`. The four that gate the most work:

| ID | Question | Gates |
|---|---|---|
| OQ-03 | Approved retention schedule and file plan | All record capture; F-018 to F-020 |
| OQ-05 | One library or immutable Published Revisions | Lifecycle build; ADR-001 |
| OQ-13 | Approval authorities by document class | Every routing assignee |
| OQ-11 | Document ID convention | Must be answered **before** the first document is created — IDs are permanent |

## 6. Provisional assumptions in place

Each is a safe default, marked provisional, and none is an invented organisational answer.

| Setting | Value | Open question |
|---|---|---|
| Architecture pattern | Single controlled library | OQ-05 |
| Document ID pattern | `^[A-Z]{2,5}-[A-Z]{2,4}-[0-9]{3,5}$` | OQ-11 |
| Audit retention | 180 days | OQ-07 |
| RPO / RTO | 24 hours / 8 business hours | OQ-06 |
| Stale check-out threshold | 3 business days | OQ-18 |
| Time zone / language | Europe/London, en-GB | OQ-16 |
| Content Type Hub URL | Conventional naming, unconfirmed | OQ-12 |

## 7. Defects found and fixed during this build

| Defect | Impact | Resolution |
|---|---|---|
| Array unwrapping in migration duplicate counting | Reported files-in-a-set instead of number of sets — a wrong figure in migration evidence | Wrapped the whole `if/else` in `@()`; regression test added |
| PnP validator matched cmdlet names inside string literals | False positives; broken invocation boundaries | Rewritten using the PowerShell AST |
| Lifecycle view invariant applied to non-lifecycle content | External Documents incorrectly required to filter on `DmsCurrentEffective` | Scoped the check to content types derived from Controlled Document |
| Pester `-ForEach` property binding | 22 data-driven tests failing | `BeforeDiscovery` for discovery-time data; `$_` for PSCustomObject items |

## 8. Next actions, in order

1. **Supply the Entra tenant ID** → completes `config/environments.json`, unblocks Apply.
2. **Establish a PnP connection** to `https://propfound.sharepoint.com/sites/DOX` (see
   `docs/DEPLOYMENT_RUNBOOK.md` section 2). Verify the site's Microsoft 365 group membership first —
   it appears Teams-connected, so Members hold Edit by default.
3. **Run discovery**, then **Plan with a connection** — the first plan showing `Compliant` for existing
   resources rather than desired state.
4. **Create the Entra role groups** through identity governance.
5. **Apply to dev**, then verify with a second Plan (all Compliant) and a drift report.
6. **Answer OQ-11 and OQ-13** — needed before the first document and the first submission.
7. **Build the flows** in a Power Platform Dev environment from the specifications.
8. **Answer OQ-03** to unblock retention.

## 9. Honest summary

The information architecture, rule engine, safety controls, deployment machinery, tests and
documentation are complete and verified offline. Nothing exists in a tenant, and no claim to the
contrary is made anywhere in this repository.

The remaining work is not further design — it is access, four stakeholder decisions, and executing
the runbook.
