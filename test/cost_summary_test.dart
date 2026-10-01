import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/services/cost_summary.dart';

Contract _c(
        {String? period = 'Monthly',
        String value = '100',
        String status = 'Active',
        String? start = '2026-01-01',
        String? end,
        String currency = 'EUR',
        List<ContractPrice> history = const []}) =>
    Contract(
        id: 1,
        title: 'Contract',
        status: status,
        value: value,
        currency: currency,
        billingPeriod: period,
        startDate: start,
        endDate: end,
        priceHistory: history,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026));

void main() {
  group('parseContractValue', () {
    test('parses plain and decimal values', () {
      expect(parseContractValue('1500'), 1500);
      expect(parseContractValue('1500.00'), 1500);
      expect(parseContractValue('12.5'), 12.5);
    });

    test('parses European and US separator styles', () {
      expect(parseContractValue('1.234,56'), 1234.56);
      expect(parseContractValue('1,234.56'), 1234.56);
      expect(parseContractValue('1,234'), 1234);
    });

    test('strips currency codes and whitespace', () {
      expect(parseContractValue(' 1500 EUR '), 1500);
      expect(parseContractValue('€ 1500'), 1500);
    });

    test('returns null for missing or unparseable values', () {
      expect(parseContractValue(null), isNull);
      expect(parseContractValue(''), isNull);
      expect(parseContractValue('   '), isNull);
      expect(parseContractValue('abc'), isNull);
    });
  });

  final now = DateTime(2026, 5, 10);
  double total(Contract c,
          {CostPeriod period = CostPeriod.month, DateTime? at}) =>
      computeCostSum(contracts: [c], period: period, now: at ?? now).total;

  test('each legacy period produces the correct full calendar-month estimate',
      () {
    expect(total(_c(period: 'OneTime', start: '2026-05-01')), 100);
    expect(total(_c(period: 'Daily')), 3100);
    expect(total(_c(period: 'Weekly')), closeTo(3100 / 7, .00001));
    expect(total(_c()), 100);
    expect(total(_c(period: 'Quarterly')), closeTo(100 / 3, .00001));
    expect(total(_c(period: 'Yearly')), closeTo(100 / 12, .00001));
  });
  test('open-ended monthly prices accumulate without lifetime-value proration',
      () {
    expect(total(_c(), period: CostPeriod.halfYear), 600);
    expect(total(_c(), period: CostPeriod.year), 1200);
    expect(total(_c(), period: CostPeriod.allActive), closeTo(1200, .00001));
  });
  test('one-time cost is charged only in the effective-date window', () {
    expect(total(_c(period: 'OneTime')), 0);
    expect(total(_c(period: 'OneTime'), period: CostPeriod.year), 100);
    expect(total(_c(period: 'OneTime'), period: CostPeriod.allActive), 0);
  });
  test(
      'inclusive contract end and partial month have exact calendar proportions',
      () {
    expect(total(_c(start: '2026-05-16', end: '2026-05-31')),
        closeTo(100 * 16 / 31, .00001));
    expect(total(_c(start: '2026-05-01', end: '2026-05-01')),
        closeTo(100 / 31, .00001));
    expect(total(_c(start: '2026-06-01')), 0);
    expect(total(_c(end: '2026-04-30')), 0);
  });
  test('leap February and daily estimates use calendar days', () {
    final leap = DateTime(2028, 2, 20);
    expect(total(_c(start: '2028-02-01'), at: leap), 100);
    expect(total(_c(start: '2028-02-01', period: 'Daily'), at: leap), 2900);
    expect(total(_c(start: '2028-02-29'), at: leap), closeTo(100 / 29, .00001));
  });
  test('dated prices and currencies are applied only to their own intervals',
      () {
    final c = _c(history: [
      const ContractPrice(
          value: '100',
          currency: 'EUR',
          billingPeriod: 'Monthly',
          effectiveFrom: '2026-01-01',
          effectiveUntil: '2026-07-01'),
      const ContractPrice(
          value: '999',
          currency: 'EUR',
          billingPeriod: 'Monthly',
          effectiveFrom: '2026-07-01',
          effectiveUntil: '2026-07-01'),
      const ContractPrice(
          value: '200',
          currency: 'USD',
          billingPeriod: 'Monthly',
          effectiveFrom: '2026-07-01'),
    ]);
    final summary =
        computeCostSum(contracts: [c], period: CostPeriod.year, now: now);
    expect(summary.byCurrency, {'EUR': 600.0, 'USD': 1200.0});
    expect(summary.contractCount, 1);
  });
  test('unknown periods preserve data but are visibly excluded from estimates',
      () {
    final c = _c(period: null, value: '1.234,56 EUR');
    final summary =
        computeCostSum(contracts: [c], period: CostPeriod.month, now: now);
    expect(summary.isEmpty, true);
    expect(summary.excludedCount, 1);
    expect(c.value, '1.234,56 EUR');
  });
  test(
      'non-active, missing, negative and non-finite amounts never inflate estimates',
      () {
    for (final c in [
      _c(status: 'Draft'),
      _c(status: 'Expired'),
      _c(value: ''),
      _c(value: '-5'),
      _c(value: 'NaN')
    ]) {
      expect(total(c), 0);
    }
  });
}
