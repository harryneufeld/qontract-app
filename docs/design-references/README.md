# Design references for qontract

Source collection: [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md).
Selected documents reviewed on 2026-10-18.

The collection contains design analyses of public websites, rather than a Flutter
component library or a development skill. The selections below are inspiration
for app UI work. [qontract's DESIGN.md](../../DESIGN.md) defines the final rules.
This local summary is sufficient for routine work without network access; the
upstream links provide additional detail. These summaries are our adaptations,
not official guidance from the referenced brands.

## Primary reference: Linear

[Upstream DESIGN.md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/linear.app/DESIGN.md)

The analysis describes near-black and charcoal surfaces, subtle borders,
restrained lavender accents, compact controls, and a hierarchy of surface colors.

Apply to qontract:

- Keep navigation, contract lists, filters, and detail panels visually quiet.
- Use subtle surface and border differences to group information.
- Reserve the existing blue accent for primary actions, selected navigation,
  focus, and deliberate emphasis; retain semantic colors with written labels.
- Align controls and repeated rows consistently. Compact desktop presentation
  must still meet qontract's touch target and enlarged-text requirements.
- Extend the same hierarchy to both the paper light theme and the ink dark theme.

Do not import Linear's dark-only marketing direction, oversized headings,
promotional sections, custom fonts, or marketing restrictions on status colors.

## Supporting reference: Notion

[Upstream DESIGN.md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/notion/DESIGN.md)

The analysis includes white and soft neutral surfaces, readable body typography,
blue actions, and pastel category colors alongside prominent marketing content.

Apply to qontract's contract details, documents, notes, and forms: group related
facts clearly, preserve comfortable reading space, and use subdued backgrounds
for secondary information. Keep qontract's RobotoSlab headings and existing body
font. Pastel accents must have a defined purpose and sufficient contrast.
Promotional illustrations, hero layouts, and large display type are outside
this app direction.

## Supporting reference: IBM

[Upstream DESIGN.md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/ibm/DESIGN.md)

The analysis describes a Carbon-inspired marketing system with structured grids,
flat surfaces, thin borders, clear type hierarchy, and explicit semantic colors.

Apply these principles to forms, dense record views, and administration: align
labels and values, separate groups consistently, and make action hierarchy and
error states clear. Preserve qontract's blue palette and established corner
radii rather than adopting IBM blue or square controls.

## How to use the references

Start with DESIGN.md and the relevant shared Flutter components. Use Linear as
the primary visual reference; use the supporting references only for the screen
roles described above. Do not combine each brand's complete visual system.

Translate ideas into Flutter theme roles and shared components rather than
copying website CSS or pixel-based breakpoints. Preserve the existing information
architecture, saved data, business behavior, accessibility, and platform controls
unless the task explicitly calls for changes to them.

When a useful pattern becomes a qontract rule, document it in DESIGN.md and
verify it in the affected app screens. Updating these documents alone does not
change the running app.
