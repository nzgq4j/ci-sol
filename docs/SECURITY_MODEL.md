# Security Model

Implements PRD section 18 (SEC-001 to SEC-015) and F-024/F-025. Source of truth for the role matrix
is `config/security-roles.json`; this document explains it.

**This document makes no compliance or certification claim.** It describes controls and the evidence
each produces.

## 1. Principles

1. Access is granted **only** through Entra groups. Direct user permissions are reported as exceptions.
2. Editing a document never confers authority to publish or approve it.
3. Platform administration never confers content-approval authority.
4. Security boundaries are the **site** and the **library** — not the item.
5. External sharing is disabled on controlled sites by default.
6. Approval Evidence is written by one non-interactive identity and by nothing else.

## 2. Custom permission levels

Built-in levels do not express "contribute but never delete", which the lifecycle requires because
removal is a lifecycle action, not a delete (PRD F-020).

| Level | Based on | Change | Why |
|---|---|---|---|
| `DMS Contribute No Delete` | Contribute | remove `DeleteListItems`, `DeleteVersions` | Authors and business users must not delete controlled content or records |
| `DMS Approve` | Contribute | add `ApproveItems`; remove delete | Reviewers/approvers need to see minor versions and set approval, not delete |
| `DMS Records Control` | Contribute | add `ManageLists`, `ApproveItems` | Records Managers administer retention without site control |
| `DMS Read Evidence` | Read | add `ViewVersions` | Auditors need version history to reconstruct a lifecycle (NFR-012) |

## 3. Role matrix (summary)

| Role | Controlled Docs | Templates | Op. Records | Approval Evidence | Exceptions | Site |
|---|---|---|---|---|---|---|
| Readers | Read | Read | — | — | — | Read |
| Authors | Contribute No Delete | Read | — | — | — | Read |
| Reviewers | DMS Approve | — | — | Read Evidence | — | Read |
| Approvers | DMS Approve | — | — | Read Evidence | — | Read |
| Document Controllers | DMS Approve | Contribute No Delete | Read | Read Evidence | Contribute No Delete | Edit |
| Records Managers | Read | — | Records Control | Read Evidence | Contribute No Delete | Read |
| Platform Administrators | — | — | — | — | Contribute No Delete | **Full Control** |
| Auditors | Read Evidence | — | Read | Read Evidence | Read | Read |
| **Automation Service** | DMS Approve | — | — | **Contribute No Delete** | Contribute No Delete | Edit |

## 4. Separation of duties (SEC-003)

Three separations are enforced structurally, not by policy alone:

**Author cannot approve their own work.** `Resolve-DmsRoutingRule -SoleAuthor` removes the author
from every stage. If that empties a stage, resolution returns `Blocked` rather than proceeding with a
smaller approval set. Tested.

**Platform administrator is not a content approver.** Full Control is a provisioning necessity.
The compensating controls are: not a member of Approvers or Records Managers; approval routes never
resolve to the group; actions audited. A test asserts that no content role holds Full Control.

**Nobody can alter their own evidence.** No interactive role holds write on Approval Evidence —
including Document Control and platform administrators. A validation check fails the build if that
changes.

## 5. Draft security (F-004, A-008)

`DraftVersionVisibility = Approver` on Controlled Documents. Only the author and principals holding
`ApproveItems` can see minor versions. This — not a view filter — is what keeps drafts away from
readers. A view filter would still leak content to a user who queried directly.

## 6. External sharing (F-025, SEC-005)

Disabled in all three environments by default; asserted by test. The External Partners role exists in
configuration but is **not provisioned**.

Any exception requires: named sponsor, defined content scope, expiry date, Security/Privacy/Legal
approval, and an audit review cadence. Sharing configuration could **not** be verified against the
tenant during discovery, so F-025 is currently *designed, not verified*.

## 7. Automation identity and secrets (SEC-004)

- Dedicated service identity; no interactive sign-in.
- **At least two administrative co-owners** (PRD ADM-008), so offboarding does not orphan the flows.
- Connection references and environment variables — never hard-coded URLs, IDs or credentials.
- **No credential of any kind is committed.** `.env.example` and `environments.example.json` contain
  placeholders only. A test scans the repository for secret-shaped values.
- Every log record and exception description passes through `Protect-DmsSensitiveText`, which redacts
  bearer tokens, JWTs and credential key/value pairs. Tested.

## 8. Required API permissions

Produced by `Get-DmsRequiredApiPermission`, with justification for each.

### Provisioning
| API | Permission | Type | Why | Least-privilege note |
|---|---|---|---|---|
| SharePoint | `Sites.FullControl.All` | Application | Create site columns, content types, libraries, views, permission levels. Library moderation and permission-level creation are not available at a narrower scope. | Initial provisioning and Content Type Hub publishing only |
| SharePoint | `Sites.Selected` | Application | Target steady state once sites exist | Granted per site collection |
| Graph | `Group.Read.All` | Application | Validate role groups, detect ownerless groups | Read-only; group creation stays human-approved |
| Graph | `Directory.Read.All` | Application | Resolve owners/approvers to active identities | Read-only |

### Runtime
| API | Permission | Type | Why | Least-privilege note |
|---|---|---|---|---|
| SharePoint | `Sites.Selected` (write) | Application | Publish, set lifecycle metadata, write registers | DMS site collections only |
| Graph | `Mail.Send` | Application | Link-based notifications | Constrained to one sender mailbox by an Exchange application access policy, so it cannot send as arbitrary users |
| Graph | `User.Read.All` | Application | Detect departed owners and approvers | Read-only |

**Administrator consent** is required for every application permission and must be granted by a
Global Administrator or Privileged Role Administrator. Steps are in `docs/DEPLOYMENT_RUNBOOK.md`.

## 9. Negative test matrix

18 assertions in `config/security-roles.json` drive `tests/security`. Each must **fail** for the
named role. Examples: readers cannot read a minor version; authors cannot set lifecycle status or
publish; Document Control cannot alter completed evidence; Records Managers cannot approve content;
platform administrators never resolve as an approval assignee; anonymous and guest access is denied.

## 10. Evidence produced

| Control | Evidence |
|---|---|
| Role assignment | Permission export from `Export-DmsConfiguration.ps1` |
| Separation of duties | Routing resolution results; negative test output |
| Draft security | Library configuration snapshot; reader access test |
| External sharing | Site sharing capability in the drift report |
| Secret hygiene | Repository scan test; redaction tests |
| Privileged actions | Purview audit log; structured deployment logs with correlation IDs |
