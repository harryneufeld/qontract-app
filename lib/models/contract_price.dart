import '../l10n/strings.dart';

Map<String, String> get billingPeriods => <String, String>{
      'OneTime': S.current.oneTime,
      'Daily': S.current.daily,
      'Weekly': S.current.weekly,
      'Monthly': S.current.monthly,
      'Quarterly': S.current.quarterly,
      'Yearly': S.current.yearly,
    };

class ContractPrice {
  final String? id;
  final String? value;
  final String? currency;
  final String? billingPeriod;
  final String effectiveFrom;
  final String? effectiveUntil;
  final String? notes;
  String get intervalLabel {
    if (effectiveUntil == null) {
      return S.current.from(S.dateText(effectiveFrom));
    }
    if (effectiveUntil!.compareTo(effectiveFrom) <= 0) {
      return S.current.supersededOn(S.dateText(effectiveFrom));
    }
    final date = DateTime.tryParse(effectiveUntil!);
    if (date == null) return S.current.from(S.dateText(effectiveFrom));
    final last = DateTime.utc(date.year, date.month, date.day)
        .subtract(const Duration(days: 1));
    final through =
        '${last.year.toString().padLeft(4, '0')}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
    return S.current.through(S.dateText(effectiveFrom), S.dateText(through));
  }

  const ContractPrice(
      {this.id,
      this.value,
      this.currency,
      this.billingPeriod,
      required this.effectiveFrom,
      this.effectiveUntil,
      this.notes});
  factory ContractPrice.fromJson(Map<String, dynamic> json) => ContractPrice(
      id: json['id'] as String?,
      value: json['value'] as String?,
      currency: json['currency'] as String?,
      billingPeriod: json['billingPeriod'] as String?,
      effectiveFrom: json['effectiveFrom'] as String,
      effectiveUntil: json['effectiveUntil'] as String?,
      notes: json['notes'] as String?);
}
