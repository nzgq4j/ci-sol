# Architecture Decision Records

Each record states the decision, why it was taken, what was rejected and what would change it.
A decision marked **Provisional** is a safe default chosen so work could continue; it is not an
organisational answer and must be confirmed before production.

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](#adr-001) | Single controlled library, not two | **Provisional** — blocked by OQ-05 |
| [ADR-002](#adr-002) | Selective check-out, co-authoring by default | Accepted |
| [ADR-003](#adr-003) | SharePoint Lists, not Dataverse | Accepted |
| [ADR-004](#adr-004) | Native forms first, Power Apps only on evidence | Accepted |
| [ADR-005](#adr-005) | Approval Evidence as a SharePoint list, automation-write-only | Accepted |
| [ADR-006](#adr-006) | Custom `DmsDocumentId`, not the SharePoint Document ID feature | Accepted |
| [ADR-007](#adr-007) | Business revision separate from SharePoint version | Accepted |
| [ADR-008](#adr-008) | Scheduled activation, not a waiting flow | Accepted |
| [ADR-009](#adr-009) | Item-level labels for records, policies for containers | **Provisional** — blocked by OQ-03 |
| [ADR-010](#adr-010) | Dedicated service identity with co-owners | Accepted |
| [ADR-011](#adr-011) | Indexed boolean for current-effective, not a derived value | Accepted |
| [ADR-012](#adr-012) | Backup selection deferred, versioning is not backup | **Provisional** — blocked by OQ-06 |
| [ADR-013](#adr-013) | No SPFx | Accepted |
| [ADR-014](#adr-014) | Migration provenance unknown by default | Accepted |
| [ADR-015](#adr-015) | Verify PnP cmdlets against source, not memory | Accepted |

---

## ADR-001
### Single controlled library versus a separate immutable Published Revisions library

**Status:** Provisional. Blocked by **OQ-05**. PRD risk R-20.

**Context.** Two patterns satisfy "one current effective revision":

- **Option A — one library.** Every revision is a version of one file. The approved major version is
  the effective revision.
- **Option B — two libraries.** Activation copies the approved artefact into a read-only Published
  Revisions library, so each approved revision is a separate immutable item.

**Decision.** Implement Option A as the default. Model Option B fully in configuration
(`libraries.json` key `PublishedRevisions`) behind a feature flag and this decision gate, so the
switch is a configuration change rather than a redesign.

**Why.** Option A is simpler, uses native versioning, avoids a duplicate-source-of-truth problem, and
meets the PRD's stated MVP treatment. Option B is genuinely stronger where a regulator or auditor
requires that an approved revision be a fixed artefact that cannot be altered even by an
administrator — but it introduces two places a reader could look, which is the exact confusion the
DMS exists to remove.

**Rejected.** Building both and deciding later. That would double the lifecycle logic and leave
neither properly tested.

**What would change it.** Quality, Legal or Records determining that immutability of each approved
revision is required. `Deploy-DmsSharePoint.ps1` currently reports the Published Revisions library as
`Blocked` with this ADR named, so the gate is visible in every plan.

---

## ADR-002
### Selective check-out rather than universal forced check-out

**Status:** Accepted. PRD C-004, R-04.

**Decision.** `ForceCheckout` is false on Controlled Documents and true on Templates only.

**Why.** Required check-out and simultaneous co-authoring are mutually exclusive. Applying forced
check-out everywhere is the intuitive "document control" setting and is the wrong one: it blocks
normal collaborative authoring and produces abandoned locks — PRD risk R-04. Templates are edited
rarely, by few people, where exclusive editing genuinely helps.

**Consequence.** Stale check-out detection (Flow 5) is mandatory, with reminders, escalation and a
justified controller override. Content is never auto-discarded.

---

## ADR-003
### SharePoint Lists rather than Dataverse for the workflow registers

**Status:** Accepted. PRD ADR requirement 3, D-002, C-002.

**Decision.** Document Register, Change Requests, Approval Evidence, Exceptions, Routing Rules,
Review Frequencies and Workflow Configuration are SharePoint lists.

**Why.** Dataverse offers a stronger relational model, real referential integrity and row-level
security — genuinely better for this shape of data. It is rejected for MVP because it carries a
premium licensing dependency that is **unconfirmed** (OQ-02), and because the registers must be
readable by the same permission model that governs the documents. Choosing Dataverse before the
licence position is known risks a late, expensive redesign (PRD risk R-02).

**Consequence.** Referential integrity is enforced in the flows and in the reconciliation sweep
rather than by the platform. This is a real cost and is why Flow 5 checks for orphaned evidence and
missing register entries.

**Revisit when.** OQ-02 is answered, or register volume exceeds comfortable list operation.

---

## ADR-004
### Native list forms first; Power Apps only where a validated need exists

**Status:** Accepted. PRD F-033, OQ-15, A-007.

**Decision.** Ship native SharePoint forms with JSON formatting. Power Apps is P1, contingent on
usability testing showing native forms fail (PRD NFR-008, UX-005).

**Why.** Power Apps adds licensing, ALM, accessibility-testing and support burden. The PRD requires
native capability to be validated first. Building an app before knowing native forms are inadequate
inverts that.

---

## ADR-005
### Approval Evidence as a SharePoint list writable only by the automation identity

**Status:** Accepted. PRD F-010, C-007, R-12, NFR-012.

**Decision.** A dedicated list. **No interactive role holds Contribute** — not authors, not
approvers, not Document Control, not platform administrators. The automation service identity is the
sole writer. Auditors and control roles read.

**Why.** Two failure modes are being prevented. First, flow run history expires long before a
retention obligation does, so evidence cannot live there. Second, evidence that its own subjects can
edit is not evidence. Restricting write access to a non-interactive identity is what makes a decision
record trustworthy after the fact.

**Consequence.** A correction cannot be made by editing a row. It is made by writing a new,
attributable record — which is the correct behaviour for an evidence trail.

**Validated by.** `Test-DmsConfiguration` check `ApprovalEvidenceSingleWriter`, which fails the build
if any other principal gains write access.

---

## ADR-006
### Custom `DmsDocumentId` rather than the built-in SharePoint Document ID

**Status:** Accepted. PRD F-002, OQ-11.

**Decision.** A governed `DmsDocumentId` column assigned at triage.

**Why.** The built-in Document ID service issues a tenant-format identifier that is not the
business's document numbering convention, cannot be pre-assigned at request time, and is not
controlled by Document Control. The PRD requires the ID to be assigned on request acceptance and to
survive rename and move — the business identifier must therefore be ours.

**Provisional element.** The **format** awaits OQ-11. The pattern lives in configuration, so
answering OQ-11 is a config edit, not a code change.

**Consequence.** Uniqueness must be enforced by the system: `Test-DmsDocumentId` performs a
case-insensitive duplicate check, and a collision blocks triage rather than silently taking the next
free number.

---

## ADR-007
### Business revision is not the SharePoint version

**Status:** Accepted. PRD DATA-002, section 2.8.

**Decision.** `DmsBusinessRevision` is the business identity of a revision. `DmsSharePointVersionRef`
records which platform version was published.

**Why.** SharePoint version numbers move for reasons that have no business meaning — a metadata edit,
a check-in, a workflow write. Presenting "version 7.0" to a reader as the revision would be wrong and
would change without approval. Recording the platform version alongside preserves the technical link
needed for evidence reconciliation.

---

## ADR-008
### Scheduled activation rather than a flow that waits for the effective date

**Status:** Accepted. PRD F-012, WF-03.

**Decision.** A daily scheduled sweep finds due revisions. No flow waits.

**Why.** An effective date can be months away. A waiting flow instance does not survive connection
expiry, solution reimport, owner offboarding or a flow version change — and its failure is silent,
which is the worst property for a publication control.

**Consequence.** Activation is idempotent and re-validating. A missed run self-corrects on the next
sweep; a duplicated run is a no-op because the guard checks `DmsCurrentEffective` first.

---

## ADR-009
### Item-level retention labels for record classes; container policies where treatment is uniform

**Status:** Provisional. Blocked by **OQ-03**. PRD F-018, R-03.

**Decision.** Labels for record classes; policies for uniform containers. **No retention
configuration is applied until the file plan is approved.**

**Why.** Policies cannot express mixed schedules within one library. Labels can, and support
event-based triggers and disposition review.

**Safety.** `Deploy-DmsPurview.ps1` refuses Apply while any class carries
`REQUIRES_RECORDS_APPROVAL`, and `retention-map.example.json` contains **no invented period**.
Configuring retention before approval causes over-retention, premature disposal or inaccessible
content — PRD risk R-03. A test asserts that no period has been invented.

**Explicitly excluded.** Regulatory records, Preservation Lock and automatic permanent deletion,
pending separate written authorisation (SEC-012, C-005, R-06).

---

## ADR-010
### Dedicated automation identity with at least two administrative co-owners

**Status:** Accepted. PRD SEC-004, ADM-008, R-09.

**Decision.** Flows run as a dedicated service identity, owned by at least two administrators,
using connection references. Credentials never enter the repository.

**Why.** Personally owned production flows break when the owner leaves — PRD risk R-09. A shared
identity with multiple owners survives offboarding, and connection references make the credential a
deployment-time input rather than a build-time constant.

---

## ADR-011
### `DmsCurrentEffective` stored as an indexed boolean rather than derived

**Status:** Accepted. PRD F-013, NFR-004.

**Decision.** Maintain a physical indexed boolean column.

**Why.** Every reader view filters on "is this the current revision". Deriving that at query time
(status = Effective AND latest revision) requires an unindexed or multi-column query that breaches
the list view threshold at the PRD's target of 50,000 documents.

**Cost, stated plainly.** A stored flag can drift from reality — two revisions could both be true if
activation half-completes. That risk is accepted and mitigated by making the flag reconcilable:
`Test-DmsEffectiveRevisionUniqueness` runs after every activation and on a schedule, and any drift
raises a High blocking exception. A derived value could not drift, but could not be queried at scale.

---

## ADR-012
### Backup service selection deferred; versioning and recycle bins are not a backup

**Status:** Provisional. Blocked by **OQ-06**. PRD NFR-013, R-13.

**Decision.** Do not select a backup product. Document the interim planning assumption (24-hour RPO,
8-business-hour RTO) and require a restore exercise before launch.

**Why.** Selecting Microsoft 365 Backup or a third party is a cost and capability decision that
depends on objectives nobody has yet approved. Choosing first and justifying afterwards is how an
organisation discovers its recovery capability does not match its expectation — PRD risk R-13.

**What is asserted now.** Version history and recycle bins protect against user error within a
retention window. They do not protect against a malicious administrator, a ransomware event that
outlasts the window, or a site deletion past the retention period. They are not a backup service.

---

## ADR-013
### No SharePoint Framework (SPFx) development

**Status:** Accepted. PRD A-007, section 11.2, MVP non-goal.

**Decision.** No SPFx. Native web parts and supported JSON view/column formatting only.

**Why.** The PRD requires a documented fit-gap analysis proving P0 requirements cannot be met
natively before SPFx is introduced. No such gap has been demonstrated: the current-document
experience is a filtered view on an indexed column, and the required result columns are all
metadata. SPFx would add a build chain, a security review, an accessibility surface and a support
burden for no proven P0 benefit.

**What would change it.** A validated P0 requirement that native capability demonstrably cannot meet,
recorded as a new ADR.

---

## ADR-014
### Migration provenance is unknown by default

**Status:** Accepted. PRD C-009, R-08, F-037, DATA-012.

**Decision.** Migrated content carries `DmsSourceProvenance` and a batch ID. Where owner, revision,
status or approval history cannot be established from source data, the item is **quarantined**, not
assigned a plausible value.

**Why.** Discovery of the actual source found revision state encoded in filenames (`-1_KLS_v2`, `-2`,
`Rev0`, `C - Gold`, `OBE`) and classification encoded in numbered folders. Inferring "this is
revision 2, approved" from a filename would manufacture control evidence that does not exist — which
is worse than an empty field, because it looks like evidence.

**Consequence.** The pilot will produce a quarantine list. That is a successful outcome, not a
failure: it makes the true data-quality position visible before enterprise migration is authorised.

---

## ADR-015
### Verify PnP cmdlet usage against source rather than trusting memory

**Status:** Accepted. Coding standards ("do not fabricate API or cmdlet support"); PRD ADM-006,
ADM-007.

**Context.** Cmdlet names and parameters change between PnP releases. `Get-PnPLabel`, for example,
does **not** exist in the current module; the retention cmdlets are `Get-PnPRetentionLabel`,
`Get-PnPFileRetentionLabel` and `Set-PnPFileRetentionLabel`. A plausible-looking but non-existent
cmdlet fails only at deployment time, against a tenant.

**Decision.** Generate a cmdlet and parameter index from the PnP.PowerShell source at a recorded
commit, commit it as `tests/fixtures/pnp-cmdlet-index.json`, and verify every invocation in the
repository against it using the PowerShell AST.

**Why the AST.** The first implementation used regular expressions and produced false positives from
cmdlet names inside string literals and comments, and could not determine where an invocation ended.
The parser resolves both problems exactly.

**Consequence.** `Test-DmsPnPCmdletUsage` runs offline in CI, and a fabricated cmdlet or parameter
fails the build. Two tests deliberately assert that it catches each case.

**Maintenance.** Regenerate the index when the pinned PnP version changes; the provenance commit and
date are recorded in the fixture.
