# Tenant configuration required before production

No tenant identifiers or policy choices below can be derived from this repository. The package intentionally remains unconfigured until accountable owners supply and approve them.

## Technical installation inputs

- SharePoint Online tenant, App Catalog and target site URLs
- controlled-document site/library and supporting register locations or IDs
- content type and site-column IDs plus approved taxonomy term sets
- Entra group IDs, group owners and membership lifecycle for every reader, author, reviewer, approver, Document Control, Records, support and platform role
- tenant-owned operation endpoint URLs, transport type and Entra application resource URIs
- approved delegated API resource names/scopes, SharePoint Online Client Extensibility principal grants and admin-consent evidence
- Power Platform Dev/Test/Prod environment IDs, managed solution, connection references, environment variables, service identities, DLP policy and flow ownership
- Purview retention/sensitivity label IDs and approved class-to-label mappings
- audit source, licensing, evidence store and correlation conventions
- backup provider, protected sites, recovery roles and monitoring routes
- support/help, notification and service-health routes

## Blocking PRD decisions

- applicable legal, quality, safety, privacy, records and contractual regimes (OQ-01)
- owned and permitted Microsoft 365 licences/add-ons (OQ-02)
- approved retention schedule/file plan (OQ-03)
- pilot process, document types, record class and user population (OQ-04)
- single versioned library versus separate immutable approved revisions (OQ-05)
- RPO, RTO, recovery scope, retention and exercise cadence (OQ-06)
- audit-evidence retention and Audit licensing (OQ-07)
- external sharing, guests, offline access, sync, print and download policy (OQ-08)
- acknowledgement versus training or legal signature requirements (OQ-09)
- migration sources, scale, permissions, duplicates and existing evidence (OQ-10)
- document ID and business revision conventions (OQ-11)
- globally mandatory and conditional metadata (OQ-12)
- approval authority, delegation, quorum, sequence, due dates and escalation (OQ-13)

The PRD's 24-hour RPO and eight-business-hour RTO are planning assumptions, not approved production values. The demo identities, document IDs, metrics, dates, sites, evidence IDs, retention classes and integration states are test fixtures only.
