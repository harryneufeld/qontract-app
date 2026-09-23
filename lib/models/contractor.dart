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

  /// Returns a copy of this contractor with the given fields replaced.
  /// Convenience for providers that apply a server response (e.g. after an
  /// update or deactivation) on top of an existing instance.
  Contractor copyWith({
    int? id,
    String? name,
    ContractorType? type,
    String? contactInfo,
    int? tenantId,
    int? userId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? createdBy,
    String? modifiedBy,
  }) {
    return Contractor(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      contactInfo: contactInfo ?? this.contactInfo,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
    );
  }

  /// Display label used in lists and chips.
  String get typeLabel => type == ContractorType.company ? 'Company' : 'Individual';

  /// Hex-style colour reference for the type chip (not a Flutter Color).
  static String typeColorHex(ContractorType t) =>
      t == ContractorType.company ? '#1976D2' : '#388E3C';

  /// Payload for POST /contractors. `tenantId`/`userId` are owned by the
  /// server (set from the authenticated user) and must not be sent.
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'type': type.apiValue,
      'contactInfo': contactInfo,
    };
  }

  /// Payload for PUT /contractors/{id}. Only the editable fields are sent —
  /// active state is changed via the dedicated deactivate endpoint, not here.
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': type.apiValue,
      'contactInfo': contactInfo,
    };
  }
}

enum ContractorType {
  individual,
  company;

  /// The string value the backend expects/returns (PascalCase, matching
  /// its `ContractorType` enum serialized with `JsonStringEnumConverter`).
  String get apiValue => this == company ? 'Company' : 'Individual';

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
