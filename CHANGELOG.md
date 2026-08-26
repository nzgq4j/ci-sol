# Changelog

## [0.1.0] — 2026-08-25

Initial implementation against `SharePoint_DMS_PRD.md`. Nothing deployed to any tenant.

### Configuration
- 12 configuration files and 6 JSON schemas covering content types, site columns, libraries, lists,
  views, taxonomy, lifecycle states, routing rules, security roles, retention map, metrics and environments.
- 10 content types with stable, parent-derived IDs; 32 site columns; 16 indexed columns within budget.
- 10-state lifecycle model with 18 transitions, 4 non-transition events, declared invalid-transition
  behaviour, recovery rules and 16 executable conformance vectors.

### Rule engine (`DmsProvisioning`, 24 exported functions)
- Lifecycle transition validation with actor authorisation and precondition checking.
- Routing resolution by specificity, refusing ambiguous matches rather than guessing.
- Approval integrity via ETag comparison at submission, approval and activation.
- Effective-revision uniqueness checking per document and applicability context.
- Review-date calculation that refuses to roll forward without an attributable decision.
- Business-day arithmetic with holiday support; control-completeness evaluation.
- Structured logging with secret redaction; bounded retry honouring `Retry-After`.
- Production guard enforcing seven conditions, reporting all failures at once.

### Provisioning
- `Deploy-Dms.ps1` orchestrator with Plan/Apply, layer selection and meaningful exit codes.
- SharePoint, security, Purview and Power Platform layers; read-only discovery; configuration export
  with drift detection.
- Plan produces 104 create actions and 25 correctly blocked; reruns are deterministic.

### Verification
- PnP cmdlet and parameter index generated from PnP.PowerShell source at commit `7e05503f` (2026-08-24),
  committed with provenance; AST-based usage validation catches fabricated cmdlets and parameters.
- Pester suites covering the rule engine, provisioning behaviour, security model, retention gates and
  migration inventory.
- Generated documentation with CI drift detection.

### Documentation
- Architecture with Mermaid diagrams; 15 ADRs; open decisions with owners and safe defaults.
- Security, Purview, Power Automate, migration, test strategy, deployment, operations, backup and
  support documents; five user guides and a glossary.
- Five Power Automate flow specifications; no solution archive fabricated.

### Discovery
- Read-only discovery of the proposal-foundry.com tenant confirmed the PRD's predicted current state
  with evidence: 58,319 folders for one search term, revision state in filenames, no lifecycle fields.

### Fixed
- Array-unwrapping defect in migration duplicate counting that reported the number of files in a
  duplicate set instead of the number of sets. Regression test added.
- PnP usage validator rewritten from regular expressions to the PowerShell AST after false positives
  from cmdlet names inside string literals.
- Lifecycle view invariant scoped to lifecycle-managed content, so External Documents (which have no
  lifecycle status) are no longer incorrectly required to filter on `DmsCurrentEffective`.

### Known limitations
- No tenant deployment; no Power Platform solution package; Power BI not implemented.
- Retention blocked pending OQ-03; 13 blocking open questions recorded in `docs/OPEN_DECISIONS.md`.
