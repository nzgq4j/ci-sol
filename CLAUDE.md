# CLAUDE.md — working rules for this repository

Guidance for any agent or engineer working on this codebase.

## What this is

A Microsoft 365 Document Management System built to `SharePoint_DMS_PRD.md`. That PRD is the
authoritative baseline.

**Source-of-truth order:** PRD → approved architecture decisions (`docs/ARCHITECTURE_DECISIONS.md`) →
approved environment configuration → current official Microsoft documentation → explicit user
instruction → clearly labelled assumption.

If requirements conflict, record the conflict in `docs/OPEN_DECISIONS.md`. Do not silently pick a
materially different interpretation.

## Hard rules

### Never claim tenant work that did not happen
No site, library, list, column, content type, group, label or flow currently exists in any tenant.
Do not describe planned configuration as deployed. Plan output is a plan.

### Never fabricate API or cmdlet support
Every PnP cmdlet and parameter is verified against `tests/fixtures/pnp-cmdlet-index.json`, generated
from the PnP.PowerShell source at a recorded commit. `Test-DmsPnPCmdletUsage` fails the build on a
fabricated cmdlet or parameter. Two tests assert the guard itself still works.
`Get-PnPLabel` does not exist — the retention cmdlets are `Get-PnPRetentionLabel`,
`Get-PnPFileRetentionLabel`, `Set-PnPFileRetentionLabel`.

### Never invent a legal retention period
Every retention class carries `REQUIRES_RECORDS_APPROVAL` until Records Management and Legal approve
the file plan (OQ-03). A test asserts no period has been populated. Configuring retention before
approval causes over-retention or premature disposal (PRD R-03).

### Never enable irreversible controls
Regulatory records, Preservation Lock and automatic permanent deletion are prohibited without three
things together: the environment flag, an explicit switch, and a signed decision record.
They cannot be undone by anyone (PRD SEC-012, C-005, R-06).

### Never commit a credential
No secret, certificate, token or connection string. `.env.example` and `environments.example.json`
hold placeholders only. Logs and exception text pass through `Protect-DmsSensitiveText`.

### Production defaults to blocked
`allowProductionChanges` defaults to `false`. `Test-DmsProductionGuard` enforces seven conditions and
reports all failures at once. Nothing bypasses it.

### Never deploy into an existing business site
`SOLEngineering`, `Gemini`, `LOGZONE` and the other tenant sites hold live client proposal material.
The DMS goes in its own site.

## Design invariants

| Invariant | Why | Enforced by |
|---|---|---|
| Business Lifecycle Status ≠ SharePoint Approval Status | "Approved" alone never means "in use" | `config/lifecycle-states.json`; F-005 |
| At most one current effective revision per document and applicability | The core trust property | `Test-DmsEffectiveRevisionUniqueness`; F-013 |
| Approval applies only to the reviewed content | An approval of unseen content is worthless | `Test-DmsApprovalIntegrity`; ETag checked at submission, approval **and** activation |
| Evidence outlives the automation | Flow history expires; obligations do not | Approval Evidence list, automation-write-only |
| Blank form ≠ completed record | Different lifecycle, different retention | Separate content types and libraries |
| Metadata, not folders | Folder trees cannot carry lifecycle or retention | Folder creation disabled |
| Review dates never roll forward silently | Otherwise review becomes a formality | `Get-DmsNextReviewDate` refuses without a decision reference |
| The system refuses to guess an approval route | A wrong approver is worse than a blocked request | `Resolve-DmsRoutingRule` returns Ambiguous |

## Working practice

- **Plan before apply.** Both run the same comparison logic; only Apply executes the action
  scriptblocks. That is what makes the plan trustworthy.
- **Idempotent by default.** Reruns must be safe. Compliant resources are skipped.
- **Blocked is a valid, useful outcome.** A plan reporting 25 blocked actions is working correctly.
- **Config over code.** Routes, thresholds, schedules and review frequencies are configuration so
  ordinary changes need no code edit.
- **Generated docs stay generated.** `DATA_DICTIONARY.md`, `STATE_MODEL.md` and
  `REQUIREMENTS_TRACEABILITY.md` are produced by scripts. Edit the source, regenerate. CI fails on drift.

## Coding standards

PowerShell 7.2+, `Set-StrictMode -Version Latest`, advanced functions with parameter validation,
comment-based help on every public function, structured objects returned (not formatted text),
no global mutable state, errors never swallowed, bounded exponential backoff honouring `Retry-After`,
stable internal SharePoint field names, planning separated from mutation.

## Commands

```bash
./src/provisioning/Test-DmsConfiguration.ps1 -Environment dev   # validation gate
./src/provisioning/Deploy-Dms.ps1 -Environment dev -Mode Plan   # what would change
./src/reporting/New-DmsDocumentation.ps1                        # regenerate derived docs
./src/reporting/New-DmsTraceability.ps1                         # regenerate traceability
pwsh -c 'Invoke-Pester ./tests/pester'                          # tests
```

## Before you finish any change

1. `Test-DmsConfiguration.ps1` exits 0
2. Pester green
3. Generated docs regenerated
4. `docs/BUILD_STATUS.md` updated
5. No new claim of tenant work that did not happen
