import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/services/cost_summary.dart';

Contract contract(int id, String period, String value,
        {String currency = 'EUR',
        bool active = true,
        String status = 'Active',
        String? end,
        List<ContractPrice> prices = const []}) =>
    Contract(
        id: id,
        title: 'Contract $id',
        status: status,
        isActive: active,
        value: value,
        currency: currency,
        billingPeriod: period,
        startDate: '2026-01-01',
        endDate: end,
        priceHistory: prices,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026));

void main() {
  final today = DateTime.utc(2026, 10, 12);
  test('amounts stay in their own frequency and currency', () {
    final sums = computeBillingSums(now: today, contracts: [
      contract(1, 'Monthly', '10'),
      contract(2, 'Monthly', '20'),
      contract(3, 'Quarterly', '90'),
      contract(4, 'Yearly', '120'),
      contract(5, 'Monthly', '5', currency: 'USD'),
      contract(6, 'Daily', '2'),
      contract(7, 'Weekly', '7'),
      contract(8, 'OneTime', '50'),
      contract(9, 'Monthly', '999', active: false),
      contract(10, 'Monthly', '999', status: 'Draft'),
      contract(11, 'Monthly', '999', end: '2026-10-11'),
    ]);
    expect(sums['Monthly']!.byCurrency, {'EUR': 30, 'USD': 5});
    expect(sums['Monthly']!.contractCount, 3);
    expect(sums['Quarterly']!.byCurrency, {'EUR': 90});
    expect(sums['Yearly']!.byCurrency, {'EUR': 120});
    expect(sums['Daily']!.total, 2);
    expect(sums['Weekly']!.total, 7);
    expect(sums['OneTime']!.total, 50);
  });
  test('dated price changes contribute only the price effective today', () {
    final sums = computeBillingSums(now: today, contracts: [
      contract(1, 'Yearly', '999', prices: [
        const ContractPrice(
            value: '10',
            currency: 'EUR',
            billingPeriod: 'Monthly',
            effectiveFrom: '2026-01-01',
            effectiveUntil: '2026-10-12'),
        const ContractPrice(
            value: '60',
            currency: 'USD',
            billingPeriod: 'Quarterly',
            effectiveFrom: '2026-10-12',
            effectiveUntil: '2026-11-01'),
        const ContractPrice(
            value: '120',
            currency: 'EUR',
            billingPeriod: 'Yearly',
            effectiveFrom: '2026-11-01'),
      ]),
      contract(2, 'Monthly', '0', end: '2026-10-12'),
      contract(3, 'Monthly', 'bad'),
      contract(4, 'Unknown', '10'),
      contract(5, 'Monthly', '10', currency: ''),
    ]);
    expect(sums['Monthly']!.byCurrency, {'EUR': 0});
    expect(sums['Quarterly']!.byCurrency, {'USD': 60});
    expect(sums['Yearly']!.isEmpty, true);
    expect(sums['review']!.excludedCount, 3);
  });
}
