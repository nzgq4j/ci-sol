# SOL Document Control UI Prototype

This is a dependency-free, responsive interface prototype for the SharePoint DMS defined in `../SharePoint_DMS_PRD.md`.

## Run locally

From this directory, start any static file server. For example:

```powershell
npx --yes serve .
```

If package downloads are unavailable, open `index.html` directly in a browser. All data is local mock data and no Microsoft 365 changes are made.

## Included role experiences

- **End user:** current-document discovery, library filtering, acknowledgements, favourites, recent history, and document detail.
- **Team administrator:** lifecycle control desk, documents, change requests, approvals, review calendar, exceptions, and reports.
- **Platform administration:** platform health, sites and access, automations, records and retention, integrations, deployments, recovery, and audit.

## Interaction notes

- Switch roles from the left rail.
- Press `/` to focus global document search.
- Open any document row for lifecycle and control details.
- Complete an acknowledgement, approve an item, or resolve an exception to see stateful prototype behaviour.
- Use Escape to close menus and drawers.

## Design direction

The interface uses a “controlled knowledge desk” aesthetic. Its signature element is the lifecycle spine: document state is treated as the primary visual grammar rather than decoration. Typography uses Microsoft-native Aptos/Segoe UI and Cascadia Mono fallbacks to keep the prototype deployable without external font services.

