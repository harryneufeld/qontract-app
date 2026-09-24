import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/services/cost_summary.dart';

Contract _c(
  int id, {
  String status = 'Active',
  String? value,
  String? currency,
  String? startDate,
  String? endDate,
  DateTime? createdAt,
}) =>
    Contract(
      id: id,
      title: 'C$id',
      status: status,
      value: value,
      currency: currency,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt ?? DateTime(2026, 5, 10),
      modifiedAt: DateTime(2026, 5, 10),
    );

void main() {
  // Reference "today": May 10, 2026 (H1, month 5, year 2026).
  final now = DateTime(2026, 5, 10);

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

  group('computeCostSum', () {
    test('allActive sums full values of active contracts only', () {
      final summary = computeCostSum(
        contracts: [
          _c(1, value: '1000', currency: 'EUR'),
          _c(2, value: '500'), // no currency
          _c(3, status: 'Draft', value: '999', currency: 'EUR'),
          _c(4, status: 'Expired', value: '999', currency: 'EUR'),
          _c(5, status: 'Terminated', value: '999'),
          _c(6, value: 'not-a-number'),
        ],
        period: CostPeriod.allActive,
        now: now,
      );
      expect(summary.byCurrency, {'EUR': 1000.0, '': 500.0});
      expect(summary.contractCount, 2);
      expect(summary.isEmpty, isFalse);
    });

    test('month: full value when fully inside the month', () {
      final summary = computeCostSum(
        contracts: [_c(1, value: '3100', startDate: '2026-05-01', endDate: '2026-05-31')],
        period: CostPeriod.month,
        now: now,
      );
      expect(summary.byCurrency['EUR'] ?? summary.byCurrency[''], 3100);
      expect(summary.contractCount, 1);
    });

    test('month: prorated for windows crossing the month boundary', () {
      // Apr 1 .. May 31 = 61 days; 31 of them inside May.
      final summary = computeCostSum(
        contracts: [_c(1, value: '6100', startDate: '2026-04-01', endDate: '2026-05-31')],
        period: CostPeriod.month,
        now: now,
      );
      expect(summary.total, closeTo(3100, 0.001));
    });

    test('month: contracts without overlap are not counted', () {
      final summary = computeCostSum(
        contracts: [
          _c(1, value: '100', startDate: '2026-01-01', endDate: '2026-01-31'),
          _c(2, value: '100', startDate: '2026-06-01', endDate: '2026-06-30'),
        ],
        period: CostPeriod.month,
        now: now,
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.contractCount, 0);
    });

    test('open-ended contract accrues value from start until today', () {
      // May 1 .. today (May 10) = 10 of 10 days in the window → full value.
      final openEnded = computeCostSum(
        contracts: [_c(1, value: '31', startDate: '2026-05-01')],
        period: CostPeriod.month,
        now: now,
      );
      expect(openEnded.total, closeTo(31, 0.001));

      // Future start: not in force yet inside May.
      final future = computeCostSum(
        contracts: [_c(2, value: '31', startDate: '2026-06-01')],
        period: CostPeriod.month,
        now: now,
      );
      expect(future.isEmpty, isTrue);
    });

    test('halfYear uses Jan-Jun / Jul-Dec windows', () {
      final h1 = computeCostSum(
        contracts: [
          _c(1, value: '9000', startDate: '2026-01-01', endDate: '2026-03-31'),
          _c(2, value: '10300', startDate: '2026-03-20', endDate: '2026-06-30'),
          // Dec 15 .. Jan 15 = 32 days total, 15 inside H1.
          _c(3, value: '3200', startDate: '2025-12-15', endDate: '2026-01-15'),
          // Fully outside H1.
          _c(4, value: '500', startDate: '2026-08-01', endDate: '2026-09-30'),
        ],
        period: CostPeriod.halfYear,
        now: now,
      );
      expect(h1.total, closeTo(9000 + 10300 + 1500, 0.01));
      expect(h1.contractCount, 3);
    });

    test('halfYear switches to the second half in July', () {
      final h2 = computeCostSum(
        contracts: [
          _c(1, value: '18600', startDate: '2026-07-01', endDate: '2026-12-31'),
          _c(2, value: '100', startDate: '2026-01-01', endDate: '2026-06-30'),
        ],
        period: CostPeriod.halfYear,
        now: DateTime(2026, 9, 1),
      );
      expect(h2.byCurrency.length, 1);
      expect(h2.total, closeTo(18600, 0.01));
      expect(h2.contractCount, 1);
    });

    test('year: full-year contract counted in full', () {
      final year = computeCostSum(
        contracts: [
          _c(1, value: '36500', startDate: '2026-01-01', endDate: '2026-12-31'),
        ],
        period: CostPeriod.year,
        now: now,
      );
      expect(year.total, closeTo(36500, 0.01));
    });

    test('groups sums per currency', () {
      final summary = computeCostSum(
        contracts: [
          _c(1, value: '1000', currency: 'eur', startDate: '2026-05-01', endDate: '2026-05-31'),
          _c(2, value: '2000', currency: 'USD', startDate: '2026-05-01', endDate: '2026-05-31'),
          _c(3, value: '500', startDate: '2026-05-01', endDate: '2026-05-31'),
        ],
        period: CostPeriod.month,
        now: now,
      );
      expect(summary.byCurrency.keys.toSet(), {'EUR', 'USD', ''});
      expect(summary.byCurrency['EUR'], 1000);
      expect(summary.byCurrency['USD'], 2000);
      expect(summary.byCurrency[''], 500);
      expect(summary.contractCount, 3);
    });

    test('empty contract list yields an empty summary', () {
      final summary = computeCostSum(
        contracts: [],
        period: CostPeriod.month,
        now: now,
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.contractCount, 0);
    });
  });
}
