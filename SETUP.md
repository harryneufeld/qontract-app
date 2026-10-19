# qontract development setup

This guide describes prerequisites, not the installation state of any particular machine.

1. Install a current Flutter 3.x SDK compatible with `pubspec.yaml` and add its `bin` directory to PATH.
2. Run `flutter doctor` and install the toolchain needed for your target (browser, Android, desktop, or macOS/Xcode for iOS).
3. Install .NET 10 to run `qontract-backend`; start its API as described in its README.
4. From this repository:

```bash
flutter pub get
flutter run --dart-define=QONTRACT_API_BASE_URL=http://localhost:65533/api
```

Use `http://10.0.2.2:65533/api` on an Android emulator, or a reachable LAN address on a physical phone. The default configuration is in `lib/config/api_config.dart`; an explicit build definition avoids depending on machine-specific edits.

```bash
flutter analyze
flutter test
```

See [README.md](README.md) for features and [DEPLOY.md](DEPLOY.md) for Linux Docker staging/production and mobile release requirements.
