import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'staging_certificate_pin.dart';

void configureStagingCertificateTrust(Dio dio, String baseUrl) {
  const certificate =
      String.fromEnvironment('QONTRACT_STAGING_CERT_DER_BASE64');
  if (!kDebugMode || certificate.isEmpty) return;

  final pin = StagingCertificatePin(
    debugBuild: kDebugMode,
    endpoint: Uri.parse(baseUrl),
    certificateDerBase64: certificate,
  );
  bool accepts(X509Certificate? cert, String host, int port) =>
      cert != null &&
      pin.accepts(cert.der, host, port,
          notBefore: cert.startValidity, notAfter: cert.endValidity);

  // Refuse redirect hops rather than sending account headers to another host.
  dio.options.followRedirects = false;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..badCertificateCallback = accepts,
    validateCertificate: accepts,
  );
}
