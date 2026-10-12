/// Product and publisher details shown in the legal footer and pages.
///
/// [kAppVersion] mirrors `version:` in pubspec.yaml (without the build number);
/// `test/app_info_test.dart` fails when the two drift apart.
const String kAppVersion = '1.0.0';

const String kCopyrightHolder = 'Harry Neufeld';
final Uri kCopyrightUrl = Uri.parse('https://harry-neufeld.de');

const String kPoweredByLabel = 'line-of-business.com';
final Uri kPoweredByUrl = Uri.parse('https://www.line-of-business.com');
