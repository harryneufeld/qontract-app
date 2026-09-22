/// Contractor model mirroring the backend `ContractorDTO` (camelCase JSON).
///
/// `Type` is serialized as a string (`Individual` / `Company`).
class Contractor {
  final int id;
  final String name;
  final ContractorType type;
  final String? contactInfo;
  final int tenantId;
  final int? userId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? createdBy;
  final String? modifiedBy;

  Contractor({
    required this.id,
    required this.name,
    required this.type,
    this.contactInfo,
    required this.tenantId,
    this.userId,
    required this.isActive,
    required this.createdAt,
    required this.modifiedAt,
    this.createdBy,
    this.modifiedBy,
  });

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: ContractorType.fromString((json['type'] ?? 'Individual').toString()),
      contactInfo: json['contactInfo'] as String?,
      tenantId: (json['tenantId'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  /// Display label used in lists and chips.
  String get typeLabel => type == ContractorType.company ? 'Company' : 'Individual';

  /// Hex-style colour reference for the type chip (not a Flutter Color).
  static String typeColorHex(ContractorType t) =>
      t == ContractorType.company ? '#1976D2' : '#388E3C';
}

enum ContractorType {
  individual,
  company;

  static ContractorType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'company':
        return company;
      case 'individual':
      default:
        return individual;
    }
  }
}
