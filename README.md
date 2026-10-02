# qontract

Flutter client for the qontract contract-management refactor. Production FamilyPlanner is the reference for feature parity and migration; the refactor is not yet a complete replacement.

## Current functionality

- Login/logout, stored JWT, session validation, and password change.
- Multiple tenant memberships and a tenant switcher that resets cached tenant data and navigation.
- Backend-controlled public signup and invitation-code signup/join for new and existing accounts.
- Tenant administrators can create/rename tenants, manage members and roles, and create/revoke invitations.
- Contract creation, editing, deletion, details, dates, and contractor selection.
- IBAN, multiline contract notes, and business types (None, Insurance, Loan,
  Subscription, Other), with an unclassified option for unknown types. Editing
  preserves legacy text and allows clearing it; contract notes are separate from
  price-change notes.
- Dashboard with tenant-wide statistics, status filters, search, paging, and cost summaries.
- Contractor management, contact fields, and addresses.
- Document upload/download, metadata editing, versioning, trash/restore, and PDF preview.
- Invoices from the dashboard menu or contract details: dates, exact signed amounts, optional currency and evidence, editing, archive/restore, and paging.
- Shared document links across contracts in the current tenant. Re-upload retains links; invoices keep the exact evidence version selected. Document actions use a compact menu.
- **Files**: tenant-shared and private account libraries, uploads without a contract, description/category/date metadata, versions, paging, and trash/restore. Personal files follow the account across tenant switches; other members and tenant admins cannot access them.
- Light/dark themes, responsive layouts, and unit/widget regression tests in `test/`.

The usability changes in [#38](https://github.com/harryneufeld/qontract-app/issues/38) are implemented: saved contract details update immediately, contract details and lists support pull-to-refresh (including empty lists), newly created contractors open their details, and inactive contractors can be reactivated from the list or details. The redundant contractor-list reload button is removed.

## Development

Install a current Flutter 3.x SDK compatible with `pubspec.yaml`, then run:

```bash
flutter pub get
flutter run --dart-define=QONTRACT_API_BASE_URL=http://localhost:65533/api
```

Start `qontract-backend` separately. Its development HTTP endpoint is `http://localhost:65533`; use an address reachable from the device, such as `http://10.0.2.2:65533/api` for an Android emulator or the development machine's LAN address for a physical phone.

API configuration is in `lib/config/api_config.dart`. Resolution order is an explicit client URL, the `QONTRACT_API_BASE_URL` build definition, the runtime environment variable where supported, and the configured fallback. Web builds need the build definition because they cannot read runtime environment variables.

```bash
flutter analyze
flutter test
```

## Structure

`lib/models/` contains API models; `lib/services/` contains the HTTP client, local storage, and cost calculations; `lib/providers/` holds state; and `lib/screens/` and `lib/widgets/` contain the interface. Routes are in `lib/app_routes.dart`; the backend documents its actual API routes.

## Product requirements and remaining work

- Memberships, switching, member roles, and code invitations are implemented. Expanded tenant settings and invitation links remain follow-ups in [app #12](https://github.com/harryneufeld/qontract-app/issues/12) and [backend #13](https://github.com/harryneufeld/qontract-backend/issues/13).
- Public signup is shown only when the backend enables `Registration:AllowPublic` (default false). Invitation signup remains available when public signup is disabled. A frontend control for the platform administrator is a proposed follow-up.
- Open **Tenants** from the dashboard or account screen to switch or accept an invitation. Admins can generate a code, optionally bind it to an email, and copy it for sharing. Codes are displayed once, expire after seven days by default, and can be revoked.
- Contract amounts have a selected one-time, daily, weekly, monthly, quarterly, or yearly period. Editing amount/currency/period records dated price history, with an optional effective date and note. Details show prior revisions. The dashboard uses calendar cost estimates, keeps currencies separate, and flags unknown periods instead of guessing. Real billing schedules and historical invoice reconciliation remain migration parity work.
- FamilyPlanner production data and workflows must be preserved. Migration includes memberships, contracts, contractors, addresses, documents, shared-file relationships, invoices, price history, and audit information.
- Legacy family means refactor tenant. Personal/tenant libraries and ownership of new uploads are implemented; historical ownership, mixed-scope legacy associations and staged imports remain pending. Personal files cannot be linked to shared contracts or invoices. See the backend [mapping inventory](https://github.com/harryneufeld/qontract-backend/blob/master/LEGACY-MAPPING.md) for the current boundary.
- OpenStreetMap is optional. Always show the plain-text address and include an external maps action. See [#25](https://github.com/harryneufeld/qontract-app/issues/25).
- Revocable sessions are planned in [backend #44](https://github.com/harryneufeld/qontract-backend/issues/44). Current logout discards the token locally; it does not invalidate copies.

See [PLAN.md](PLAN.md) for the agreed implementation order.

## Deployment

Staging and production target the owner's Linux Docker machine. GitHub Pages will not be used. Container packaging for the web client is tracked in [#34](https://github.com/harryneufeld/qontract-app/issues/34). See [DEPLOY.md](DEPLOY.md) for build and platform release instructions.

## Branding

The display name is lowercase `qontract`. `QontractWordmark` uses bundled RobotoSlab (Apache 2.0), with a purple `q` and black `ontract` on light backgrounds, and a black `q` and white `ontract` on dark backgrounds. The app icon is the purple-circle black `q.` mark in `assets/brand/`.
