# Reporting

| Script | Purpose | Tenant required |
|---|---|---|
| `Export-DmsMetrics.ps1` | Computes and exports the 15 metrics from `config/metrics.json` | Partially — definitions export offline |
| `New-DmsDocumentation.ps1` | Generates `DATA_DICTIONARY.md` and `STATE_MODEL.md` from configuration | No |
| `New-DmsTraceability.ps1` | Generates `REQUIREMENTS_TRACEABILITY.md` from the PRD and repository | No |

## Delivery tiers

1. **SharePoint list views** — live, no licence dependency, permission-trimmed by the platform.
   The Document Control Work Queue and the review reports are views, so they are inherently current.
2. **CSV / JSON export** — `Export-DmsMetrics.ps1`. Portable (NFR-018) and reconcilable to source.
3. **Power BI** — **not implemented.**

## On Power BI

No `.pbix`, no semantic model and no reproducible build process exists in this repository, so Power BI
is recorded as *planned*, not delivered. Claiming otherwise would misrepresent the state of the work,
and PRD section 10 explicitly forbids it. Its licence position is also unconfirmed (OQ-02).

The CSV export is designed as the ingestion source when Power BI is licensed and built.

## Metric integrity

Every exported row carries the formula, sources, refresh expectation, owner, visibility, exclusions
and a `DataAsOfUtc` timestamp alongside the value. PRD R-19 is that metrics without definitions and
owners drive the wrong behaviour, so the definition travels with the number rather than living in a
separate document.

Metrics that cannot be computed from SharePoint (findability testing, disposition backlog, recovery
conformance) export with a null value and their real source named. They are never estimated.
