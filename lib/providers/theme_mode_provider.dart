import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's light/dark/system theme choice (issue #22).
///
/// Device-level preference (not tenant-scoped), stored under [storageKey]
/// in SharedPreferences. Falls back to [ThemeMode.system] when unset or
/// corrupted.
class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const String storageKey = 'app.themeMode';

  final SharedPreferences? _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get themeMode => _mode;

  /// Loads the stored preference (call once at app start).
  Future<void> init() async {
    final raw = (await _resolvePrefs())?.getString(storageKey);
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
    if (mode != _mode) {
      _mode = mode;
      // The UI is already subscribed (provider is created before the
      // first Consumer builds), so announce the restored value.
      notifyListeners();
    }
  }

  /// Applies [mode] and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await _resolvePrefs();
    if (prefs != null) {
      await prefs.setString(storageKey, mode.name);
    }
  }

  Future<SharedPreferences?> _resolvePrefs() async {
    if (_prefs != null) return _prefs;
    return SharedPreferences.getInstance();
  }
}
