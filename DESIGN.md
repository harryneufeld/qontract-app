# qontract design direction

qontract should feel like a calm workspace for decisions about commitments.
Keep the existing lowercase name, q mark and RobotoSlab wordmark. Blue marks
actions and navigation; white panels sit on a faint blue paper background.
The dark alternative uses ink backgrounds, softly outlined surfaces and a
lighter blue accent. Colour never carries a status without a written label.

## External design references

For all UI work, also read [the selected design references](docs/design-references/README.md)
from [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md).
Linear is the primary reference for restrained surfaces, borders, and controls;
Notion supports readable content grouping, and IBM supports structured forms and
dense information. The local reference guide explains the adaptations for qontract.
These references inform the implementation; the rules in this document remain
authoritative, including both themes, branding, accessibility, and app behavior.

## Shared rules

Implementation: lib/app_theme.dart and lib/widgets/app_design.dart.

| Role | Rule |
| --- | --- |
| Neighbouring actions | 8 logical pixels minimum |
| Form fields and groups | 16 logical pixels |
| Section edges and gaps | 24 logical pixels |
| Major page divisions | 32 logical pixels |
| Overview/library width | At most 1180 logical pixels |
| Form width | At most 760 logical pixels |
| Contract detail width | At most 1180 logical pixels; two columns above 900 |
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

The drawer uses compact 48-pixel rows with horizontal padding only. Its
destinations are Dashboard, Contracts, Contractors, Account and Settings.
Tenant management remains accessible through Account; documents are accessed
from their contracts. On a pushed Contracts page, the app bar shows Back.
The root Contracts page retains its drawer because there is no previous page.
The wordmark uses the theme primary colour for its q on dark backgrounds.

## Information and behaviour

The dashboard is an overview with a compact shortcut group for up to three
recently updated contracts, ordered by saved modification time. It follows the
selected responsibility scope and excludes deleted contracts. Search and full
contract lists remain on Contracts.
Counts and costs use the same successfully loaded complete tenant snapshot.
Loading and failed complete reads remain explicit; partial pages never become
totals. Insight cards open Contracts with the relevant filter.

Contracts puts search first, then wrapping Material filter chips for workflow
status. Additional selections live in a staged panel: a bottom sheet on phones,
a dialog on desktop. Apply commits the draft, Cancel leaves the library untouched,
and Reset updates both the draft and the visible fields. Active selections appear
as removable chips, with Clear all as an explicit escape hatch.
Status labels, borders and selected backgrounds share semantic colours: green
for Active, blue for Draft, grey for Expired and red for Terminated. Written
labels and selection checkmarks remain visible; colour is an additional cue.

Search composes with status, contractor, end-date, type and billed-period filters.
Status-only queries use backend pages; combined filters, search, drafts, terminated
contracts, billing review, price-change review and custom sorting use the complete
tenant set. Never display a partial page as complete matches. Loading/error panels
keep the controls available. Late list, paging and refresh responses cannot replace
a newer filter selection. Unknown billed amounts or periods need review; never
infer a period. End-date windows include contracts ending today.

Contract details use a strong identity and billing summary, a two-column desktop
layout and horizontal fact groups where they fit. Information, dates, price history,
documents, linked contractor and creation/update history use the existing saved
values. Narrow layouts put core information and dates first, then further details.
Copyable notes, descriptions and account values remain complete. Missing data is
explicit; do not invent renewal dates, payment states or financial estimates.

Primary create actions use a plus-only button at the bottom, with an accessible
tooltip. Edit also stays at the bottom of detail pages; destructive lifecycle actions
remain secondary and keep their existing confirmation. Contextual actions such as
opening a contractor or attaching a document stay with their content.
AppBottomActions renders every bottom action as the same 56-pixel floating
button with the shared 12-pixel corner radius and an 8-pixel gap. Primary actions
use primary/onPrimary; Delete and Deactivate use errorContainer/onErrorContainer.
Other secondary actions use secondaryContainer/onSecondaryContainer. Action specs
keep individual screens from substituting a smaller circular control.

