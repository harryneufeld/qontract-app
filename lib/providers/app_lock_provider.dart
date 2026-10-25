import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/biometric_authenticator.dart';

/// Optional biometric lock (mobile only). The setting belongs to the device,
/// not to an account. The app locks on a cold start and when it returns after
/// more than [lockAfter] in the background.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppLockProvider(
      {BiometricAuthenticator? authenticator, DateTime Function()? clock})
      : _authenticator = authenticator ?? LocalAuthenticator(),
        _now = clock ?? DateTime.now;

  static const String storageKey = 'app.biometricLock';
  static const Duration lockAfter = Duration(minutes: 5);

  final BiometricAuthenticator _authenticator;
  final DateTime Function() _now;

  bool _enabled = false;
  bool _locked = false;
  bool _available = false;
  bool _authenticating = false;
  DateTime? _backgroundedAt;

  bool get enabled => _enabled;
  bool get locked => _enabled && _locked;

  /// Whether this device can use the lock; the toggle is hidden otherwise.
  bool get available => _available;

  /// Loads the setting and locks right away when it is on (call at app start).
  Future<void> init() async {
    _available = await _authenticator.isAvailable();
    if (!_available) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(storageKey) ?? false;
    _locked = _enabled;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= _now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && _now().difference(since) > lockAfter && !_locked) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  /// Turning it on proves the device can unlock first, so it never locks the
  /// user out. Returns false when the device cannot or the user declined.
  Future<bool> setEnabled(bool value) async {
    if (value == _enabled) return true;
    if (value) {
      if (!_available ||
          !await _authenticator.authenticate(S.current.appLockReason)) {
        return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, value);
    _enabled = value;
    _locked = false;
    notifyListeners();
    return true;
  }

  /// Prompts for the device unlock; true when the app is open afterwards.
  Future<bool> unlock() async {
    if (!locked) return true;
    if (_authenticating) return false;
    _authenticating = true;
    try {
      if (!await _authenticator.authenticate(S.current.appLockReason)) {
        return false;
      }
      _locked = false;
      notifyListeners();
      return true;
    } finally {
      _authenticating = false;
    }
  }

  /// Forgets the lock, for the "sign out instead" fallback.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    _enabled = false;
    _locked = false;
    notifyListeners();
  }
}
