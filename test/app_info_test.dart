import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qontract_app/config/app_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('displayed version comes from built package metadata', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);
    PackageInfo.setMockInitialValues(
        appName: 'qontract',
        packageName: 'app.qontract',
        version: version!,
        buildNumber: '3',
        buildSignature: '');
    await loadAppInfo();
    expect(kAppVersion, version);
  });

  test('build-time version override is shown instead of source version',
      () async {
    PackageInfo.setMockInitialValues(
        appName: 'qontract',
        packageName: 'app.qontract',
        version: '9.8.7',
        buildNumber: '42',
        buildSignature: '');
    await loadAppInfo();
    expect(kAppVersion, '9.8.7');
  });
}
