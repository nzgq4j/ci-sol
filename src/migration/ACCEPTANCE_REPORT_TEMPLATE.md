# Pilot Migration Acceptance Report

| Field | Value |
|---|---|
| Batch ID | |
| Source | |
| Target | |
| Executed by | |
| Date | |

## 1. Counts

| Measure | Source | Target | Variance | Within tolerance |
|---|---:|---:|---:|:--:|
| Files inventoried | | | | |
| Files imported | | | | |
| Files quarantined | | | | |
| Total size (bytes) | | | | |

## 2. Quarantine analysis

| Reason | Count | Business decision required |
|---|---:|---|
| Revision encoded in filename | | Confirm revision and approval history |
| Status encoded in folder name | | Confirm lifecycle status |
| No identifiable owner | | Assign owner |
| Duplicate set | | Nominate the authoritative copy |
| Invalid name / excessive path | | Approve rename or restructure |

A high quarantine rate is a **finding about the source**, not a migration failure.

## 3. Metadata reconciliation

| Check | Result |
|---|---|
| Required metadata populated on all imported items | |
| Document IDs unique | |
| No duplicate current effective revision | |
| Provenance recorded on every imported item | |
| Permissions mapped to role groups, no direct user permissions | |

## 4. Chain of custody (where required)

| Measure | Result |
|---|---|
| Items hashed | |
| Hash matches source | |
| Mismatches | |

## 5. Source preservation

- [ ] Source content unmodified
- [ ] Source content not deleted
- [ ] Source retirement remains a separate, unauthorised decision

## 6. Outcome

- [ ] **Accepted** — reconciliation within tolerance
- [ ] **Accepted with actions** — actions listed below
- [ ] **Rejected** — source not fit to migrate; cleanse required

## 7. Sign-off

| Role | Name | Date |
|---|---|---|
| Migration lead | | |
| Business owner | | |
| Document Control | | |
| Records Management | | |

> Acceptance of this pilot does **not** authorise enterprise migration (PRD F-037).
