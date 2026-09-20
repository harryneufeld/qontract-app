/// Contract model mirroring the backend `ContractDTO` (camelCase JSON,
/// status serialized as a string).
class Contract {
  final int id;
  final String title;
  final String? description;
  final String status; // Draft, Active, Expired, Terminated
  final String? startDate; // 'yyyy-MM-dd' as stored by the backend
  final String? endDate;
  final String? counterparty;
  final String? currency;
  final String? value; // free-form string on the backend ("1500", "1500.00")
  final int? contractorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? modifiedBy;

  Contract({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
    this.counterparty,
    this.currency,
    this.value,
    this.contractorId,
    required this.createdAt,
    required this.updatedAt,
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
      counterparty: json['counterparty'] as String?,
      currency: json['currency'] as String?,
      value: json['value'] as String?,
      contractorId: (json['contractorId'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
      'counterparty': counterparty,
      'currency': currency,
      'value': value,
      'contractorId': contractorId,
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

  String? get subtitle =>
      (description == null || description!.isEmpty)
          ? counterparty
          : description;
}

/// Status constants (mirror the backend `ContractStatus` enum).
class ContractStatus {
  static const String draft = 'Draft';
  static const String active = 'Active';
  static const String expired = 'Expired';
  static const String terminated = 'Terminated';

  static const List<String> values = [draft, active, expired, terminated];
}
