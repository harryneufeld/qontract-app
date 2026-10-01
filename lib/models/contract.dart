/// Contract model mirroring the backend `ContractDTO` (camelCase JSON,
/// status serialized as a string).
///
/// The counterparty of a contract is its linked `Contractor` (see
/// `contractorId`); the free-text `counterparty` field was removed on
/// the backend (harryneufeld/qontract-backend#17).
library;

import 'contract_price.dart';
export 'contract_price.dart';

class Contract {
  final int id;
  final String title;
  final String? description;
  final String status; // Draft, Active, Expired, Terminated
  final String? startDate; // 'yyyy-MM-dd' as stored by the backend
  final String? endDate;
  final String? currency;
  final String? value; // free-form string on the backend ("1500", "1500.00")
  final String? billingPeriod;
  final List<ContractPrice> priceHistory;
  final String? priceEffectiveFrom;
  final String? priceNotes;
  final int? contractorId;
  final String? contractNumber; // optional, e.g. "CNT-2026-0042"
  final String?
      minimumContractDate; // 'yyyy-MM-dd' ISO date, earliest date the contract can end
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? createdBy;
  final String? modifiedBy;

  Contract({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
    this.currency,
    this.value,
    this.billingPeriod,
    this.priceHistory = const [],
    this.priceEffectiveFrom,
    this.priceNotes,
    this.contractorId,
    this.contractNumber,
    this.minimumContractDate,
    required this.createdAt,
    required this.modifiedAt,
    this.createdBy,
    this.modifiedBy,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: (json['status'] ?? 'Draft').toString(),
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      currency: json['currency'] as String?,
      value: json['value'] as String?,
      billingPeriod: json['billingPeriod'] as String?,
      priceHistory: (json['priceHistory'] as List? ?? [])
          .map((p) =>
              ContractPrice.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      contractorId: (json['contractorId'] as num?)?.toInt(),
      contractNumber: json['contractNumber'] as String?,
      minimumContractDate: json['minimumContractDate'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  /// Payload for POST /contracts and PUT /contracts/{id}.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'currency': currency,
      'value': value,
      if (billingPeriod != null) 'billingPeriod': billingPeriod,
      if (priceEffectiveFrom != null) 'priceEffectiveFrom': priceEffectiveFrom,
      if (priceNotes != null) 'priceNotes': priceNotes,
      'contractorId': contractorId,
      'contractNumber': contractNumber,
      'minimumContractDate': minimumContractDate,
    };
  }

  bool get isExpired {
    final end = _parseDate(endDate);
    return end != null && end.isBefore(_today);
  }

  bool get isExpiringSoon {
    final end = _parseDate(endDate);
    if (end == null) return false;
    final diff = end.difference(_today);
    return diff.inDays >= 0 && diff.inDays <= 30;
  }

  /// Parsed [minimumContractDate] (earliest date the contract can end),
  /// or null when unset/unparseable.
  DateTime? get minimumContractDateTime => _parseDate(minimumContractDate);

  /// Calendar days until the minimum contract date (negative when
  /// already past), or null when the contract has no minimum contract
  /// date. Uses date-only comparison so "90 days from today" is
  /// deterministic regardless of the current time of day.
  int? get daysToMinimumContractDate {
    final min = minimumContractDateTime;
    if (min == null) return null;
    final today = _today;
    return DateTime(min.year, min.month, min.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  /// True when the minimum contract date falls within the next [days]
  /// days (already passed counts as approaching). Null/missing dates
  /// are ignored.
  bool reachesMinimumContractDateIn({int days = 90}) {
    final remaining = daysToMinimumContractDate;
    return remaining != null && remaining <= days;
  }

  static DateTime get _today => DateTime.now();

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Display value with the currency prefix, when known.
  String get formattedValue {
    final value = this.value;
    final currency = this.currency;
    if (value == null || value.isEmpty) return '—';
    final prefix = (currency == null || currency.isEmpty) ? '' : '$currency ';
    return '$prefix$value';
  }

  /// Fallback text for list tiles: the description, when present.
  /// (The counterparty name is resolved separately from the linked
  /// contractor, since it is no longer part of the contract payload.)
  String? get subtitle =>
      (description == null || description!.isEmpty) ? null : description;
}

/// Status constants (mirror the backend `ContractStatus` enum).
class ContractStatus {
  static const String draft = 'Draft';
  static const String active = 'Active';
  static const String expired = 'Expired';
  static const String terminated = 'Terminated';

  static const List<String> values = [draft, active, expired, terminated];
}
