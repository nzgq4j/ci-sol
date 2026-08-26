# Template mapping

| Content type | Template | Status | PRD |
|---|---|---|---|
| SOP | `SOP/SOP-Template.md` | Structure defined; Word `.dotx` to be produced from it | F-003 |
| Policy | `Policy/Policy-Template.md` | Structure defined | F-003 |
| Work Instruction | `Work-Instruction/Work-Instruction-Template.md` | Structure defined | F-003 |
| Controlled Form / Template | `Controlled-Form/Controlled-Form-Template.md` | Structure defined | F-003, DATA-006 |
| Standard | — | Not required for MVP pilot | F-003 |
| Business Operations Document | — | Not required for MVP pilot | F-003 |

## Why these are Markdown, not `.dotx`

A Word template is a binary artefact whose control header must be bound to SharePoint document
properties (quick parts) in the tenant. Committing a hand-built binary would produce a file whose
property bindings do not resolve, which fails at first use.

These files define the **required structure and control header** so the `.dotx` can be produced
correctly once the tenant exists and OQ-11 fixes the Document ID convention. Deploy them with
`Set-PnPList -Path` or by uploading to the Templates library and setting the content type's document
template.

## Control header — required on every controlled document

Every template carries a header bound to document properties, so the rendered document always shows
its own control metadata rather than a typed copy that can drift:

| Field shown | Bound property |
|---|---|
| Document ID | `DmsDocumentId` |
| Title | `Title` |
| Revision | `DmsBusinessRevision` |
| Effective date | `DmsEffectiveDate` |
| Owner | `DmsDocumentOwner` |
| Next review | `DmsNextReviewDate` |
| Classification | `DmsSensitivityClassification` |

## Uncontrolled-copy statement

Every template footer carries:

> *Printed or downloaded copies are uncontrolled. Verify the current revision in the DMS before use.*

PRD C-008 states plainly that the system cannot prevent an authorised reader taking a screenshot,
printout or offline copy. Labelling every rendition is the layered mitigation, alongside link-only
distribution (F-017) and obsolete-link warnings (UX-004).

## The blank form versus completed record distinction

A blank form in `Controlled-Form/` is a **controlled document** — it has a lifecycle, an owner, an
approval history and a review date.

A **completed** form is an **Operational Record** — a different content type, in a different library,
with no `DmsLifecycleStatus`, governed by retention from the moment of capture.

Completing a form must never overwrite the blank template (PRD F-003). This is the single most
commonly confused distinction in document management, and it is why the two are modelled as separate
entities (DATA-001 versus DATA-006).
