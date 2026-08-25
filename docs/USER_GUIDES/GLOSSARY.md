# Glossary

From PRD section 2.8. These meanings are controlled: using them loosely is how document control
becomes ambiguous.

| Term | Controlled meaning |
|---|---|
| **Controlled document** | Information whose creation, review, approval, publication, revision and withdrawal are governed. |
| **Operational record** | Evidence that a business activity happened. Captured, not authored. Different lifecycle, different retention. |
| **Effective revision** | The one approved revision authorised for current use. |
| **Major version** | A SharePoint published milestone version (1.0, 2.0). |
| **Minor version** | A SharePoint draft version (1.1, 1.2). Not visible to ordinary readers. |
| **Approval Status** | *Platform* state: Draft, Pending, Approved, Rejected. Set by SharePoint. |
| **Lifecycle Status** | *Business* state: Authoring, In Review, Effective, Superseded… Set by the DMS. |
| **Record label** | A Purview retention label imposing records-management restrictions. |
| **Regulatory record** | A Purview record type with **irreversible** restrictions. Not the same as an ordinary business record. Excluded from MVP. |
| **Controlled copy** | A rendition whose status and revision can be verified against the DMS. |

## Two distinctions that matter most

**Approval Status is not Lifecycle Status.** A document can be "Approved" in SharePoint and not yet
effective — because its effective date has not arrived. Only Lifecycle Status tells you whether you
may act on it.

**A blank form is not a completed record.** The blank form is a controlled document with an owner and
a review date. The completed form is an operational record governed by retention. They live in
different libraries and must never overwrite each other.
