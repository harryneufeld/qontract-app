# qontract

**Keep every contract, subscription and insurance policy in one place — and know what they really cost.**

qontract is a privacy-first contract manager for households and small businesses.
Track insurance, loans, subscriptions and service contracts together with their
documents, price history, end dates and minimum terms, and see your monthly,
quarterly and yearly costs at a glance.

This repository contains the app for Android, iOS and the web, built with Flutter.
The server lives in [qontract-backend](https://github.com/harryneufeld/qontract-backend).

## Why qontract

- **Document import with OCR and one-step contract assignment.** Share a PDF or a
  photo of a letter to qontract from any app. The text is recognised on your
  phone, qontract suggests the matching contract (by contract number, contractor,
  title or IBAN) along with the document date and subject, and you file it with a
  single confirmation. Nothing is attached without your review.
- **Private by design.** OCR runs entirely on the device — Tesseract on Android,
  Apple Vision on iPhone — and the recognised text never leaves your phone.
  Only the original file is uploaded, only to the qontract backend you connect
  to (your own server if you self-host), and only when you save. No third-party
  services are involved.
- **Open source and self-hostable.** Licensed under the AGPL-3.0. Run your own
  backend with Docker on SQLite or PostgreSQL and point the app at it from the
  login screen.
- **Personal and shared workspaces.** Keep private contracts to yourself and share
  others with your household or company, with roles, invitation codes and a
  workspace switcher.
- **Costs you can trust.** Monthly, quarterly and yearly totals across all active
  contracts, dated price history, separate currencies, and insights for upcoming
  end dates, minimum terms and price changes.
- **Documents attached to contracts.** Versioning, shared links across contracts,
  private and shared file libraries, in-app PDF preview, and a trash with restore.

## Features

- Contracts with contractors, contract numbers, IBAN, business type (insurance,
  loan, subscription, …), billing period, notes and responsible member
- Dashboard with workspace statistics, cost estimates and actionable insights
- Search, filters and sorting across the complete workspace
- Contractors with contact details, website and addresses
- Document import, upload, versioning and preview
- Sign-in with optional two-factor authentication (authenticator app),
  password reset by email and revocable sessions
- English and German, light and dark themes, phone and desktop layouts

## Getting started

Requirements: a current Flutter 3.x SDK and a running
[qontract-backend](https://github.com/harryneufeld/qontract-backend).

```bash
flutter pub get
flutter run --dart-define=QONTRACT_API_BASE_URL=http://localhost:65533/api
```

On an Android emulator use `http://10.0.2.2:65533/api`; on a physical phone use
your computer's LAN address. The server can also be changed in the app on the
login screen or under **Settings → Server**.

Run the checks with:

```bash
flutter analyze
flutter test
```

See [SETUP.md](SETUP.md) for platform toolchains and [DEPLOY.md](DEPLOY.md) for
Docker web hosting and Android/iOS release builds.

## Documentation

- [Implementation notes](docs/IMPLEMENTATION-NOTES.md) — detailed feature behaviour, OCR and import pipeline
- [DESIGN.md](DESIGN.md) — design language and components
- [LOCALIZATION.md](LOCALIZATION.md) — translations and locale handling
- [PLAN.md](PLAN.md) — roadmap and remaining work
- [DEPLOY.md](DEPLOY.md) — web, Android and iOS deployment

## Contributing

Issues and pull requests are welcome. Please open an issue to discuss larger
changes first. Changes to `main` go through pull requests; run `flutter analyze`
and `flutter test` before submitting.

## License

Copyright © 2026 Harry Neufeld.

qontract is free software: you can redistribute it and/or modify it under the
terms of the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0). If you
run a modified version as a network service, the AGPL requires you to offer its
users the corresponding source code.

Bundled third-party components keep their own licenses: Roboto and Roboto Slab
(`assets/fonts/`, Apache 2.0), PDF.js (`web/pdfjs/`, Apache 2.0) and the
Tesseract language data (Apache 2.0). The in-app license page lists these
together with all Dart and Flutter package licenses.
