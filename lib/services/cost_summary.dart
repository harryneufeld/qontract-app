/// Calendar-based cost estimates from dated billed amounts. These are not invoice totals.
library;

import '../models/contract.dart';

enum CostPeriod { month, quarter, halfYear, year, allActive }

bool needsBillingReview(Contract contract) {
  if (contract.status != ContractStatus.active) return false;
  final prices = contract.priceHistory.isEmpty
      ? [
          ContractPrice(
              value: contract.value,
              billingPeriod: contract.billingPeriod,
              effectiveFrom: contract.startDate ?? '')
        ]
      : contract.priceHistory;
  return prices.any((price) {
    final value = parseContractValue(price.value);
    return value == null ||
        !value.isFinite ||
        value < 0 ||
        !billingPeriods.containsKey(price.billingPeriod) ||
        (contract.priceHistory.isNotEmpty &&
            (_date(price.effectiveFrom) == null ||
                (price.effectiveUntil != null &&
                    _date(price.effectiveUntil) == null)));
  });
}

bool hasUpcomingPriceChange(Contract contract, {DateTime? now}) {
  if (contract.status != ContractStatus.active) return false;
  final ref = now ?? DateTime.now();
  final today = DateTime.utc(ref.year, ref.month, ref.day);
  final until = today.add(const Duration(days: 30));
  return contract.priceHistory.any((p) {
    final date = _date(p.effectiveFrom);
    return date != null && date.isAfter(today) && !date.isAfter(until);
  });
}

class CostSummary {
  final Map<String, double> byCurrency;
  final int contractCount;
  final int excludedCount;
  const CostSummary(
      {required this.byCurrency,
      required this.contractCount,
      this.excludedCount = 0});
  double get total => byCurrency.values.fold(0.0, (a, b) => a + b);
  bool get isEmpty => byCurrency.isEmpty;
}

double? parseContractValue(String? value) {
  if (value == null) return null;
  var v = value.trim();
  if (v.isEmpty) return null;
  // Keep only digits, separators and a minus sign (strips currency
  // codes/symbols and whitespace).
  v = v.replaceAll(RegExp(r'[^\d,.\-]'), '');
  if (v.isEmpty) return null;
  final lastComma = v.lastIndexOf(',');
  final lastDot = v.lastIndexOf('.');
  if (lastDot > lastComma) {
    // US style ("1,234.56"): comma is a thousands separator.
    v = v.replaceAll(',', '');
  } else if (lastComma != -1) {
    // Comma is the decimal separator ("1.234,56" or "1,25"), except
    // when three digits follow it ("1,234" → 1234).
    if (v.length - lastComma - 1 <= 2) {
      v = v.replaceAll('.', '').replaceAll(',', '.');
    } else {
      v = v.replaceAll(',', '');
    }
  }
  return double.tryParse(v);
}

CostSummary computeCostSum(
    {required List<Contract> contracts,
    required CostPeriod period,
    DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime.utc(ref.year, ref.month, ref.day);
  late DateTime from;
  late DateTime until;
  switch (period) {
    case CostPeriod.month:
      from = DateTime.utc(ref.year, ref.month);
      until = DateTime.utc(ref.year, ref.month + 1);
    case CostPeriod.quarter:
      final month = ((ref.month - 1) ~/ 3) * 3 + 1;
      from = DateTime.utc(ref.year, month);
      until = DateTime.utc(ref.year, month + 3);
    case CostPeriod.halfYear:
      final month = ref.month <= 6 ? 1 : 7;
      from = DateTime.utc(ref.year, month);
      until = DateTime.utc(ref.year, month + 6);
    case CostPeriod.year:
      from = DateTime.utc(ref.year);
      until = DateTime.utc(ref.year + 1);
    case CostPeriod.allActive:
      from = today;
      until = DateTime.utc(ref.year + 1, ref.month, ref.day);
  }
  final totals = <String, double>{};
  var count = 0;
  var excluded = 0;
  for (final contract in contracts) {
    if (contract.status != ContractStatus.active) continue;
    final start = _date(contract.startDate) ??
        DateTime.utc(contract.createdAt.year, contract.createdAt.month,
            contract.createdAt.day);
    final end = _date(contract.endDate)?.add(const Duration(days: 1)) ?? until;
    final prices = contract.priceHistory.isNotEmpty
        ? contract.priceHistory
        : [
            ContractPrice(
                value: contract.value,
                currency: contract.currency,
                billingPeriod: contract.billingPeriod,
                effectiveFrom: _iso(start))
          ];
    var contributed = false;
    var incomplete = false;
    for (final price in prices) {
      final priceStart = _date(price.effectiveFrom);
      if (priceStart == null) {
        incomplete = true;
        continue;
      }
      final priceEnd = _date(price.effectiveUntil) ?? until;
      final overlapStart = _max(_max(start, from), priceStart);
      final overlapEnd = _min(_min(end, until), priceEnd);
      if (!overlapStart.isBefore(overlapEnd)) continue;
      if (price.value == null || price.value!.trim().isEmpty) continue;
      final value = parseContractValue(price.value);
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          !billingPeriods.containsKey(price.billingPeriod)) {
        incomplete = true;
        continue;
      }
      double share;
      switch (price.billingPeriod) {
        case 'OneTime':
          share = !priceStart.isBefore(overlapStart) &&
                  priceStart.isBefore(overlapEnd)
              ? value
              : 0;
        case 'Daily':
          share = value * overlapEnd.difference(overlapStart).inDays;
        case 'Weekly':
          share = value * overlapEnd.difference(overlapStart).inDays / 7;
        default:
          final monthly = value /
              (price.billingPeriod == 'Yearly'
                  ? 12
                  : price.billingPeriod == 'Quarterly'
                      ? 3
                      : 1);
          share = 0;
          var cursor = overlapStart;
          while (cursor.isBefore(overlapEnd)) {
            final nextMonth = DateTime.utc(cursor.year, cursor.month + 1);
            final stop = _min(nextMonth, overlapEnd);
            final daysInMonth = nextMonth
                .difference(DateTime.utc(cursor.year, cursor.month))
                .inDays;
            share += monthly * stop.difference(cursor).inDays / daysInMonth;
            cursor = stop;
          }
      }
      if (share != 0) {
        final currency = (price.currency ?? '').trim().toUpperCase();
        totals[currency] = (totals[currency] ?? 0) + share;
        contributed = true;
      }
    }
    if (contributed) count++;
    if (incomplete) excluded++;
  }
  return CostSummary(
      byCurrency: Map.unmodifiable(totals),
      contractCount: count,
      excludedCount: excluded);
}

DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime? _date(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  return parsed == null
      ? null
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}