The Contracts redesign follows the filtering role and state treatment of Flutter's
[Material FilterChip](https://api.flutter.dev/flutter/material/FilterChip-class.html),
compared with the official [Material 3 demo](https://github.com/flutter/samples/tree/main/material_3_demo).
The detail layout applies the wide/narrow composition principle from Flutter's
[adaptive navigation/detail example](https://docs.flutter.dev/learn/pathway/tutorial/navigation).
These are reference patterns; qontract keeps its blue surfaces and slab headings.

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
| Contracts, active filter and Back | [Preview](docs/previews/contracts-active-light.png) | [Preview](docs/previews/contracts-active-dark.png) |
| Flyout navigation | [Preview](docs/previews/navigation-light.png) | [Preview](docs/previews/navigation-dark.png) |
| Contract form | [Preview](docs/previews/contract-form-light.png) | [Preview](docs/previews/contract-form-dark.png) |
| Contract detail | [Preview](docs/previews/contract-detail-light.png) | [Preview](docs/previews/contract-detail-dark.png) |
| Contractor form | [Preview](docs/previews/contractor-form-light.png) | [Preview](docs/previews/contractor-form-dark.png) |
| Contractor detail | [Preview](docs/previews/contractor-detail-light.png) | [Preview](docs/previews/contractor-detail-dark.png) |
| Tenants | [Preview](docs/previews/tenants-light.png) | [Preview](docs/previews/tenants-dark.png) |

[Phone overview](docs/previews/dashboard-phone.png) ·
[Phone costs](docs/previews/dashboard-phone-costs.png)
[Phone Contracts](docs/previews/contracts-phone-light.png) ·
[Phone contract details](docs/previews/contract-detail-phone-light.png) ·
[Phone filters](docs/previews/filters-phone-light.png) ·
[Desktop filters](docs/previews/contracts-filters-light.png)
(dark equivalents are alongside these in docs/previews).

The preview test is opt-in. Set QONTRACT_PREVIEW_DIR to the desired output
directory and QONTRACT_PREVIEW_FONT_DIR to the Flutter SDK's
bin/cache/artifacts/material_fonts directory, then run the export-preview case
in test/dashboard_cost_section_test.dart. Normal tests do not write images.

## Next visual review (#40)

Review this direction in the running app before extending it further. Remaining
polish includes a richer desktop navigation treatment, further contractor detail
refinements, consistent file/invoice empty and error panels,
and a comprehensive keyboard/screen-reader audit. Invoice document types and
OCR/AI processing await their separate product and data review in backend #53.

## Document import

Keep the review focused on editable title/date and destination. Show filename once;
give the detected date and contract number their own review disclosures, each
with its value, editable field and source. Keep full recognized text secondary. Contract
suggestions show identity immediately, with matching passages available on demand.
Use the shared form spacing, flat collection rows and theme colors. Keep one save
action available at the bottom, alongside the destination's visibility notice.
Preselect a uniquely highest-scoring contract, clearly showing relative evidence
points and requiring Save. Ties remain unselected; manual choices survive refresh.
Scores are not calibrated confidence percentages.

Compact AppCollection groups use horizontal row padding and 48-pixel minimum
targets, growing naturally for wrapped labels and enlarged text.

Selection menus share showAppSelection: a draggable, dismissible bottom sheet
on phones and a bounded dialog on desktop. Search stays above scrollable choices;
controls and rows grow with enlarged text, and keyboard insets remain respected.

Document review keeps a local Preview action next to the filename, available even
when recognition fails. Returning preserves edits and never saves automatically.
A filename fallback is labelled explicitly when no subject could be extracted.

## Currency

Amounts and currency pickers show symbols (€, $, CA$, A$, CHF); codes whose symbol would be ambiguous (SEK, NOK, DKK) stay as codes. ISO codes remain the stored value.
