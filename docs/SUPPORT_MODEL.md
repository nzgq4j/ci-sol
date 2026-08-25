# Support Model

Implements PRD ADM-001, ADM-002, ADM-007, ADM-011.

## 1. Governance roles

**Not yet assigned.** PRD A-006 assumes Document Control and Records Management authorities are named
before build completion, and R-01 makes unassigned governance a launch blocker.

| Role | Accountable for | Assigned |
|---|---|---|
| Executive Sponsor | Funding, authority, cross-functional conflicts | **Outstanding** |
| Product Owner | Backlog, releases, metric definitions | **Outstanding** |
| Document Control authority | Lifecycle integrity, triage, publication, exceptions | **Outstanding — blocks production** |
| Records Manager | File plan, labels, disposition | **Outstanding — blocks OQ-03** |
| Security owner | Access model, sharing, incidents | **Outstanding** |
| Privacy owner | Personal data, retention of personal fields | **Outstanding** |
| Platform owner | Provisioning, flows, monitoring, recovery | **Outstanding** |

## 2. Support tiers

| Tier | Handles | Escalates when |
|---|---|---|
| Tier 1 — Service desk | Access requests, "where is the current version", link problems | Metadata or lifecycle state looks wrong |
| Tier 2 — Document Control | Triage, metadata correction, stale check-outs, publication queries, non-technical exceptions | Technical failure, integrity exception, retention issue |
| Tier 3 — Platform support | Flow failures, connections, provisioning, drift, restore | Records or security decision needed |
| Tier 4 — Records / Security / Legal | Retention, disposition, sharing exceptions, incidents | — |

**A Document Controller is not Tier 3, and a platform administrator is not Tier 2.** That separation
mirrors SEC-003: keeping platform administration away from content authority.

## 3. Severity model (proposed — OQ-18)

| Severity | Definition | Example | Target response |
|---|---|---|---|
| 1 Critical | Wrong revision presented as current, or controlled content exposed | `DuplicateCurrentRevision` reaching readers; guest access to controlled docs | Immediate |
| 2 High | Lifecycle blocked, or evidence integrity at risk | Activation failing; `MissingApprovalEvidence` | Same business day |
| 3 Medium | Degraded but workable | Stale check-outs; notification failures | Next business day |
| 4 Low | Cosmetic or informational | Search freshness delay | Scheduled |

Severity 1 maps directly to MET-014, whose target is zero.

## 4. Dependency register (ADM-007)

| Dependency | Pinned | Support ownership |
|---|---|---|
| `PnP.PowerShell` | ≥ 2.12.0 | **Community-led, not Microsoft product support.** Organisational owner: Platform owner. Upgrades tested in Dev with index regeneration before promotion. |
| `Microsoft.Online.SharePoint.PowerShell` | ≥ 16.0.24810.12000 | Microsoft |
| `ExchangeOnlineManagement` | ≥ 3.4.0 | Microsoft |
| `Microsoft.Graph.Authentication` | ≥ 2.19.0 | Microsoft |
| `Pester` | ≥ 5.5.0 | Community; test-only |

PnP PowerShell is community-led. This is stated explicitly because assuming Microsoft product support
for it is a common and consequential mistake: a breaking change carries no support SLA. The mitigation
is version pinning, the committed cmdlet index, and a regression test before upgrade.

## 5. Service change monitoring (ADM-011, R-15)

Monthly review of Microsoft Message Center and roadmap for changes affecting SharePoint connector
actions, list view threshold behaviour, retention labels, Approvals, and PnP releases. Any change
touching a P0 control triggers a regression run in Test before Prod.

## 6. Monthly service review

Metrics scorecard · incidents · aged exceptions · permission and sharing exceptions · owner status ·
licence and capacity · Microsoft roadmap · improvement backlog. Recorded with actions and owners.
