# qontract

Flutter client for the qontract contract-management refactor. The production legacy system is the reference for feature parity and migration; the refactor is not yet a complete replacement.

## Current functionality

- English/German UI with persistent device-language selection, localized dates,
  numbers, validation and password reset emails; see [LOCALIZATION.md](LOCALIZATION.md).
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
- Compact contract rows with current document counts, a single scrollable filter
  row, and labeled deletion queue access. New contractors default to Company;
  their cards always show a contract count, including zero. Contractor email and
  phone open the device's handlers, with the contract number in email subjects
  when contacting a contractor from contract details.
- Tenant admins can set a default currency under Workspaces and apply it to
  existing contracts and price history. The action fills missing currencies by
  default; replacing existing currencies is an explicit choice and never converts
  amounts. New contracts use the tenant default (EUR until configured). Deploy
  the matching default-currency and document-count backend first. Legacy billed
  amounts without currency remain visible in a separate dashboard group.
- **My addresses** under Account and **Tenant addresses** under Workspaces.
  Account addresses are private; tenant members can read shared addresses and
  tenant admins can add/edit/remove them. The editor keeps house numbers separate,
  supports partial addresses and clearing fields, and preserves source text.
  Deploy the matching address-aware backend first.
- Contractor website, description and multiline notes, with editing/clearing that
  preserves legacy text. Details provide an external open action for valid
  HTTP/HTTPS websites and keep other stored references readable.
- Document upload/download, metadata editing, versioning, trash/restore, and PDF preview.
- **Import document**: share PDFs/images from another phone app or choose a file
  from **Dashboard → + → Import document**. The same popup offers **Contract**;
  import is not a flyout-menu action. Both platforms use existing PDF text where available;
  otherwise Android uses bundled, offline Tesseract OCR and iPhone uses Apple Vision. The app suggests contracts in the current
  workspace using contract numbers, titles, contractor names and IBANs, with the
  matching reasons, original matching passages, contract number and contractor
  shown. OCR suggests an editable document date and subject/title, prioritizing
  labelled document/invoice dates and excluding labelled deadlines or coverage
  periods. Equally likely dates remain unselected and can be chosen from the
  detected passages. Review the suggested destination before saving; nothing is attached
  automatically. Unmatched files can be saved to a library (private by default).
  The original file is uploaded through the existing document API only on Save;
  recognized text stays local and is not stored on the server.
  Shared files wait in a persistent local inbox through login, cancellation or
  failed uploads; reopen **Dashboard → + → Import document** to review or discard them. Limits:
  20 MB per file, 10 pending files, recognition of only the first PDF page, with the
  complete original retained for upload. Android opens review when sharing;
  iOS sharing queues documents for review when qontract is opened. Desktop/web
  support choosing a destination and saving, with an explanation that OCR requires
  a phone. iOS App Group/signing setup and device verification are in [DEPLOY.md](DEPLOY.md).
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

API configuration is in `lib/config/api_config.dart`. Resolution order is an explicit client URL, the server picked in the app (login screen or Settings → Server, saved on the device), the `QONTRACT_API_BASE_URL` build definition, the runtime value (process environment on mobile/desktop, `config.js` written by the web container on web), and the fallback `https://api.qontract.app/api`.

### Android LAN staging

For a physical Android device, use the reachable HTTPS staging API URL. If its
certificate is self-signed, a **debug build only** can explicitly pin the exact
DER certificate with `QONTRACT_STAGING_CERT_DER_BASE64`. Obtain the certificate
through a trusted operator connection to the host, not an unauthenticated LAN
download. Keep host-specific build settings outside Git, for example:

```json
{
  "QONTRACT_API_BASE_URL": "https://api.example.com:8443/api",
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
- Legacy production migration includes memberships, contracts, contractors,
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

The display name is lowercase `qontract`. The brand color is `#0369A1`, matching the q in the light login wordmark, with `#7DD3FC` for readable text/actions on dark surfaces and `#082F49` as ink. `QontractWordmark` uses bundled RobotoSlab (Apache 2.0). The lowercase serif q-dot icon uses the same bundled RobotoSlab Bold as the wordmark, with white lettering on brand blue. Run `python tool/generate_brand_icons.py` (Pillow and fontTools required) to regenerate the SVG, Android vector and PNG icons for the app, web, Android and iOS. Android also has an adaptive vector icon with a monochrome layer.

Login and signup fields share an `AutofillGroup`, identify the email as the account username and distinguish existing from new passwords. Credentials are committed to the platform autofill service only after successful authentication; leaving or cancelling a form does not request saving. Availability of suggestions and save prompts depends on the browser/OS and enabled password manager. Verify on a real device/browser with saved credentials, generated passwords, failed submissions and successful submissions.

