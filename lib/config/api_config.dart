import 'package:flutter/foundation.dart';

import 'platform_environment_io.dart'
    if (dart.library.js_interop) 'platform_environment_web.dart';

/// Default backend: production. Local development passes
/// `--dart-define=QONTRACT_API_BASE_URL=http://localhost:65533/api`.
const String kDefaultApiBaseUrl = 'https://api.qontract.app/api';

/// Environment variable name for overriding the backend address at runtime
/// (container support). Also honored at build time via
/// `--dart-define=QONTRACT_API_BASE_URL=<url>`. On web the runtime value comes
/// from `window.qontractConfig` in `config.js`, written by the web container.
const String kApiBaseUrlEnvVar = 'QONTRACT_API_BASE_URL';

const String kAllowServerSwitchEnvVar = 'QONTRACT_ALLOW_SERVER_SWITCH';

/// Web deployments use their configured server unless switching is opted in.
/// Build-time values take precedence over runtime config.js/process values.
bool get isApiHostSwitchingEnabled => resolveApiHostSwitching(
      buildValue: const String.fromEnvironment(kAllowServerSwitchEnvVar),
      runtimeValue: getRuntimeEnvironment()[kAllowServerSwitchEnvVar],
    );

bool resolveApiHostSwitching(
    {bool isWeb = kIsWeb, String? buildValue, String? runtimeValue}) {
  final value = buildValue?.trim().isNotEmpty == true
      ? buildValue!.trim()
      : runtimeValue?.trim();
  if (value == null || value.isEmpty) return !isWeb;
  return value == 'true';
}

/// Host the user picked in the app (see `ApiHostProvider`), or null to use
/// the configured default. Read on every request, so switching takes effect
/// for existing `ApiService` instances too.
String? _selectedApiBaseUrl;

String? get selectedApiBaseUrl => _selectedApiBaseUrl;

void setSelectedApiBaseUrl(String? url) {
  _selectedApiBaseUrl =
      url == null || url.trim().isEmpty ? null : normalizeApiBaseUrl(url);
}

/// The base URL used when the user has not picked a host.
String defaultApiBaseUrl() => _resolve(null, useSelection: false);

/// Resolves the backend base URL.
///
/// Priority:
/// 1. [explicit] value (e.g. `ApiService(baseUrl: ...)` / tests)
/// 2. Host selected in the app ([setSelectedApiBaseUrl])
/// 3. Build-time `--dart-define=QONTRACT_API_BASE_URL=...`
/// 4. Runtime `QONTRACT_API_BASE_URL`: the process environment on
///    mobile/desktop, `window.qontractConfig` (`config.js`) on web
/// 5. [kDefaultApiBaseUrl]
///
/// The URL is normalized with [normalizeApiBaseUrl].
String resolveApiBaseUrl({String? explicit}) =>
    _resolve(explicit, useSelection: true);

String _resolve(String? explicit, {required bool useSelection}) {
  String? raw;
  if (explicit != null && explicit.trim().isNotEmpty) {
    raw = explicit;
  } else if (useSelection && _selectedApiBaseUrl != null) {
    raw = _selectedApiBaseUrl;
  } else {
    const dartDefine = String.fromEnvironment(kApiBaseUrlEnvVar);
    if (dartDefine.isNotEmpty) {
      raw = dartDefine;
    } else {
      raw = getRuntimeEnvironment()[kApiBaseUrlEnvVar];
    }
  }
  if (raw == null || raw.trim().isEmpty) {
    return kDefaultApiBaseUrl;
  }
  return normalizeApiBaseUrl(raw);
}

/// Whitespace trimmed, trailing slashes removed, and the `/api` path segment
/// appended when missing (the backend always serves under `/api`).
String normalizeApiBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (!url.endsWith('/api')) {
    url = '$url/api';
  }
  return url;
}

/// Normalizes a user-entered server address, or returns null when it is not
/// an absolute http(s) URL with a host. A missing scheme defaults to https.
String? parseApiHostInput(String input) {
  var text = input.trim();
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return normalizeApiBaseUrl(text);
}
