import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/config/app_info.dart';

void main() {
  test('displayed version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);
    expect(kAppVersion, version);
  });
}
