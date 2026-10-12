import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds qontract's own license (AGPL-3.0) and the bundled fonts and PDF.js to
/// Flutter's license page, which already lists all Dart/Flutter packages.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    Future<LicenseEntry> entry(List<String> packages, String asset) async =>
        LicenseEntryWithLineBreaks(
            packages, await rootBundle.loadString(asset));

    yield await entry(const ['qontract'], 'LICENSE');
    yield await entry(
        const ['Roboto (font)'], 'assets/fonts/Roboto-Apache-2.0.txt');
    yield await entry(
        const ['Roboto Slab (font)'], 'assets/fonts/RobotoSlab-Apache-2.0.txt');
    yield await entry(const ['PDF.js'], 'web/pdfjs/LICENSE');
  });
}
