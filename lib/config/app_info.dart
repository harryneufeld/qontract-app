import 'package:package_info_plus/package_info_plus.dart';

PackageInfo? _packageInfo;

/// Central version used by the footer and license page. Read from the built
/// package so pubspec.yaml and build-time version overrides remain authoritative.
String get kAppVersion => _packageInfo?.version ?? '—';

/// Load once before runApp. Unavailable metadata must not prevent app startup.
Future<void> loadAppInfo() async {
  try {
    _packageInfo =
        await PackageInfo.fromPlatform().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Keep a known version, or show an honest placeholder rather than a stale one.
  }
}

const String kCopyrightHolder = 'Harry Neufeld';
const String kLicenseName = 'AGPL-3.0';
final Uri kCopyrightUrl = Uri.parse('https://harry-neufeld.de');

const String kPoweredByLabel = 'line-of-business.com';
final Uri kPoweredByUrl = Uri.parse('https://www.line-of-business.com');

/// Imprint and privacy policy are hosted on the publisher's website so their
/// contact details stay out of the repository. Override per build with
/// `--dart-define=QONTRACT_IMPRINT_URL=<url>` and `QONTRACT_PRIVACY_URL`.
final Uri kImprintUrl = Uri.parse(const String.fromEnvironment(
    'QONTRACT_IMPRINT_URL',
    defaultValue: ''));
final Uri kPrivacyUrl = Uri.parse(const String.fromEnvironment(
    'QONTRACT_PRIVACY_URL',
    defaultValue: ''));
