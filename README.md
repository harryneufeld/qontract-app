# qontract

Flutter client for the qontract contract-management refactor. Production FamilyPlanner is the reference for feature parity and migration; the refactor is not yet a complete replacement.

## Current functionality

- Login/logout, stored JWT, session validation, and password change.
- Forgot-password and email password-setup/reset screens, with one-use links and
  a fresh login after completion. Backend SMTP reset must be explicitly configured.
- Personal and tenant workspaces, with a switcher under Account → Workspaces that
  clears cached workspace data and navigation. Personal contracts, contractors,
  their documents and addresses are owner-only, including accounts without tenant
  memberships. Forms explain visibility before saving; tenant admins cannot read
  another user's personal records. Deploy the matching ownership-aware backend first.
- Backend-controlled public signup and invitation-code signup/join for new and existing accounts.
- Tenant administrators can create/rename tenants, manage members and roles, and create/revoke invitations.
- Contract creation, editing, deletion, details, dates, and contractor selection.
- IBAN, multiline contract notes, and business types (None, Insurance, Loan,
  Subscription, Other), with an unclassified option for unknown types. Editing
  preserves legacy text and allows clearing it; contract notes are separate from
  price-change notes.
- Overview-only dashboard with complete selected-workspace statistics, calendar costs and
  actionable end-date, minimum-term, billing-review and upcoming-price insights.
- Dedicated **Contracts** page for search (including contractor names), status,
  contractor, end-date, type and billing-period filters, sorting, paging and creation. Insight cards open this
  page with the relevant filter; search composes with filters across the complete tenant set.
- Adaptive contract details with a billing summary, grouped facts, dated price history,
  documents, contractor links and activity. New and Edit actions stay at the bottom.
- Costs show this month, quarter and year together for the complete selected workspace's
  active contracts, independently of contract-list filters and search. Partial
  pages never substitute for totals; failed complete loads show a retry state.
- Contractor management, contact fields, and addresses.
- **My addresses** under Account and **Tenant addresses** under Workspaces.
  Account addresses are private; tenant members can read shared addresses and
  tenant admins can add/edit/remove them. The editor keeps house numbers separate,
  supports partial addresses and clearing fields, and preserves source text.
  Deploy the matching address-aware backend first.
- Contractor website, description and multiline notes, with editing/clearing that
  preserves legacy text. Details provide an external open action for valid
  HTTP/HTTPS websites and keep other stored references readable.
- Document upload/download, metadata editing, versioning, trash/restore, and PDF preview.
- Invoice records remain available from contract details, with dates, exact signed
  amounts, optional currency/evidence and archive/restore. The menu entry is hidden
  pending review of the document/invoice direction in [backend #53](https://github.com/harryneufeld/qontract-backend/issues/53).
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

### Android LAN staging

For a physical Android device, use the reachable HTTPS staging API URL. If its
certificate is self-signed, a **debug build only** can explicitly pin the exact
DER certificate with `QONTRACT_STAGING_CERT_DER_BASE64`. Obtain the certificate
through a trusted operator connection to the host, not an unauthenticated LAN
download. Keep host-specific build settings outside Git, for example:

```json
{
  "QONTRACT_API_BASE_URL": "https://staging.example:8443/api",
  "QONTRACT_STAGING_CERT_DER_BASE64": "BASE64_OF_THE_EXACT_DER_CERTIFICATE"
}
```

```bash
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=PRIVATE_STAGING_DEFINES.json
adb connect DEVICE_IP:WIRELESS_DEBUG_PORT
adb -s DEVICE_IP:WIRELESS_DEBUG_PORT install -r build/app/outputs/flutter-apk/app-debug.apk
```

The native API client accepts only that certificate at the configured HTTPS host
and port, within its validity dates. Redirects are disabled when the pin is in
use. A changed certificate needs a new build; other certificates/hosts/ports are
rejected. The setting is ignored in profile/release builds; those builds require
normally trusted HTTPS. Browser trust is managed separately by the browser.
Android's main manifest includes Internet permission for all build variants.
Installing with `-r` preserves app data when the package and signing key match;
do not uninstall an existing app to bypass a signing mismatch without deciding
how to preserve its data first. This is local device installation, not Play Store
publication.

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
- Contract amounts have a selected one-time, daily, weekly, monthly, quarterly, or yearly period. Editing amount/currency/period records dated price history, with an optional effective date and note. Details show prior revisions. The dashboard shows monthly, quarterly and yearly calendar estimates together, keeps currencies separate, and flags unknown periods instead of guessing. Real billing schedules and historical invoice reconciliation remain migration parity work.
- Dashboard/Contracts separation is implemented for [#39](https://github.com/harryneufeld/qontract-app/issues/39).
  The shared violet, paper and ink design foundation is documented with screen
  previews in [DESIGN.md](DESIGN.md). Further visual review and refinement stay
  in [#40](https://github.com/harryneufeld/qontract-app/issues/40).
  Tenant creation and signup controls use tenant terminology; the API's historical
  `Family` type value remains unchanged for compatibility and displays as Standard.
- FamilyPlanner production migration includes memberships, contracts, contractors,
  addresses, current prices/periods, documents, shared-file relationships and audit
  information. Harry excluded unused production invoices and historical-price
  records/their join on 2026-10-04; all documents remain in scope.
- Legacy family means refactor tenant. Personal/tenant libraries and ownership of new uploads are implemented; historical ownership, mixed-scope legacy associations and staged imports remain pending. Personal files cannot be linked to shared contracts or invoices. See the backend [mapping inventory](https://github.com/harryneufeld/qontract-backend/blob/master/LEGACY-MAPPING.md) for the current boundary.
- OpenStreetMap is optional. Always show the plain-text address and include an external maps action. See [#25](https://github.com/harryneufeld/qontract-app/issues/25).
- Backend sessions are revocable: a successful logout invalidates retained copies
  for that session, and password changes invalidate all of the account's sessions.
  After changing a password the app clears its session and returns to login.
  Logout always clears local credentials; an offline/failed request cannot confirm
  server revocation. Existing tokens need a fresh login after the backend session
  migration. Refresh tokens and session management remain in
  [backend #44](https://github.com/harryneufeld/qontract-backend/issues/44).

See [PLAN.md](PLAN.md) for the agreed implementation order.

## Deployment

The Dockerfile and Compose setup package Flutter web for Linux Docker staging and
production, with generic configuration, root/subpath
hosting, route fallback and separate staging/production configuration. Actual Linux
host deployment and smoke verification remain tracked in [#34](https://github.com/harryneufeld/qontract-app/issues/34).
See [DEPLOY.md](DEPLOY.md) for build and platform release instructions.
Optional Compose overrides integrate with a separately managed Traefik network,
with generic router/TLS settings and no published host ports.

## Branding

The display name is lowercase `qontract`. `QontractWordmark` uses bundled RobotoSlab (Apache 2.0), with a purple `q` and black `ontract` on light backgrounds, and a black `q` and white `ontract` on dark backgrounds. The app icon is the purple-circle black `q.` mark in `assets/brand/`.
