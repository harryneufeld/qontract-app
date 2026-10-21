import '../l10n/strings.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Result of a signup: signed in directly, or waiting for the emailed link.
enum RegisterOutcome { signedIn, confirmationRequired, failed }

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

  bool _requiresTwoFactor = false;
  bool get requiresTwoFactor => _requiresTwoFactor;

  /// Set when the last login had the right password but an unconfirmed email.
  bool _emailNotConfirmed = false;
  bool get emailNotConfirmed => _emailNotConfirmed;

  /// Terms of use the signed-in account still has to accept, if any.
  TermsStatus? _pendingTerms;
  TermsStatus? get pendingTerms => isAuthenticated ? _pendingTerms : null;

  /// Unknown/offline status never blocks the app; the server stays authoritative.
  Future<void> refreshTermsStatus() async {
    final generation = _sessionGeneration;
    try {
      final status = await _api.termsStatus();
      if (generation != _sessionGeneration) return;
      _pendingTerms = status.needsAcceptance ? status : null;
      notifyListeners();
    } catch (_) {
      // Older servers have no terms endpoint.
    }
  }

  Future<bool> acceptPendingTerms() async {
    final pending = _pendingTerms;
    if (pending?.version == null) return true;
    try {
      final status = await _api.acceptTerms(pending!.version!);
      _pendingTerms = status.needsAcceptance ? status : null;
      notifyListeners();
      return _pendingTerms == null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // The terms may have changed meanwhile; show the current version.
      await refreshTermsStatus();
      return false;
    } catch (_) {
      _errorMessage = S.current.couldNotUpdateYourSessionPleaseTryAgain;
      return false;
    }
  }

  Future<bool> resendEmailConfirmation(String email) async {
    try {
      await _api.resendEmailConfirmation(email);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = S.current.unableToCompleteResetPleaseTryAgain;
      return false;
    }
  }

  bool get isAuthenticated => _user != null;

  bool _showTwoFactorReminder = false;
  int _reminderGeneration = 0;
  String? _reminderServerUrl;
  int? _reminderUserId;
  bool get showTwoFactorReminder =>
      isAuthenticated &&
      _showTwoFactorReminder &&
      _reminderServerUrl == _api.baseUrl &&
      _reminderUserId == _user?.id;

  /// Unknown/offline status never prompts users who may already have 2FA.
  Future<void> refreshTwoFactorReminder() async {
    final user = _user;
    final serverUrl = _api.baseUrl;
    final generation = _sessionGeneration;
    final reminderGeneration = ++_reminderGeneration;
    if (user == null) return;
    try {
      final dismissed =
          await _storage.isTwoFactorReminderDismissed(serverUrl, user.id);
      if (serverUrl != _api.baseUrl) return;
      final status = dismissed ? null : await _api.twoFactorStatus();
      if (generation != _sessionGeneration ||
          serverUrl != _api.baseUrl ||
          reminderGeneration != _reminderGeneration) {
        return;
      }
      _showTwoFactorReminder = !dismissed && status?['enabled'] == false;
      _reminderServerUrl = serverUrl;
      _reminderUserId = user.id;
      notifyListeners();
    } catch (_) {
      // This optional hint must not interrupt normal use when unavailable.
    }
  }

  Future<void> dismissTwoFactorReminder() async {
    _reminderGeneration++;
    final user = _user;
    final serverUrl = _api.baseUrl;
    if (user == null) return;
    _showTwoFactorReminder = false;
    notifyListeners();
    await _storage.setTwoFactorReminderDismissed(serverUrl, user.id, true);
  }

  Future<bool> _replaceSession(Future<AuthResult> Function() action,
      {bool freshLogin = false}) async {
    if (_isLoading) return false;
    final generation = ++_sessionGeneration;
    final serverUrl = _api.baseUrl;
    _errorMessage = null;
    _setLoading(true);
    try {
      final result = await action();
      if (generation != _sessionGeneration) return false;
      await _storage.saveUser(result.user);
      if (freshLogin) {
        await _storage.setTwoFactorReminderDismissed(
            serverUrl, result.user.id, false);
        _showTwoFactorReminder = false;
      }
      _user = result.user;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = S.current.couldNotUpdateYourSessionPleaseTryAgain;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<RegisterOutcome> register(Map<String, dynamic> fields) async {
    if (_isLoading) return RegisterOutcome.failed;
    var pending = false;
    final ok = await _replaceSession(() async {
      final result = await _api.register(fields);
      if (result == null) {
        pending = true;
        throw const _ConfirmationPending();
      }
      return result;
    }, freshLogin: true);
    if (pending) {
      _errorMessage = null;
      return RegisterOutcome.confirmationRequired;
    }
    return ok ? RegisterOutcome.signedIn : RegisterOutcome.failed;
  }
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

  Future<bool> login(String email, String password) {
    if (!_isLoading) {
      _requiresTwoFactor = false;
      _emailNotConfirmed = false;
    }
    return _login(() => _api.login(email, password));
  }

  Future<bool> loginWithTwoFactor(String email, String password, String code,
          {bool recovery = false}) =>
      _login(() =>
          _api.loginWithTwoFactor(email, password, code, recovery: recovery));

  void cancelTwoFactorLogin() {
    _sessionGeneration++;
    _requiresTwoFactor = false;
    _emailNotConfirmed = false;
    clearError();
  }

  Future<bool> _login(Future<AuthResult> Function() action) async {
    if (_isLoading) return false;
    final generation = ++_sessionGeneration;
    final serverUrl = _api.baseUrl;
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await action();
      if (generation != _sessionGeneration) return false;
      _requiresTwoFactor = false;
      _user = result.user;
      await _storage.saveUser(result.user);
      await _storage.setTwoFactorReminderDismissed(
          serverUrl, result.user.id, false);
      _showTwoFactorReminder = false;
      notifyListeners();
      return true;
    } on TwoFactorRequiredException {
      if (generation != _sessionGeneration) return false;
      _requiresTwoFactor = true;
      notifyListeners();
      return false;
    } on EmailNotConfirmedException {
      if (generation != _sessionGeneration) return false;
      _emailNotConfirmed = true;
      _errorMessage = S.current.confirmYourEmailBeforeSigningIn;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      if (generation != _sessionGeneration) return false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      if (generation != _sessionGeneration) return false;
      _errorMessage = S.current.loginFailed;
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

  /// Email reset revokes sessions server-side; clear the local copy as well.
  Future<void> clearRevokedSession() async {
    _sessionGeneration++;
    await _api.clearToken();
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
      _errorMessage = S.current.passwordChangeFailed;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _handleUnauthorized() {
    _showTwoFactorReminder = false;
    _sessionGeneration++;
    // Token rejected by the API: drop the local session so the user
    // lands back on the login screen.
    _user = null;
    _errorMessage = S.current.yourSessionExpiredPleaseLoginAgain;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _showTwoFactorReminder = false;
    _sessionGeneration++;
    _user = null;
    _requiresTwoFactor = false;
    _emailNotConfirmed = false;
    _pendingTerms = null;
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

/// Signup succeeded without a session; the account waits for email confirmation.
class _ConfirmationPending implements Exception {
  const _ConfirmationPending();
}
