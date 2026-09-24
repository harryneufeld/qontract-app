/// Pure cost summarisation for the dashboard "Costs" section (app#13):
/// sums the values of **active** contracts, attributed to calendar
/// periods (month, half year, year) or the full active portfolio.
///
/// A contract's cost is its [Contract.value] spread over the window it
/// is in force ([Contract.startDate] .. [Contract.endDate], falling
/// back to the creation date / today when missing). Contracts spanning
/// a period boundary are prorated by days, so a 12-month contract
/// contributes its value/12 to each month it is active.
///
/// Flutter-free on purpose: this is unit-tested without a widget tree.
library;

import '../models/contract.dart';

/// Granularity of a cost summary (app#13).
enum CostPeriod {
  /// The current calendar month.
  month,

  /// The current half year (Jan-Jun or Jul-Dec).
  halfYear,

  /// The current calendar year.
  year,

  /// All active contracts in full (no proration).
  allActive,
}

/// Result of [computeCostSum].
class CostSummary {
  /// Sum per currency; the key is the normalised
  /// [Contract.currency] (upper-cased, trimmed; `''` when unset).
  final Map<String, double> byCurrency;

  /// Number of active contracts that contributed to the sum
  /// (parseable value and, for bounded periods, overlap with the
  /// period window).
  final int contractCount;

  const CostSummary({required this.byCurrency, required this.contractCount});

  /// Total across all currencies. Only meaningful when the sum covers
  /// a single currency (mixing currencies is otherwise); provided for
  /// convenience.
  double get total => byCurrency.values.fold(0.0, (a, b) => a + b);

  bool get isEmpty => byCurrency.isEmpty;
}

class _Window {
  final DateTime start; // date-only, inclusive
  final DateTime end; // date-only, inclusive
  const _Window(this.start, this.end);
}

/// Calendar window (inclusive) for [period] at [now], or `null` for
/// [CostPeriod.allActive] (no window → full contract values).
_Window? _periodWindow(CostPeriod period, DateTime now) {
  final y = now.year;
  switch (period) {
    case CostPeriod.month:
      return _Window(
        DateTime(y, now.month, 1),
        DateTime(y, now.month + 1, 0),
      );
    case CostPeriod.halfYear:
      final startMonth = now.month <= 6 ? 1 : 7;
      final endMonth = now.month <= 6 ? 6 : 12;
      return _Window(
        DateTime(y, startMonth, 1),
        DateTime(y, endMonth + 1, 0),
      );
    case CostPeriod.year:
      return _Window(DateTime(y, 1, 1), DateTime(y, 12, 31));
    case CostPeriod.allActive:
      return null;
  }
}

/// Parses the free-form [Contract.value] (e.g. `"1500"`, `"1500.00"`,
/// `"1.234,56"`, `" 1,234.56"`, `"1500 EUR"`) into a double.
/// Returns `null` when the value is missing or unparseable.
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

/// Sums the cost of [contracts] for [period] (see file doc for the
/// proration rules). `now` is injectable for deterministic tests.
CostSummary computeCostSum({
  required List<Contract> contracts,
  required CostPeriod period,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final window = _periodWindow(period, ref);
  final today = DateTime(ref.year, ref.month, ref.day);

  final byCurrency = <String, double>{};
  var count = 0;

  for (final c in contracts) {
    if (c.status != ContractStatus.active) continue;
    final value = parseContractValue(c.value);
    if (value == null) continue;

    final share = window == null
        ? value
        : _proratedShare(c, window, today, value);
    if (share == null || share == 0) continue;

    final currency = _currencyKey(c.currency);
    byCurrency[currency] = (byCurrency[currency] ?? 0) + share;
    count++;
  }

  return CostSummary(
    byCurrency: Map<String, double>.unmodifiable(byCurrency),
    contractCount: count,
  );
}

/// Value fraction for [c] inside [w] (inclusive day overlap), or
/// `null` when the contract is not in force inside [w].
double? _proratedShare(
  Contract c,
  _Window w,
  DateTime today,
  double value,
) {
  final start = _date(c.startDate) ??
      DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day);
  final rawEnd = _date(c.endDate) ?? today;
  final end = rawEnd.isBefore(start) ? start : rawEnd;

  final overlapStart = start.isAfter(w.start) ? start : w.start;
  final overlapEnd = end.isBefore(w.end) ? end : w.end;
  if (overlapEnd.isBefore(overlapStart)) return null;

  final totalDays = end.difference(start).inDays + 1;
  final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
  return value * overlapDays / totalDays;
}

String _currencyKey(String? currency) =>
    (currency ?? '').trim().toUpperCase();

DateTime? _date(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } on FormatException {
    return null;
  }
}
