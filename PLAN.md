# Refactor implementation order

Agreed with Harry on 2026-10-01. FamilyPlanner is the production system and must remain supported until the refactor provides complete feature/data parity and a verified migration. Existing code and tests take precedence over old setup notes.

1. Correct READMEs and issue descriptions to reflect implemented features and approval comments, including Linux Docker deployment.
2. Tenant access and membership: close cross-tenant administration gaps first; introduce multiple memberships, membership-specific roles, tenant switching, configurable public registration, and code/link invitations. Track in [backend #13](https://github.com/harryneufeld/qontract-backend/issues/13) and [app #12](https://github.com/harryneufeld/qontract-app/issues/12).
3. Finish focused usability changes in [app #38](https://github.com/harryneufeld/qontract-app/issues/38).
4. Plan authenticated legacy export and backend import. Inventory all production features and data, implement missing parity (especially billing periods and price history), then prove completeness with dry runs and reconciliation. Track export planning in [FamilyPlanner #1](https://github.com/harryneufeld/FamilyPlanner/issues/1).
5. Add revocable sessions and rotating refresh tokens in [backend #44](https://github.com/harryneufeld/qontract-backend/issues/44), followed by the existing 2FA and login-anomaly issues.

The approved audit cleanup in [backend #38](https://github.com/harryneufeld/qontract-backend/issues/38) remains separate schema work: preserve `Documents.UserId`, retain only base audit fields, and remove unused relationships after checking actual data. Migration must preserve legitimate shared-file relationships from legacy FamilyPlanner even though its schema differs from the new backend's unused join.

Contract amounts are billed per selected period. Calendar cost estimates now use the selected period and dated price history. Use FamilyPlanner as the reference and record proposed improvements explicitly.

## Progress on 2026-10-01

Documentation and approved issue descriptions are corrected. Core tenant membership, registration, invitation-code flows, and administration are implemented across the app and backend, with regression coverage for switching, permissions, signup, and stale responses. Expanded validated tenant settings, invitation links, and a distinct platform-admin registration control remain tracked follow-ups. App #38 usability is implemented and covered by widget regressions. Billing periods, dated price revisions, history display, and calendar cost estimates are implemented. The backend's LEGACY-MAPPING.md inventories source models and remaining parity gaps. Authenticated export/import and production reconciliation remain pending.

Invoice records, exact signed amounts, unknown currency, optional evidence, archive/restore and contract file sharing are implemented. Re-upload preserves shared links and invoices retain exact evidence versions. New storage keys prevent same-name file overwrites. Personal/family file scope, complete ownership, original-anchor removal and import provenance remain gaps; production FamilyPlanner is unchanged.

## Progress on 2026-10-02

Harry clarified that a legacy family is a refactor tenant. Tenant-shared and private
account file libraries now support contract-free uploads, metadata/categories,
versions, paging and trash/restore. New ownership comes from authenticated identity;
re-upload retains the original owner. Personal files remain private across tenant
switches and cannot become shared through contract or invoice links. Historical
ownership, mixed legacy associations and staged import remain pending.

The dashboard now contains only complete tenant-wide overview information.
Search, contract rows, filters and paging live on the dedicated Contracts page.
Shared themes, spacing, constrained forms and responsive overview panels begin
the design-language rollout; DESIGN.md contains rendered sample-data previews.
App #39 covers the delivered overview flow; #40 remains the visual review and
further polish tracker. The Invoices drawer entry is hidden. Backend #53 awaits
review; OCR/AI-assisted extraction is a potential future direction, and no
document type, invoice schema or production data change is included.
