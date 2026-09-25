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

  AuthProvider({ApiService? api, StorageService? storage})
      : _api = api ?? ApiService(),
        _storage = storage ?? StorageService() {
    ApiService.onUnauthorized = _handleUnauthorized;
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _user != null;

  /// Restores the session from local storage, then validates the stored
  /// token against GET /auth/me. Falls back to the cached user when the
  /// server is unreachable (offline) — the token is still trusted locally.
  Future<bool> checkSession() async {
    final savedUser = await _storage.getUser();
    if (savedUser == null) return false;

    _user = savedUser;
    notifyListeners();

    try {
      final freshUser = await _api.me();
      _user = freshUser;
      await _storage.saveUser(freshUser);
      notifyListeners();
    } on ApiException catch (e) {
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
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _api.login(email, password);
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
    await _api.logout();
    await _clearSession();
  }

  /// Changes the password of the currently signed-in user (app#11).
  ///
  /// Returns true on success. On failure the [errorMessage] is set (e.g.
  /// "Current password is incorrect.") and false is returned; the session
  /// stays intact in every case.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _api.changePassword(currentPassword, newPassword);
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
    // Token rejected by the API: drop the local session so the user
    // lands back on the login screen.
    _user = null;
    _errorMessage = 'Your session expired. Please login again.';
    notifyListeners();
  }

  Future<void> _clearSession() async {
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
