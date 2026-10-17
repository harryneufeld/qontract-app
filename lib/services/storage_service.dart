import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Local persistence for the session (user snapshot only — the JWT lives
/// in [ApiService]).
class StorageService {
  static const String _userKey = 'user';

  Future<bool> isTwoFactorReminderDismissed(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('two_factor_reminder_dismissed_$userId') ?? false;
  }

  Future<void> setTwoFactorReminderDismissed(int userId, bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('two_factor_reminder_dismissed_$userId', dismissed);
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
