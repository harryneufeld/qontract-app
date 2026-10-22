import 'package:intl/intl.dart';

/// Currencies offered in pickers; contracts may still carry any ISO code.
const offeredCurrencies = [
  'EUR',
  'USD',
  'GBP',
  'CHF',
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
  'CAD',
  'AUD',
  'JPY',
];

/// A sensible default from the device region; Euro when unknown.
String defaultCurrencyForCountry(String? countryCode) => switch (countryCode) {
      'CH' || 'LI' => 'CHF',
      'GB' => 'GBP',
      'US' => 'USD',
      'SE' => 'SEK',
      'NO' => 'NOK',
      'DK' => 'DKK',
      'PL' => 'PLN',
      'CZ' => 'CZK',
      'CA' => 'CAD',
      'AU' => 'AUD',
      'JP' => 'JPY',
      _ => 'EUR',
    };

/// Symbols that would otherwise be shared between currencies ($ for USD, CAD
/// and AUD; kr for SEK, NOK and DKK) are made unambiguous.
const _symbols = {
  'USD': r'$',
  'CAD': r'CA$',
  'AUD': r'A$',
  'SEK': 'SEK',
  'NOK': 'NOK',
  'DKK': 'DKK',
  'CHF': 'CHF',
};

/// Display symbol for an ISO code; unknown codes are shown as given.
String currencySymbol(String code) {
  final upper = code.trim().toUpperCase();
  final fixed = _symbols[upper];
  if (fixed != null) return fixed;
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(upper)) return code.trim();
  final symbol = NumberFormat.simpleCurrency(name: upper).currencySymbol;
  return symbol.isEmpty ? upper : symbol;
}

/// Picker label: the symbol with the ISO code, e.g. `€ · EUR`.
String currencyLabel(String code) {
  final symbol = currencySymbol(code);
  final upper = code.trim().toUpperCase();
  return symbol == upper ? upper : '$symbol · $upper';
}
