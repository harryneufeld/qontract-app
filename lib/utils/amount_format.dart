import 'package:intl/intl.dart';

import 'currency.dart';

/// Display only: the original decimal string remains unchanged in storage.
String formatAmount(String? raw, String? currency, {String? locale}) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final text = raw.trim();
  final code = currency?.trim();
  if (!RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(text)) {
    return '${code == null || code.isEmpty ? '' : '${currencySymbol(code)} '}$text';
  }
  final value = double.tryParse(text.replaceAll(',', '.'));
  if (value == null || !value.isFinite) return text;
  if (code == null || code.isEmpty) {
    return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2)
        .format(value);
  }
  final symbol = currencySymbol(code);
  final formatted =
      NumberFormat.currency(locale: locale, name: code, symbol: symbol)
          .format(value);
  // Lettered symbols (CHF, SEK) need a space where the pattern puts them first.
  final lettered = RegExp(r'[A-Za-z]$').hasMatch(symbol);
  return lettered &&
          RegExp('^-?${RegExp.escape(symbol)}\\d').hasMatch(formatted)
      ? formatted.replaceFirst(symbol, '$symbol\u00a0')
      : formatted;
}
