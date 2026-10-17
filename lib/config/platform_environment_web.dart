import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Runtime configuration on the web platform.
///
/// Browsers have no process environment, so the web container writes
/// `config.js` at startup (`deploy/docker-entrypoint.d/40-qontract-config.sh`),
/// which sets `window.qontractConfig`. Only string values are returned.
Map<String, String> getRuntimeEnvironment() {
  final config = globalContext['qontractConfig'];
  if (config == null || !config.isA<JSObject>()) {
    return const <String, String>{};
  }
  final object = config as JSObject;
  final environment = <String, String>{};
  for (final key in ['QONTRACT_API_BASE_URL', 'QONTRACT_ALLOW_SERVER_SWITCH']) {
    final value = object[key];
    if (value != null && value.isA<JSString>()) {
      environment[key] = (value as JSString).toDart;
    }
  }
  return environment;
}
