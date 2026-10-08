import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/config/staging_certificate_pin.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);
  final end = DateTime.utc(2027, 1, 1);
  final now = DateTime.utc(2026, 10, 8);
  final certificate = [1, 2, 3];

  StagingCertificatePin pin(
          {bool debug = true,
          String url = 'https://staging.example:8443/api'}) =>
      StagingCertificatePin(
        debugBuild: debug,
        endpoint: Uri.parse(url),
        certificateDerBase64: base64Encode(certificate),
      );
  bool accepts(StagingCertificatePin pin,
          {List<int>? der,
          String host = 'staging.example',
          int port = 8443,
          DateTime? time}) =>
      pin.accepts(der ?? certificate, host, port,
          notBefore: start, notAfter: end, now: time ?? now);

  test('only exact certificate, endpoint and valid dates are accepted', () {
    expect(accepts(pin()), isTrue);
    expect(accepts(pin(), der: [1, 2, 4]), isFalse);
    expect(accepts(pin(), host: 'other.example'), isFalse);
    expect(accepts(pin(), port: 443), isFalse);
    expect(accepts(pin(), time: start.subtract(const Duration(seconds: 1))),
        isFalse);
    expect(accepts(pin(), time: end.add(const Duration(seconds: 1))), isFalse);
  });
  test('non-debug builds cannot accept a staging certificate', () {
    expect(accepts(pin(debug: false)), isFalse);
  });
  test('invalid configuration fails instead of disabling TLS checks', () {
    expect(
        () => pin(url: 'http://staging.example:8443/api'), throwsArgumentError);
    expect(() => pin(url: 'https://user:password@staging.example/api'),
        throwsArgumentError);
    expect(
        () => StagingCertificatePin(
            debugBuild: true,
            endpoint: Uri.parse('https://staging.example'),
            certificateDerBase64: ''),
        throwsArgumentError);
    expect(
        () => StagingCertificatePin(
            debugBuild: true,
            endpoint: Uri.parse('https://staging.example'),
            certificateDerBase64: '!'),
        throwsFormatException);
  });
}