### Contract review behavior

Contract lists default to alphabetical order and search includes contract numbers. Details highlight the number, billed amount, dates, and responsible member. Amount formatting is display-only; migrated decimal strings are preserved. Inactive contracts stay accessible and can be reactivated from the edit screen.

The dashboard starts with contracts assigned to the current user. Whole-tenant scope includes other members and unassigned contracts; cost estimates exclude inactive and trashed contracts. Browsing from the dashboard preserves that scope. Contract trash supports restoration before its deadline (90 days by default). Tenant admins can adjust future retention in workspace settings. These features require the backend's `ContractResponsibilityAndTrash` migration. Document menus start with Download; PDF preview behavior is unchanged.

## License

Copyright © 2026 Harry Neufeld.

qontract is free software: you can redistribute it and/or modify it under the
terms of the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0). If you
run a modified version as a network service, the AGPL requires you to offer its
users the corresponding source code.

Bundled third-party components keep their own licenses: Roboto and Roboto Slab
(`assets/fonts/`, Apache 2.0) and PDF.js (`web/pdfjs/`, Apache 2.0). The app's
license page (footer → AGPL-3.0) lists these together with all Dart and Flutter
package licenses.


## Build metadata

`pubspec.yaml` is the default source for the app version/build number. The footer and license page read one central `kAppVersion` from the actual installed package (or Flutter's generated `version.json` on web) via `package_info_plus`, including build-time overrides. No separate version string is maintained. Android application ID and iOS bundle ID are `app.qontract`.

The icon generator also versions the favicon URL with a content hash so browsers request the new icon after deployment.

The import review keeps title/date and destination in one form. OCR sources and
matching passages expand on demand; the save action and visibility notice remain
available at the bottom. Compact rows reuse the shared AppCollection component.
Import layout previews (phone/desktop, both themes, enlarged text and loading/error
states) can be exported by setting QONTRACT_PREVIEW_DIR and running
`test/document_import_test.dart`.

OCR review has separate date and contract-number sections. German and English
contract, insurance and policy labels supply number candidates; customer/invoice
numbers do not identify contracts. Dates in the upper half of page 1 are preferred, with the upper-right
region ranked first when coordinates are available. Labels and city/date lines
rank candidates within each region; text-only input falls back to label priority. Due dates, coverage dates and birth dates are excluded. Ambiguous values
remain reviewable; a number correction reranks matches and selects a unique strongest destination.
Both native PDF readers inspect page 1 only, retaining the complete original.
iOS embedded PDF text remains preferred; position hints are available for rendered
OCR pages and images. The iOS changes require build/device validation on a Mac.

Import suggests a short document subject from labelled subjects or common
German/English headings (including wrapped headings). Suggestions remain editable;
if no reliable subject is found, the filename remains the fallback. A successful
contract attachment refreshes document data and opens that contract. Dashboard
shows up to three recent contracts ordered by the server's saved modification time,
within the selected responsibility scope.

Import includes an in-app preview from the original memory bytes before Save;
no upload, download, or external viewer is used. PDFs can be paged/zoomed, and
images zoomed. Preview errors return to review without losing edits. Subject
extraction uses text, relative line height/position and embedded-PDF bold metadata
where available; scan OCR does not reliably identify bold fonts. Unlabelled
subject-line numbers and exact known contract numbers become review candidates.
No generative summarization model is included: suggested titles are short local
extractions, with an explicit filename fallback when no reliable subject is found.

OCR processes document contents on-device. PDFs with a text layer are read
directly (PdfBox-Android on Android, PDFKit on iPhone), which is exact and needs
no OCR. For images and scanned PDFs, Android runs Tesseract (Tesseract4Android,
Apache 2.0) with the bundled German and English `tessdata_fast` models in
`android/app/src/main/assets/tessdata`; it has no telemetry and makes no network
requests. Apple Vision runs locally. Matching still retrieves contracts from qontract; pressing Save uploads
the complete original to the selected qontract API. OCR itself can run offline;
this is not a claim that the entire import workflow or SDK produces zero traffic.

Date review prioritizes upper-right, then remaining upper-half candidates, then
other dates. Labelled deadlines and coverage periods stay excluded everywhere.
Labels on preceding lines are inherited only within an aligned nearby column
when coordinates are available; dates with equal priority remain unselected.

Import shows relative evidence points for date candidates and contract matches,
not OCR confidence percentages. The unique strongest contract is preselected;
ties remain unselected and Save is always required. Manual destinations survive
contract refreshes. Contract audit dates for document uploads/links/replacements
require the backend document-activity fix to be deployed.
