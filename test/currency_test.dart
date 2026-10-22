import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/utils/amount_format.dart';
import 'package:qontract_app/utils/currency.dart';

void main() {
  test('symbols are unambiguous and fall back to the code', () {
    expect(currencySymbol('EUR'), '€');
    expect(currencySymbol('usd'), r'$');
    expect(currencySymbol('CAD'), r'CA$');
    expect(currencySymbol('AUD'), r'A$');
    expect(currencySymbol('SEK'), 'SEK');
    expect(currencySymbol('XYZ'), 'XYZ');
    expect(currencyLabel('EUR'), '€ · EUR');
    expect(currencyLabel('CHF'), 'CHF');
  });

  test('amounts use the symbol with locale-aware placement', () {
    expect(formatAmount('1234.5', 'EUR', locale: 'de'), '1.234,50 €');
    expect(formatAmount('1234.5', 'EUR', locale: 'en'), '€1,234.50');
    expect(formatAmount('12', 'CHF', locale: 'en'), 'CHF 12.00');
    expect(formatAmount('12', null, locale: 'en'), '12.00');
  });
}
