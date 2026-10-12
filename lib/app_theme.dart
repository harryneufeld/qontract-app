import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Violet actions, warm paper surfaces and an ink-dark alternative.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF6D28D9);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
            surface: dark ? const Color(0xFF1C1925) : Colors.white,
            primary: dark ? const Color(0xFFC4B5FD) : seed,
            onPrimary: dark ? const Color(0xFF211238) : Colors.white);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Browsers cannot use the platform system fonts; the bundled Roboto keeps
      // the web build from fetching fonts from external servers.
      fontFamily: kIsWeb ? 'Roboto' : null,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF121019) : const Color(0xFFF6F4F9),
    );
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant));
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w700,
            letterSpacing: -.6),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarTheme(
          backgroundColor: base.scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: scheme.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant))),
      inputDecorationTheme: InputDecorationTheme(
          helperMaxLines: 4,
          errorMaxLines: 4,
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.all(16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 2))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.all(16),
          iconColor: scheme.primary,
          minVerticalPadding: 12),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, space: 32, thickness: 1),
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      chipTheme: base.chipTheme.copyWith(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(8)),
    );
  }
}
