import 'dart:convert';

/// Explicit, debug-only trust for one self-signed LAN endpoint.
class StagingCertificatePin {
  final bool debugBuild;
  final Uri endpoint;
  final String certificateDerBase64;

  StagingCertificatePin({
    required this.debugBuild,
    required this.endpoint,
    required String certificateDerBase64,
  }) : certificateDerBase64 = base64Encode(base64Decode(certificateDerBase64)) {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        this.certificateDerBase64.isEmpty) {
      throw ArgumentError(
          'Staging certificate trust requires an HTTPS endpoint and certificate.');
    }
  }

  bool accepts(
    List<int> certificateDer,
    String host,
    int port, {
    required DateTime notBefore,
    required DateTime notAfter,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return debugBuild &&
        host.toLowerCase() == endpoint.host.toLowerCase() &&
        port == endpoint.port &&
        !time.isBefore(notBefore) &&
        !time.isAfter(notAfter) &&
        base64Encode(certificateDer) == certificateDerBase64;
  }
}
