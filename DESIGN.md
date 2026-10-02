# qontract design direction

qontract should feel like a calm workspace for decisions about commitments.
Keep the existing lowercase name, q mark and RobotoSlab wordmark. Violet marks
actions and navigation; white panels sit on a faint violet paper background.
The dark alternative uses ink backgrounds, softly outlined surfaces and a
lighter violet accent. Colour never carries a status without a written label.

## Shared rules

Implementation: lib/app_theme.dart and lib/widgets/app_design.dart.

| Role | Rule |
| --- | --- |
| Neighbouring actions | 8 logical pixels minimum |
| Form fields and groups | 16 logical pixels |
| Section edges and gaps | 24 logical pixels |
| Major page divisions | 32 logical pixels |
| Overview/library width | At most 1180 logical pixels |
| Form/detail width | At most 760 logical pixels |
| Panel radius | 16 logical pixels |
| Button/field radius | 12 logical pixels |
| Button targets | At least 48 logical pixels, grow with text |

RobotoSlab page headings carry the brand; body text and controls use the
platform's readable sans serif. Use theme colour roles for text, borders,
focus, errors and surfaces. Outlined fields have a visible primary focus border.
Status labels accompany semantic colours. Prefer flat surfaces and quiet borders
to stacks of shadows.

AppPageHeading establishes page hierarchy. AppPanel groups overview content.
AppPage, AppPageListView and AppPageScrollView constrain reading width.
AppFormColumn separates consecutive form controls. AppFormRow stacks related
fields below 560 logical pixels or with enlarged text. AppNavigation provides
the shared drawer with an explicit selected destination.

## Information and behaviour

The dashboard is an overview, with no contract rows, search or list filters.
Counts and costs use the same successfully loaded complete tenant snapshot.
Loading and failed complete reads remain explicit; partial pages never become
totals. Insight cards open Contracts with the relevant filter.

Contracts contains search, filters and paging. Status queries use the backend's
filtered pages. Contractor/end-date filters, drafts, billing review, price-change
review and search use the complete tenant set. Keep the established search
behaviour: a search overrides the quick filters until cleared. Unknown billed
amounts or periods need review; never silently infer a period. End-date windows
use calendar days, including contracts ending today.

Costs are calendar estimates from dated billed prices. Currencies stay separate.
Invoice amounts and payment dates are a different source of information. Invoices
are hidden from the drawer while backend #53 awaits review; existing contract
invoice records and evidence remain available.

The foundation applies to overview, library, contract/contractor forms and details,
tenant management, registration and settings. Existing platform focus, keyboard
navigation and semantic controls remain in use. Page content scrolls as a whole
where possible; overview cards wrap and field rows stack rather than squeezing.

For larger tenants, server aggregates and server-side text/combined filters should
replace full downloads without weakening complete-result guarantees. This is a
scaling follow-up, not an excuse to show partial totals.

## Representative previews

These are rendered Flutter screens using synthetic data, real bundled heading
fonts, SDK body/icon fonts and the implemented themes. They document the first
design pass, not production data.

| Screen | Light | Dark |
| --- | --- | --- |
| Dashboard | [Preview](docs/previews/dashboard-light.png) | [Preview](docs/previews/dashboard-dark.png) |
| Contracts | [Preview](docs/previews/contracts-light.png) | [Preview](docs/previews/contracts-dark.png) |
| Contract form | [Preview](docs/previews/contract-form-light.png) | [Preview](docs/previews/contract-form-dark.png) |
| Contract detail | [Preview](docs/previews/contract-detail-light.png) | [Preview](docs/previews/contract-detail-dark.png) |
| Contractor form | [Preview](docs/previews/contractor-form-light.png) | [Preview](docs/previews/contractor-form-dark.png) |
| Contractor detail | [Preview](docs/previews/contractor-detail-light.png) | [Preview](docs/previews/contractor-detail-dark.png) |
| Tenants | [Preview](docs/previews/tenants-light.png) | [Preview](docs/previews/tenants-dark.png) |

[Phone overview](docs/previews/dashboard-phone.png) ·
[Phone costs](docs/previews/dashboard-phone-costs.png)

The preview test is opt-in. Set QONTRACT_PREVIEW_DIR to the desired output
directory and QONTRACT_PREVIEW_FONT_DIR to the Flutter SDK's
bin/cache/artifacts/material_fonts directory, then run the export-preview case
in test/dashboard_cost_section_test.dart. Normal tests do not write images.

## Next visual review (#40)

Review this direction in the running app before extending it further. Remaining
polish includes a richer desktop navigation treatment, more expressive contract
and contractor detail layouts, consistent file/invoice empty and error panels,
and a comprehensive keyboard/screen-reader audit. Invoice document types and
OCR/AI processing await their separate product and data review in backend #53.
