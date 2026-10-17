import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// A backend the user saved on this device. [url] is normalized (ends in
/// `/api`) and identifies the entry.
@immutable
class ApiHost {
  final String name;
  final String url;
  const ApiHost({required this.name, required this.url});

  Map<String, String> toJson() => {'name': name, 'url': url};

  static ApiHost? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['url'];
    if (url is! String) return null;
    final normalized = parseApiHostInput(url);
    if (normalized == null) return null;
    final name = json['name'];
    return ApiHost(
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : Uri.parse(normalized).host,
      url: normalized,
    );
  }
}

/// Saved API hosts and the active one (device-level, not tenant-scoped).
///
/// The active host is pushed into [setSelectedApiBaseUrl], which every
/// `ApiService` reads per request. Null [activeUrl] means the configured
/// default ([defaultApiBaseUrl]). Callers own the session: switching hosts
/// while signed in must sign out first, since tokens belong to one backend.
class ApiHostProvider extends ChangeNotifier {
  ApiHostProvider({SharedPreferences? prefs, bool? switchingEnabled})
      : _prefs = prefs,
        switchingEnabled = switchingEnabled ?? isApiHostSwitchingEnabled;

  final bool switchingEnabled;

  static const String hostsKey = 'app.apiHosts';
  static const String activeKey = 'app.apiHost';

  final SharedPreferences? _prefs;
  List<ApiHost> _hosts = const [];
  String? _activeUrl;

  List<ApiHost> get hosts => List.unmodifiable(_hosts);
  String? get activeUrl => _activeUrl;
  String get defaultUrl => defaultApiBaseUrl();
  String get effectiveUrl => _activeUrl ?? defaultUrl;

  /// Loads the stored hosts (call once at app start, before any request).
  Future<void> init() async {
    final prefs = await _resolvePrefs();
    if (!switchingEnabled) {
      // A saved alternative server must not override deployment policy or
      // send that server's cached credentials to the configured backend.
      final active = prefs.getString(activeKey);
      if (active != null && active != defaultUrl) {
        await ApiService().clearToken();
        await StorageService().clearUser();
      }
      await prefs.remove(activeKey);
      _hosts = const [];
      _activeUrl = null;
      setSelectedApiBaseUrl(null);
      notifyListeners();
      return;
    }
    final hosts = <ApiHost>[];
    try {
      final decoded = jsonDecode(prefs.getString(hostsKey) ?? '[]');
      if (decoded is List) {
        for (final entry in decoded) {
          final host = ApiHost.fromJson(entry);
          if (host != null && hosts.every((h) => h.url != host.url)) {
            hosts.add(host);
          }
        }
      }
    } on FormatException {
      // Corrupted list: start empty rather than failing app start.
    }
    _hosts = hosts;
    final active = prefs.getString(activeKey);
    _activeUrl = hosts.any((h) => h.url == active) ? active : null;
    setSelectedApiBaseUrl(_activeUrl);
    notifyListeners();
  }

  /// Saves a host (or renames an existing one with the same URL) and returns
  /// it, or null when [address] is not a valid http(s) URL.
  Future<ApiHost?> save(String address, {String? name}) async {
    if (!switchingEnabled) return null;
    final url = parseApiHostInput(address);
    if (url == null) return null;
    final host = ApiHost(
      name: name != null && name.trim().isNotEmpty
          ? name.trim()
          : Uri.parse(url).host,
      url: url,
    );
    final index = _hosts.indexWhere((h) => h.url == url);
    _hosts = [..._hosts];
    if (index >= 0) {
      _hosts[index] = host;
    } else {
      _hosts.add(host);
    }
    notifyListeners();
    await _persist();
    return host;
  }

  /// Makes [url] (a saved host) active; null returns to the default.
  Future<void> select(String? url) async {
    if (!switchingEnabled) return;
    if (url != null && _hosts.every((h) => h.url != url)) return;
    if (url == _activeUrl) return;
    _activeUrl = url;
    setSelectedApiBaseUrl(url);
    notifyListeners();
    await _persist();
  }

  /// Removes a saved host. The active host cannot be removed — switch away
  /// first, so the session is handled by the caller.
  Future<void> remove(String url) async {
    if (!switchingEnabled) return;
    if (url == _activeUrl) return;
    _hosts = _hosts.where((h) => h.url != url).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await _resolvePrefs();
    await prefs.setString(
        hostsKey, jsonEncode([for (final h in _hosts) h.toJson()]));
    if (_activeUrl == null) {
      await prefs.remove(activeKey);
    } else {
      await prefs.setString(activeKey, _activeUrl!);
    }
  }

  Future<SharedPreferences> _resolvePrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();
}
