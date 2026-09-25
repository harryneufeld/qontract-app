import 'package:flutter/material.dart';

/// Visual treatment for a feedback toast (app#28).
///
/// Each [ToastStyle] maps to a Material 3 container colour plus a matching
/// on-colour for the icon and text, so the user can read the outcome at a
/// glance. Colours are resolved from the active [ColorScheme], so they stay
/// consistent across the light and dark themes and with the rest of the
/// app.
enum ToastStyle {
  success,
  error,
  info;

  IconData get icon => switch (this) {
        success => Icons.check_circle_rounded,
        error => Icons.error_rounded,
        info => Icons.info_outline_rounded,
      };

  /// Container (surface) colour, resolved against [context]'s theme.
  Color containerOf(BuildContext context) => switch (this) {
        success => Theme.of(context).colorScheme.secondaryContainer,
        error => Theme.of(context).colorScheme.errorContainer,
        info => Theme.of(context).colorScheme.primaryContainer,
      };

  /// Icon + text colour, resolved against [context]'s theme.
  Color onColorOf(BuildContext context) => switch (this) {
        success => Theme.of(context).colorScheme.onSecondaryContainer,
        error => Theme.of(context).colorScheme.onErrorContainer,
        info => Theme.of(context).colorScheme.onPrimaryContainer,
      };
}

/// Shows a lightweight, app-wide consistent feedback toast (app#28).
///
/// A thin wrapper around [ScaffoldMessengerState.showSnackBar] that gives
/// the whole app one Material 3 look: a rounded surface in the
/// [ToastStyle]'s container colour, a matching leading icon, and a short
/// message. Call it from any screen after a user action (save, delete,
/// upload, session expired, ...).
///
/// The snackbar is shown on the [ScaffoldMessenger] that owns the app (the
/// one installed by [MaterialApp]), so it stays visible even if the calling
/// screen is popped or replaced right after.
void showToast(
  BuildContext context,
  String message, {
  ToastStyle style = ToastStyle.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final iconColor = style.onColorOf(context);

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(style.icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: iconColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: style.containerOf(context),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
}
