# SOL Document Management System

## Authoritative references

Before implementing or changing user-facing functionality, read:

- `docs/SharePoint_DMS_PRD.md`
- `docs/design-reference/dms-ui-prototype/README.md`
- `docs/design-reference/dms-ui-prototype/index.html`
- `docs/design-reference/dms-ui-prototype/styles.css`
- `docs/design-reference/dms-ui-prototype/app.js`
- All `docs/design-reference/dms-ui-prototype/preview-*.png` images
- `docs/design-reference/dms-ui-prototype/verify-ui.cjs`

Authority order:

1. The PRD controls business requirements, permissions and lifecycle behaviour.
2. The prototype controls visual design, navigation, responsive behaviour and interaction patterns.
3. Existing production code controls engineering conventions and deployment architecture.
4. Report material conflicts instead of silently choosing one interpretation.

## Design intent

The product uses a “controlled knowledge desk” visual language.

Non-negotiable design characteristics:

- Lifecycle state is the primary visual grammar.
- Navigation uses deep navy surfaces.
- Controlled and effective states use teal.
- Primary actions use cobalt.
- Warnings use amber.
- Exceptions and failures use red.
- Content uses quiet document-paper surfaces.
- Typography uses Aptos, Segoe UI and Cascadia Mono system fallbacks.
- The document lifecycle spine must remain part of document details.
- Do not replace the interface with a generic Fluent UI dashboard.
- Do not reduce the interface to interchangeable cards.

## Required role experiences

### End user

- Authoritative-document search
- Controlled library
- Document filtering
- Favourites
- Recently viewed documents
- Assigned acknowledgements
- Document details
- Lifecycle and version evidence

### Team administrator

- Lifecycle control desk
- Document register
- Change requests
- Approval queue
- Review calendar
- Exceptions
- Governance reporting

### Platform administrator

- Platform assurance overview
- Sites and access
- Power Automate monitoring
- Records and retention
- Integrations
- Deployments
- Recovery
- Unified audit

## Production boundaries

The prototype contains mock data. Do not treat its static JavaScript state as production architecture.

Create separate typed adapters for:

- SharePoint sites and document libraries
- SharePoint content types and metadata
- Microsoft Graph
- Microsoft Entra ID
- SharePoint permissions
- Power Automate workflows
- Microsoft Purview retention
- Change requests
- Approval evidence
- Acknowledgement evidence
- Audit records
- Platform-health information

Do not invent tenant identifiers, credentials, list GUIDs, API endpoints or security behaviour.

Access must be enforced by production services and permissions, not only by hiding interface elements.

## Accessibility and responsive requirements

- Meet WCAG 2.2 AA interaction expectations.
- Support keyboard-only operation.
- Provide visible focus.
- Use semantic landmarks, labels and headings.
- Trap focus in modal dialogs and drawers.
- Make closed off-canvas navigation inert.
- Honour `prefers-reduced-motion`.
- Do not communicate status through colour alone.
- Prevent page-level horizontal overflow at 390px.
- Tables may scroll within bounded containers.

## Engineering expectations

- Preserve existing repository architecture unless a change is justified.
- Use TypeScript where supported.
- Centralise design tokens.
- Build reusable components for status, document rows, lifecycle spine, evidence history, metrics, tables, drawers and confirmation dialogs.
- Separate presentation, domain logic and Microsoft 365 integrations.
- Include loading, empty, error, stale-data and permission-denied states.
- Governed actions must require confirmation and produce evidence-friendly results.
- Do not modify the reference prototype while implementing the production application.

## Completion criteria

Before declaring work complete:

1. Build and type-check the application.
2. Run unit and integration tests.
3. Exercise every navigation view for all three roles.
4. Test search, document opening, acknowledgement, approval and exception resolution.
5. Inspect desktop and 390px mobile layouts.
6. Test keyboard and modal focus behaviour.
7. Compare production screens with the reference screenshots.
8. Report intentional differences and remaining tenant configuration.