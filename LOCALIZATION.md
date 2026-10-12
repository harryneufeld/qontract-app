# English and German

Issue: https://github.com/harryneufeld/qontract-app/issues/70

The app follows the first supported device language, falling back to English.
Settings and the language menu on the public authentication screens offer
device language, English and Deutsch. The choice is stored locally as
`app.language`, independently of the current account or workspace. It survives
restarts and logout; changing it does not discard the current navigation stack.

## Adding or changing copy

- Edit `lib/l10n/app_en.arb` and `app_de.arb` together. English is the template.
- Run `flutter gen-l10n`. Generated files under `lib/l10n/generated` are ignored;
  `flutter pub get` also generates them before analysis, tests and builds.
- In widgets, use `context.l10n` from `lib/l10n/strings.dart`. This subscribes to
  Flutter's inherited locale so open screens update immediately.
- Non-widget presentation helpers and request-time error messages use
  `S.current`, synchronized by `LocaleProvider`. Keep models' JSON keys and
  enums invariant. Translation maps for categories/periods are getters so their
  labels follow the current language while their API keys stay unchanged.
- Use ICU plural messages for counts. German copy includes discretionary soft
  hyphens in long compound words so large system text can break naturally.
- Never run user-provided titles, notes, file categories, names or document
  contents through the translation catalog.

## Dates, numbers and errors

English retains the existing `YYYY-MM-DD` date display. German uses
`DD.MM.YYYY`. `DatePickerFormField` keeps a separate display controller and
passes strict ISO values to callers; it rejects impossible calendar dates and
supports ISO paste in German. Flutter's calendar and standard dialogs use its
English/German localization delegates. Displayed amounts and file sizes use
localized separators. `DecimalFormField` preserves exact decimal strings in
its caller's controller and shows a decimal comma in German. Manual amounts
accept a decimal dot or comma, without currency/grouping separators; saving
normalizes classified amounts to an invariant decimal dot without converting
through a floating-point number. Unclassified legacy free-text amounts remain
verbatim. Displayed currency totals use existing rounding; stored amounts and
invoice editing retain their original precision.

Every request sends `Accept-Language` using the resolved app language, including
public password reset requests. The companion backend returns
`Content-Language` and localizes only application-owned messages/validation.
German clients receiving English errors from an older backend show a localized
fallback. Password reset emails carry the requested language through the worker
queue and include `lang=en`/`lang=de` in the reset link. A supported link language
applies to that app session without overwriting the device's saved choice;
explicit language selection overrides it. Malformed/duplicate language values
are ignored. No database migration is required.

## Verification

Run `flutter analyze` and `flutter test`. Localization tests cover catalog
parity, plurals, device/persistent selection, live switching, strict dates,
exact decimal input, unchanged user/API values, request headers, safe error
fallbacks, German calendar actions, reset links and contract/invoice saves.
Four layout scenarios exercise fourteen German pages at phone/tablet sizes,
landscape and doubled text, including both themes and reduced motion.

Optional screenshot export with synthetic data:

```text
flutter test test/localization_test.dart --dart-define=QONTRACT_CAPTURE_LOCALIZATION=true --dart-define=QONTRACT_PREVIEW_DIR=<absolute-output-directory> --dart-define=QONTRACT_PREVIEW_FONT_DIR=<flutter-sdk>/bin/cache/artifacts/material_fonts
```

Native file pickers and external email/phone apps follow their platform's own
language. The app localizes the text it supplies to them. iOS declares English
and German bundle support; native iOS compilation requires macOS.
