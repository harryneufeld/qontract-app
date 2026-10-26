import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key/value surface of the platform keystore, so tests can swap it.
abstract class SecretBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemorySecretBackend implements SecretBackend {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Keychain (iOS/macOS), Keystore-backed storage (Android) and the platform
/// equivalents elsewhere. When the keystore cannot be used (no plugin in unit
/// tests, a corrupted keystore after a device restore) the value is kept in
/// memory instead, so signing in never fails; it then lasts until the app
/// is closed.
class PlatformSecretBackend implements SecretBackend {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final MemorySecretBackend _fallback = MemorySecretBackend();

  @override
  Future<String?> read(String key) async {
    final remembered = await _fallback.read(key);
    if (remembered != null) return remembered;
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      await _fallback.delete(key);
    } catch (_) {
      await _fallback.write(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _fallback.delete(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Nothing stored that could be removed.
    }
  }
}

/// What is stored for one API server.
class StoredTokens {
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;

  const StoredTokens({this.accessToken, this.refreshToken, this.accessExpiresAt});

  static const empty = StoredTokens();
}

/// Session tokens, kept per API base URL so credentials are never offered to
/// another server.
///
/// Mobile and desktop keep the access token, refresh token and the access
/// expiry in the platform keystore. Web keeps only the access token, in
/// memory: the refresh token lives in an HttpOnly cookie that scripts cannot
/// read, and a reload starts without an access token and refreshes first.
class TokenStore {
  TokenStore({SecretBackend? backend, bool? web})
      : isWeb = web ?? kIsWeb,
        _backend = backend ?? PlatformSecretBackend();

  /// Shared by every [ApiService] instance. Tests replace it.
  static TokenStore shared = TokenStore();

  /// Pre-keystore location of the access token.
  static const legacyPrefsKey = 'jwt_token';

  final bool isWeb;
  final SecretBackend _backend;
  final Map<String, StoredTokens> _cache = {};

  String _key(String baseUrl, String field) => 'qontract.$field|$baseUrl';

  Future<StoredTokens> read(String baseUrl) async {
    await _migrateLegacy(baseUrl);
    final cached = _cache[baseUrl];
    if (cached != null) return cached;
    if (isWeb) return StoredTokens.empty;
    final access = await _backend.read(_key(baseUrl, 'access'));
    final refresh = await _backend.read(_key(baseUrl, 'refresh'));
    final expiry = DateTime.tryParse(
        await _backend.read(_key(baseUrl, 'accessExpiresAt')) ?? '');
    return _cache[baseUrl] = StoredTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expiry ?? _expiryOf(access));
  }

  /// A login, registration or confirmation: replaces everything stored.
  Future<void> startSession(String baseUrl,
      {required String accessToken,
      String? refreshToken,
      DateTime? accessExpiresAt}) async {
    await _migrateLegacy(baseUrl);
    await _write(
        baseUrl,
        StoredTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessExpiresAt: accessExpiresAt ?? _expiryOf(accessToken)));
  }

  /// A tenant switch or a refresh: new access token, refresh token kept
  /// unless the server rotated it.
  Future<void> updateAccess(String baseUrl,
      {required String accessToken,
      String? refreshToken,
      DateTime? accessExpiresAt}) async {
    final current = await read(baseUrl);
    await _write(
        baseUrl,
        StoredTokens(
            accessToken: accessToken,
            refreshToken: refreshToken ?? current.refreshToken,
            accessExpiresAt: accessExpiresAt ?? _expiryOf(accessToken)));
  }

  Future<void> clear(String baseUrl) async {
    await _migrateLegacy(baseUrl);
    _cache[baseUrl] = StoredTokens.empty;
    if (isWeb) return;
    await _backend.delete(_key(baseUrl, 'access'));
    await _backend.delete(_key(baseUrl, 'refresh'));
    await _backend.delete(_key(baseUrl, 'accessExpiresAt'));
  }

  Future<void> _write(String baseUrl, StoredTokens tokens) async {
    _cache[baseUrl] = tokens;
    if (isWeb) return;
    await _backend.write(_key(baseUrl, 'access'), tokens.accessToken!);
    if (tokens.refreshToken == null) {
      await _backend.delete(_key(baseUrl, 'refresh'));
    } else {
      await _backend.write(_key(baseUrl, 'refresh'), tokens.refreshToken!);
    }
    if (tokens.accessExpiresAt == null) {
      await _backend.delete(_key(baseUrl, 'accessExpiresAt'));
    } else {
      await _backend.write(_key(baseUrl, 'accessExpiresAt'),
          tokens.accessExpiresAt!.toUtc().toIso8601String());
    }
  }

  /// Moves the token an older version left in shared preferences (which is
  /// localStorage on web) into the store and deletes it there, so it moves
  /// exactly once. It was stored without a server, so it goes to the first
  /// server asked about.
  Future<void> _migrateLegacy(String baseUrl) async {
    if (_cache.containsKey(baseUrl)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(legacyPrefsKey);
      if (legacy == null) return;
      await prefs.remove(legacyPrefsKey);
      if (legacy.isNotEmpty) {
        await _write(
            baseUrl,
            StoredTokens(
                accessToken: legacy, accessExpiresAt: _expiryOf(legacy)));
      }
    } catch (_) {
      // Preferences are unavailable; there is nothing to migrate.
    }
  }

  static DateTime? _expiryOf(String? jwt) {
    if (jwt == null || jwt.isEmpty) return null;
    try {
      return JwtDecoder.getExpirationDate(jwt).toUtc();
    } catch (_) {
      return null;
    }
  }
}
