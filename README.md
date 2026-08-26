# SOL Document Control

Production-oriented role experiences for the SOL SharePoint Online document management system. The application implements the controlled knowledge desk interface for end users, team administrators, and platform administrators while keeping Microsoft 365 integrations behind typed service boundaries.

## Local verification

Use Node.js 22.

```powershell
npm install
npm run verify
```

The local development server uses the isolated demo adapter from `.env.development`. Production builds never fall back to demo data: an absent runtime manifest produces an explicit unconfigured state.

## SharePoint package

The installable SharePoint Framework project is in `sharepoint/sol-dms`. It is deliberately tenant-neutral. Build it with Node.js 22.14 or later in the Node 22 line:

```powershell
npm run sync:sharepoint
npm --prefix sharepoint/sol-dms install
npm --prefix sharepoint/sol-dms run build
```

The resulting package is `sharepoint/sol-dms/sharepoint/solution/sol-dms.sppkg`. Follow [deployment/README.md](deployment/README.md) to configure and install it in another SharePoint Online tenant or site collection.

For an automated installation preview and deployment, use `deployment/Install-SolDms.ps1`. It uploads the package and runtime manifest, creates the full-page SharePoint experience, configures the web part, publishes the page and can write a deployment receipt.

This build does **not** target on-premises SharePoint Server 2016, 2019, or Subscription Edition. The authoritative PRD explicitly assumes SharePoint Online (A-001).

## Architecture

- `src/domain`: document lifecycle, evidence, role, and control types
- `src/services/contracts.ts`: typed production boundaries
- `src/services/application.ts`: permission-aware application orchestration
- `src/services/http.ts`: configurable production adapter and injectable authenticated transport
- `src/services/demo.ts`: local/test-only data adapter
- `src/app` and `src/components`: role experiences and reusable presentation
- `sharepoint/sol-dms`: SPFx deployment host using `SPHttpClient` and `AadHttpClient`

See [docs/implementation-map.md](docs/implementation-map.md) and [docs/tenant-configuration.md](docs/tenant-configuration.md).
