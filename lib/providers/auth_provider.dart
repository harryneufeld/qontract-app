import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Session state: current user, loading, error. Backed by [ApiService]
/// (JWT in shared prefs) and [StorageService] (user snapshot).
class AuthProvider with ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  int _sessionGeneration = 0;

  AuthProvider({ApiService? api, StorageService? storage})
      : _api = api ?? ApiService(),
        _storage = storage ?? StorageService() {
    ApiService.onUnauthorized = _handleUnauthorized;
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _user != null;

  Future<bool> _replaceSession(Future<AuthResult> Function() action) async {
    if (_isLoading) return false;
    final generation = ++_sessionGeneration;
    _errorMessage = null;
    _setLoading(true);
    try {
      final result = await action();
      if (generation != _sessionGeneration) return false;
      await _storage.saveUser(result.user);
      _user = result.user;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Could not update your session. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(Map<String, dynamic> fields) =>
      _replaceSession(() => _api.register(fields));
  Future<bool> switchTenant(int tenantId) =>
      _replaceSession(() => _api.switchTenant(tenantId));
  Future<bool> redeemInvitation(String code) =>
      _replaceSession(() => _api.redeemInvitation(code));

  /// Restores the session from local storage, then validates the stored
  /// token against GET /auth/me. Falls back to the cached user when the
  /// server is unreachable (offline) — the token is still trusted locally.
  Future<bool> checkSession() async {
    final generation = _sessionGeneration;
    final savedUser = await _storage.getUser();
    if (generation != _sessionGeneration) return isAuthenticated;
    if (savedUser == null) return false;

    _user = savedUser;
    notifyListeners();

    try {
      final freshUser = await _api.me();
      if (generation != _sessionGeneration) return isAuthenticated;
      _user = freshUser;
      await _storage.saveUser(freshUser);
      notifyListeners();
    } on ApiException catch (e) {
      if (generation != _sessionGeneration) return isAuthenticated;
      if (e.statusCode == 401) {
        await _clearSession();
        return false;
      }
      // Network/server error: keep the cached user, let the UI retry.
      _user = savedUser;
    }
    return true;
  }

  Future<bool> login(String email, String password) async {
    final generation = ++_sessionGeneration;
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _api.login(email, password);
      if (generation != _sessionGeneration) return false;
      _user = result.user;
      await _storage.saveUser(result.user);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _sessionGeneration++;
    await _api.logout();
    await _clearSession();
  }

  /// Changes the password of the currently signed-in user (app#11).
  ///
  /// Returns true on success. On failure the [errorMessage] is set (e.g.
  /// "Current password is incorrect.") and false is returned; the session
  /// stays intact on failure. Success clears the revoked session.
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _api.changePassword(currentPassword, newPassword);
      _sessionGeneration++;
      await _api.clearToken();
      await _clearSession();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password change failed: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _handleUnauthorized() {
    _sessionGeneration++;
    // Token rejected by the API: drop the local session so the user
    // lands back on the login screen.
    _user = null;
    _errorMessage = 'Your session expired. Please login again.';
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _sessionGeneration++;
    _user = null;
    _errorMessage = null;
    await _storage.clearUser();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
