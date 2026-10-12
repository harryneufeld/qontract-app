import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';
export 'generated/app_localizations.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => S.of(this);
}

/// UI reads the inherited locale. Non-widget presentation helpers and request
/// errors use the same resolved device preference, never translated API values.
class S {
  static String languageCode = 'en';
  static AppLocalizations get current =>
      lookupAppLocalizations(Locale(languageCode));
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? current;

  static String date(DateTime? value) {
    if (value == null) return '—';
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return languageCode == 'de' ? '$day.$month.$year' : '$year-$month-$day';
  }

  static String dateText(String? value) {
    if (value == null || value.isEmpty) return '—';
    final date = DateTime.tryParse(value);
    return date == null ? value : S.date(date);
  }

  static String role(String? value) => switch (value) {
        'Admin' => current.administrator,
        'TenantAdmin' => current.tenantAdministrator,
        'User' => current.memberRole,
        'Contractor' => current.contractorRole,
        _ => value ?? '—',
      };
}
