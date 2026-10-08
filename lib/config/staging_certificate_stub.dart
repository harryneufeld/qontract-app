import 'package:dio/dio.dart';

// Browser trust is managed by the browser, never by the native test pin.
void configureStagingCertificateTrust(Dio dio, String baseUrl) {}
