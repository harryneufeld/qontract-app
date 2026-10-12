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
  final value = object['QONTRACT_API_BASE_URL'];
  if (value == null || !value.isA<JSString>()) {
    return const <String, String>{};
  }
  return <String, String>{
    'QONTRACT_API_BASE_URL': (value as JSString).toDart,
  };
}
