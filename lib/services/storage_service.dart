import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../config/api_config.dart';

/// Local persistence for the session (user snapshot only — the JWT lives
/// in [ApiService]).
class StorageService {
  static const String _userKey = 'user';

  /// User IDs are local to a backend, so neither ID nor server alone is enough.
  /// Legacy ID-only keys are deliberately ignored: their server is unknown.
  String _reminderKey(String serverUrl, int userId) {
    final server = Uri.parse(normalizeApiBaseUrl(serverUrl)).normalizePath();
    final scope =
        base64Url.encode(utf8.encode(jsonEncode([server.toString(), userId])));
    return 'two_factor_reminder_dismissed_v2_$scope';
  }

  Future<bool> isTwoFactorReminderDismissed(
      String serverUrl, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderKey(serverUrl, userId)) ?? false;
  }

  Future<void> setTwoFactorReminderDismissed(
      String serverUrl, int userId, bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderKey(serverUrl, userId), dismissed);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
