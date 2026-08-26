# SOL DMS implementation map

This map was produced after repository and reference-package inspection and before application code was changed. Authority is applied in this order: PRD business behaviour, reference prototype experience, repository engineering conventions.

## Repository finding

The repository contained the PRD and the complete static reference package but no production application or deployment architecture. The implementation therefore establishes a TypeScript/React application and a SharePoint Framework host without changing the reference package.

## Requirement-to-implementation map

| Product surface | Production implementation | Microsoft 365 boundary |
|---|---|---|
| End-user search, controlled library, filters, favourites, recently viewed | `src/app/views.tsx`, reusable document rows and detail drawer | `SharePointDocumentService`, Microsoft Graph |
| Assigned acknowledgements | exact version and ETag confirmation, evidence receipt, reassigned workspace state | `AcknowledgementEvidenceService`, permissions, audit |
| Document details, lifecycle and version evidence | `DetailDrawer`, `LifecycleSpine`, evidence and version models | SharePoint versions/metadata, approval evidence, audit |
| Team control desk, register, changes, approvals, calendar, exceptions, reporting | team-admin routes in `src/app/views.tsx` | change requests, approvals, Power Automate, exceptions, audit |
| Governed approval | role authorisation, exact revision/ETag confirmation, durable receipt | permissions and `ApprovalEvidenceService`; production service revalidates concurrency |
| Platform overview, sites/access, automation, retention, integrations, deployments, recovery, audit | platform-admin routes in `src/app/views.tsx` | sites, Entra, permissions, Power Automate, Purview, platform health, audit |
| Loading, empty, error, stale, denied and unconfigured states | `StatePanel`, workspace freshness metadata | all service results carry source, freshness and correlation metadata |
| Responsive and accessible shell | semantic landmarks, focus traps, inert off-canvas UI, visible focus, reduced motion, bounded tables | presentation-only; authorisation remains server-side |

## Architecture boundaries

`src/services/contracts.ts` defines separate typed interfaces for:

- SharePoint sites and document libraries
- SharePoint content types and metadata
- Microsoft Graph
- Microsoft Entra ID
- SharePoint permissions
- Power Automate workflows
- Microsoft Purview retention
- change requests
- approval evidence
- acknowledgement evidence
- audit records
- platform health and exceptions

`DmsApplication` coordinates these interfaces. It never grants access by role-switch visibility alone: every governed action calls the permission boundary before the production evidence operation. The backend remains responsible for identity, permission trimming, concurrency, lifecycle invariants, and immutable evidence.

The static demo adapter is only selected by the local development environment. The production SPFx host always constructs the configured HTTP adapter.

## Portable deployment map

The same `sol-dms.sppkg` can be uploaded to another SharePoint Online App Catalog. A site-owned JSON manifest maps logical operations to environment endpoints and selects one of three credential-free transports:

- `sharePoint`: `SPHttpClient`, using the signed-in SharePoint context
- `entra`: `AadHttpClient`, using an approved Entra resource URI and tenant admin-approved API permission
- `browser`: same-origin browser request, intended for tenant-owned same-origin endpoints only

The package has no tenant ID, site URL, list GUID, group ID, flow URL, retention label, API key, client secret, or credential compiled into it.

## Material boundary decisions

- The PRD says SharePoint Online is the target and that native capabilities may be sufficient; the user explicitly requested these role experiences and a portable SharePoint installation, so the interface is supplied as an SPFx package.
- The PRD leaves the one-library versus immutable-revision topology unresolved. The client models an authoritative document plus exact business revision, SharePoint version and ETag, but does not choose or provision either topology.
- Acknowledgement is presented as evidence of reading/understanding, not competence certification or legal signature.
- Platform integration toggles create a proposed, evidence-friendly governed change; they do not silently mutate tenant controls from the browser.
