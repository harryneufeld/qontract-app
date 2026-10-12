import 'platform_environment_io.dart'
    if (dart.library.js_interop) 'platform_environment_web.dart';

/// Default local-dev backend address.
const String kDefaultApiBaseUrl = 'http://localhost:65533/api';

/// Environment variable name for overriding the backend address at runtime
/// (container support). Also honored at build time via
/// `--dart-define=QONTRACT_API_BASE_URL=<url>`. On web the runtime value comes
/// from `window.qontractConfig` in `config.js`, written by the web container.
const String kApiBaseUrlEnvVar = 'QONTRACT_API_BASE_URL';

/// Resolves the backend base URL.
///
/// Priority:
/// 1. [explicit] value (e.g. `ApiService(baseUrl: ...)` / tests)
/// 2. Build-time `--dart-define=QONTRACT_API_BASE_URL=...`
/// 3. Runtime `QONTRACT_API_BASE_URL`: the process environment on
///    mobile/desktop, `window.qontractConfig` (`config.js`) on web
/// 4. [kDefaultApiBaseUrl]
///
/// The URL is normalized: whitespace trimmed, trailing slashes removed, and
/// the `/api` path segment is appended when missing (the backend always
/// serves under `/api`).
String resolveApiBaseUrl({String? explicit}) {
  String? raw;
  if (explicit != null && explicit.trim().isNotEmpty) {
    raw = explicit;
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
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (!url.endsWith('/api')) {
    url = '$url/api';
  }
  return url;
}
