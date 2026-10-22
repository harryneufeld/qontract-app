void clearResetTokenFromUrl([String fragment = '#/reset-password']) {}

/// Emailed links are real paths (`/confirm-email?token=...`) so the OS can hand
/// them to the installed app; only the web build reads them from the address bar.
String? emailedLinkRoute() => null;
