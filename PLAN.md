# Refactor implementation order

Agreed with Harry on 2026-10-01. The legacy system is the production system and must remain supported until the refactor provides complete feature/data parity and a verified migration. Existing code and tests take precedence over old setup notes.

1. Correct READMEs and issue descriptions to reflect implemented features and approval comments, including Linux Docker deployment.
2. Tenant access and membership: close cross-tenant administration gaps first; introduce multiple memberships, membership-specific roles, tenant switching, configurable public registration, and code/link invitations. Track in [backend #13](https://github.com/harryneufeld/qontract-backend/issues/13) and [app #12](https://github.com/harryneufeld/qontract-app/issues/12).
3. Finish focused usability changes in [app #38](https://github.com/harryneufeld/qontract-app/issues/38).
4. Plan authenticated legacy export and backend import. Inventory all production features and data, implement missing parity (especially billing periods and price history), then prove completeness with dry runs and reconciliation.
5. Add revocable sessions and rotating refresh tokens in [backend #44](https://github.com/harryneufeld/qontract-backend/issues/44), followed by the existing 2FA and login-anomaly issues.

The approved audit cleanup in [backend #38](https://github.com/harryneufeld/qontract-backend/issues/38) remains separate schema work: preserve `Documents.UserId`, retain only base audit fields, and remove unused relationships after checking actual data. Migration must preserve legitimate shared-file relationships from the legacy system even though its schema differs from the new backend's unused join.

Contract amounts are billed per selected period. Calendar cost estimates now use the selected period and dated price history. Use the legacy system as the reference and record proposed improvements explicitly.

## Progress on 2026-10-01

Documentation and approved issue descriptions are corrected. Core tenant membership, registration, invitation-code flows, and administration are implemented across the app and backend, with regression coverage for switching, permissions, signup, and stale responses. Expanded validated tenant settings, invitation links, and a distinct platform-admin registration control remain tracked follow-ups. App #38 usability is implemented and covered by widget regressions. Billing periods, dated price revisions, history display, and calendar cost estimates are implemented. The backend's LEGACY-MAPPING.md inventories source models and remaining parity gaps. Authenticated export/import and production reconciliation remain pending.

Invoice records, exact signed amounts, unknown currency, optional evidence, archive/restore and contract file sharing are implemented. Re-upload preserves shared links and invoices retain exact evidence versions. New storage keys prevent same-name file overwrites. Personal/family file scope, complete ownership, original-anchor removal and import provenance remain gaps; production the legacy system is unchanged.

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

## Migration staging preparation (2026-10-04)

Account and tenant address parity is implemented: private **My addresses** under
Account and shared **Tenant addresses** under Workspaces. Tenant members read;
administrators write. The editor separates house numbers, supports partial fields
and explicit clearing, and keeps unchanged historical text. Target storage accepts
nullable/unbounded source fields, adds account ownership without guessing owners,
and preserves existing associations and audit history. Deploy the matching API
first; rollback requires a matched pre-upgrade database backup. Source GUID address
relationships, reused source rows and visibility conflicts still require mapping
and reconciliation before export/import. Production data is untouched.

Personal contract and contractor workspaces are implemented alongside tenant
workspaces. Account → Workspaces always offers Personal; forms state visibility
before saving. Switching resets scoped caches/navigation. Personal contract
documents remain private and personal details hide the tenant-only invoice action.
The matching backend adds explicit owner FKs, allows accounts without a primary
tenant, and enforces ownership throughout CRUD, counts, stats, documents and
contract/contractor addresses. Existing target tenant data is not reclassified;
audit identity and legacy UserId associations are not ownership evidence.
Deploy that backend first. Migration downgrade requires restoring a matched backup.
Legacy relationship and address reconciliation and export/import remain
pending; no production data has been imported. Backend #53 remains deferred.

Harry excluded unused production invoice and historical-price tables/their join.
Current prices/periods and all documents remain in scope. A backed-up local legacy
fixture now supports migration rehearsals. Docker web/API packaging, separate
environment templates, persistent storage, trusted proxy forwarding, readiness and
backup/restore instructions are prepared under #34. Actual Linux host startup,
chosen-provider verification, HTTPS/SMTP and restore rehearsal remain pending.
Personal contract/contractor scope, user/tenant addresses and historical import
are still migration gaps; preparing deployment does not authorize cutover.
