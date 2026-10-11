import 'package:intl/intl.dart';

/// Display only: the original decimal string remains unchanged in storage.
String formatAmount(String? raw, String? currency, {String? locale}) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final text = raw.trim();
  final code = currency?.trim();
  if (!RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(text)) {
    return '${code == null || code.isEmpty ? '' : '$code '}$text';
  }
  final value = double.tryParse(text.replaceAll(',', '.'));
  if (value == null || !value.isFinite) return text;
  if (code == null || code.isEmpty) {
    return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2)
        .format(value);
  }
  return NumberFormat.currency(locale: locale, name: code, symbol: '$code ')
      .format(value);
}
