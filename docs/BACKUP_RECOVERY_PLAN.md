# Backup and Recovery Plan

**Status: Provisional.** RPO and RTO are unapproved (OQ-06). No backup product has been selected.
See ADR-012.

## 1. What is asserted now

Version history and recycle bins are **not** a backup service. They protect against user error inside
a retention window. They do not protect against:

- a malicious or compromised administrator,
- ransomware whose dwell time exceeds the recycle-bin retention period,
- site deletion discovered after the retention period,
- a bulk metadata corruption applied through a script or flow.

Stating this matters because assuming otherwise is PRD risk **R-13** — recovery capability assumed
rather than tested.

## 2. Interim planning assumption

| Objective | Interim value | Status |
|---|---|---|
| RPO | 24 hours | **Assumption pending OQ-06** |
| RTO | 8 business hours | **Assumption pending OQ-06** |
| Exercise frequency | Quarterly | Assumption |

These are planning figures so design can proceed. They are **not** approved objectives and must not
be quoted to a business owner as a commitment.

## 3. Scope of protection

| Asset | Mechanism | Gap |
|---|---|---|
| Documents and versions | SharePoint versioning + recycle bin | No protection beyond retention window |
| Registers | Same | Same |
| Approval Evidence | Same + retention label (after OQ-03) | Evidence loss would be a control failure, not just data loss |
| Configuration | **Source control** — this repository | Fully recoverable by redeployment |
| Power Platform solution | Managed solution artefact | Recoverable by reimport |
| Entra groups | Identity governance | Outside this product |

Configuration is the one area with genuinely strong recovery: the entire information architecture can
be rebuilt from `config/*.json` by rerunning Apply. That is a direct benefit of configuration-as-code.

## 4. Selection criteria (pending OQ-06)

| Criterion | Microsoft 365 Backup | Third party |
|---|---|---|
| Granularity | Site level | Often item level |
| Retention | Product-defined | Configurable |
| Cost model | Per GB | Varies |
| Data residency | Inherits tenant | Verify |
| Restore of metadata and permissions | Verify | Verify |

Whichever is chosen, the acceptance test is the same: restore a representative site and reconcile
content, metadata, **permissions** and **approval evidence**. A restore that recovers files but loses
lifecycle metadata has not restored the DMS.

## 5. Restore exercise procedure

1. Select a representative site or library in a non-production environment.
2. Record pre-state: item counts, sample metadata, permission assignments, evidence row count.
3. Simulate loss (delete in a **non-production** environment only).
4. Restore using the selected service.
5. Reconcile:
   - item count matches
   - sampled `DmsDocumentId`, `DmsLifecycleStatus`, `DmsCurrentEffective`, `DmsEffectiveDate` match
   - permission assignments match the role matrix
   - Approval Evidence rows match, and each still references its correct revision and ETag
   - exactly one current effective revision per document (`Test-DmsEffectiveRevisionUniqueness`)
6. Measure elapsed time against RTO and data currency against RPO.
7. Record the result (MET-015). A failed restore escalates to the continuity owner.

Step 5's last check matters: a restore that reintroduces a superseded revision as current would
silently break the core invariant.

## 6. Rollback (referenced by the production guard)

| Scenario | Rollback |
|---|---|
| Deployment applied wrong configuration | Correct `config/*.json`, rerun Plan, review, Apply. Idempotent. |
| Solution import broke a flow | Reimport the previous managed solution version |
| Retention label applied in error | **May not be reversible.** Records Management decision. This is why labels are gated behind OQ-03 |
| Regulatory record applied in error | **Not reversible by anyone.** This is why it is prohibited in MVP (SEC-012) |
| Site created in the wrong place | `Remove-PnPTenantSite` in dev only; production requires change approval |

The two irreversible rows are the reason the Purview gate exists. There is no rollback to design for;
prevention is the only control.

## 7. What must happen before launch

- [ ] OQ-06 answered: approved RPO, RTO, scope, exercise cadence
- [ ] Backup service selected and provisioned
- [ ] Restore access restricted, logged, and separated from content roles (SEC-015)
- [ ] One successful restore exercise with full reconciliation
- [ ] Escalation path for a failed restore
