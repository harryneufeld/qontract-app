/// Contract model mirroring the backend `ContractDTO` (camelCase JSON,
/// status serialized as a string).
///
/// The counterparty of a contract is its linked `Contractor` (see
/// `contractorId`); the free-text `counterparty` field was removed on
/// the backend (harryneufeld/qontract-backend#17).
library;

import '../l10n/strings.dart';

import 'contract_price.dart';
import '../utils/amount_format.dart';
export 'contract_price.dart';

class Contract {
  final int id;
  final int? documentCount;
  final int? tenantId;
  final int? ownerUserId;
  final int? responsibleUserId;
  final String? responsibleUserName;
  final bool clearResponsibleUser;
  final bool isActive;
  final DateTime? deletedAt;
  final DateTime? retentionExpiresAt;
  bool get isPersonal => tenantId == null && ownerUserId != null;
  final String title;
  final String? description;
  final String? iban;
  final String? notes;
  final String? type;
  final bool clearType;
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
  final int? noticePeriodValue;
  final String? noticePeriodUnit; // Days, Weeks, Months
  final bool autoRenews;
  final int? renewalMonths;
  final bool clearNoticePeriod;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? createdBy;
  final String? modifiedBy;

  Contract({
    required this.id,
    this.documentCount,
    this.tenantId,
    this.ownerUserId,
    this.responsibleUserId,
    this.responsibleUserName,
    this.clearResponsibleUser = false,
    this.isActive = true,
    this.deletedAt,
    this.retentionExpiresAt,
    required this.title,
    this.description,
    this.iban,
    this.notes,
    this.type,
    this.clearType = false,
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
    this.noticePeriodValue,
    this.noticePeriodUnit,
    this.autoRenews = false,
    this.renewalMonths,
    this.clearNoticePeriod = false,
    required this.createdAt,
    required this.modifiedAt,
    this.createdBy,
    this.modifiedBy,
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: (json['id'] as num).toInt(),
      documentCount: (json['documentCount'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      ownerUserId: (json['ownerUserId'] as num?)?.toInt(),
      responsibleUserId: (json['responsibleUserId'] as num?)?.toInt(),
      responsibleUserName: json['responsibleUserName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      retentionExpiresAt:
          DateTime.tryParse(json['retentionExpiresAt'] as String? ?? ''),
      title: json['title'] as String,
      description: json['description'] as String?,
      iban: json['iban'] as String?,
      notes: json['notes'] as String?,
      type: json['type'] as String?,
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
      noticePeriodValue: (json['noticePeriodValue'] as num?)?.toInt(),
      noticePeriodUnit: json['noticePeriodUnit'] as String?,
      autoRenews: json['autoRenews'] as bool? ?? false,
      renewalMonths: (json['renewalMonths'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  Contract withDocumentCount(int count) => Contract(
      id: id,
      tenantId: tenantId,
      ownerUserId: ownerUserId,
      responsibleUserId: responsibleUserId,
      responsibleUserName: responsibleUserName,
      clearResponsibleUser: clearResponsibleUser,
      isActive: isActive,
      deletedAt: deletedAt,
      retentionExpiresAt: retentionExpiresAt,
      documentCount: count,
      title: title,
      description: description,
      iban: iban,
      notes: notes,
      type: type,
      clearType: clearType,
      status: status,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      value: value,
      billingPeriod: billingPeriod,
      priceHistory: priceHistory,
      priceEffectiveFrom: priceEffectiveFrom,
      priceNotes: priceNotes,
      contractorId: contractorId,
      contractNumber: contractNumber,
      minimumContractDate: minimumContractDate,
      noticePeriodValue: noticePeriodValue,
      noticePeriodUnit: noticePeriodUnit,
      autoRenews: autoRenews,
      renewalMonths: renewalMonths,
      clearNoticePeriod: clearNoticePeriod,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      createdBy: createdBy,
      modifiedBy: modifiedBy);

  /// Payload for POST /contracts and PUT /contracts/{id}.
  Map<String, dynamic> toJson() {
    return {
      if (responsibleUserId != null) 'responsibleUserId': responsibleUserId,
      if (clearResponsibleUser) 'clearResponsibleUser': true,
      'isActive': isActive,
      'title': title,
      'description': description,
      if (iban != null) 'iban': iban,
      if (notes != null) 'notes': notes,
      if (type != null) 'type': type,
      if (clearType) 'clearType': true,
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
      if (noticePeriodValue != null) ...{
        'noticePeriodValue': noticePeriodValue,
        'noticePeriodUnit': noticePeriodUnit ?? 'Days',
      },
      if (clearNoticePeriod) 'clearNoticePeriod': true,
      'autoRenews': autoRenews,
      if (autoRenews && renewalMonths != null) 'renewalMonths': renewalMonths,
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

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Display value with the currency prefix, when known.
  String get formattedValue => formatAmount(value, currency);

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

/// Business categories from the legacy system, independent of workflow status.
Map<String, String> get contractTypes => <String, String>{
      'None': S.current.none,
      'Insurance': S.current.insurance,
      'Loan': S.current.loan,
      'Subscription': S.current.subscription,
      'Other': S.current.other,
    };
