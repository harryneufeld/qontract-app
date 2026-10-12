import '../l10n/strings.dart';

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Strict calendar parsing rejects overflow dates (e.g. 31 February). German
/// entry accepts the display format and ISO for copy/paste compatibility.
DateTime? parseDateInput(String text, {String? language}) {
  final value = text.trim();
  final code = language ?? S.languageCode;
  final pattern =
      code == 'de' && value.contains('.') ? 'dd.MM.yyyy' : 'yyyy-MM-dd';
  if (!RegExp(pattern == 'dd.MM.yyyy'
          ? r'^\d{2}\.\d{2}\.\d{4}$'
          : r'^\d{4}-\d{2}-\d{2}$')
      .hasMatch(value)) {
    return null;
  }
  final parts =
      value.split(pattern == 'dd.MM.yyyy' ? '.' : '-').map(int.parse).toList();
  final year = parts[pattern == 'dd.MM.yyyy' ? 2 : 0];
  final month = parts[1];
  final day = parts[pattern == 'dd.MM.yyyy' ? 0 : 2];
  if (year < 1 || year > 9999) return null;
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// Preserve decimal precision and signs; never interpret grouping separators.
String? canonicalDecimal(String text) {
  final value = text.trim();
  return RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(value)
      ? value.replaceAll(',', '.')
      : null;
}

String decimalInput(String text) =>
    S.languageCode == 'de' && canonicalDecimal(text) != null
        ? text.replaceAll('.', ',')
        : text;
