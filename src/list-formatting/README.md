# List and view formatting

Supported JSON column and view formatting only. No SPFx (ADR-013).

| File | Applies to | PRD |
|---|---|---|
| `current-documents-view.json` | Controlled Documents, reader views | UX-003, UX-004 |
| `lifecycle-status-column.json` | `DmsLifecycleStatus` column | UX-003 |
| `exception-severity-column.json` | Exception Register `DmsSeverity` | F-022 |

## Accessibility rules applied (NFR-009, WCAG 2.2 AA)

- **Never colour alone.** Every status badge carries text as well as a background colour (1.4.1 Use of Colour).
- **Theme tokens with fallbacks.** `var(--neutralLight, #edebe9)` so contrast holds in both light and dark themes and if the token is absent (1.4.3 Contrast).
- **Obsolete-link warning uses `role="note"`** and text, so a screen reader announces it (UX-004).
- **No content conveyed only on hover**; `title` attributes supplement, never replace, visible text.
- Relative units and wrapping (`flex-wrap`) so the layout survives 200% zoom and reflow (1.4.10).

Formatting must still be verified against a deployed view before acceptance; these rules are applied,
not yet tested (see `tests/accessibility/`).
