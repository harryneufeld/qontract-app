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

/// Imprint and privacy policy are hosted outside the app so the publisher's
/// contact details stay out of the repository. Set them per build with
/// `--dart-define=QONTRACT_IMPRINT_URL=<url>` and `QONTRACT_PRIVACY_URL`;
/// a link whose URL is not set is not shown.
const String kImprintUrl = String.fromEnvironment('QONTRACT_IMPRINT_URL');
const String kPrivacyUrl = String.fromEnvironment('QONTRACT_PRIVACY_URL');

/// Parses a configured link URL; null when unset or invalid.
Uri? configuredUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasScheme ? uri : null;
}
