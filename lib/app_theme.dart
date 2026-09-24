import 'package:flutter/material.dart';

/// App-wide themes (issue #22): Material 3, seeded from the brand blue,
/// with a proper light and dark variant so [MaterialApp.themeMode] can
/// switch between them.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF1976D2);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );
  }
}
