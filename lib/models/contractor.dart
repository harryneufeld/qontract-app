import '../l10n/strings.dart';

/// Contractor model mirroring the backend `ContractorDTO` (camelCase JSON).
///
/// `Type` is serialized as a string (`Individual` / `Company`).
///
/// Contact details are the structured `Email`/`Phone` fields the backend
/// returns (the old free-text `ContactInfo` was removed in backend #41). The
/// postal address is a separate `Address` record — see [Address] and the
/// contractor's address endpoints (#24).
class Contractor {
  final int id;
  final String name;
  final ContractorType type;
  final String? email;
  final String? phone;
  final String? website;
  final String? description;
  final String? notes;
  final int? tenantId;
  final int? userId;
  final bool isActive;

  /// Total number of the tenant's contracts referencing this contractor
  /// (app#33), computed server-side. 0 when the backend predates the
  /// field — callers then fall back to counting the loaded contracts.
  final int contractCount;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? createdBy;
  final String? modifiedBy;

  Contractor({
    required this.id,
    required this.name,
    required this.type,
    this.email,
    this.phone,
    this.website,
    this.description,
    this.notes,
    required this.tenantId,
    this.userId,
    required this.isActive,
    this.contractCount = 0,
    required this.createdAt,
    required this.modifiedAt,
    this.createdBy,
    this.modifiedBy,
  });

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type:
          ContractorType.fromString((json['type'] ?? 'Individual').toString()),
      email: _clean(json['email']),
      phone: _clean(json['phone']),
      website: json['website'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      tenantId: (json['tenantId'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
      contractCount: (json['contractCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  static String? _clean(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Returns a copy of this contractor with the given fields replaced.
  /// Convenience for providers that apply a server response (e.g. after an
  /// update or deactivation) on top of an existing instance.
  Contractor copyWith({
    int? id,
    String? name,
    ContractorType? type,
    String? email,
    String? phone,
    String? website,
    String? description,
    String? notes,
    int? tenantId,
    int? userId,
    bool? isActive,
    int? contractCount,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? createdBy,
    String? modifiedBy,
  }) {
    return Contractor(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      contractCount: contractCount ?? this.contractCount,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      createdBy: createdBy ?? this.createdBy,
      modifiedBy: modifiedBy ?? this.modifiedBy,
    );
  }

  /// Display label used in lists and chips.
  String get typeLabel =>
      type == ContractorType.company ? S.current.company : S.current.individual;

  /// Only HTTP/HTTPS addresses can be opened; other legacy text stays readable.
  Uri? get websiteUri {
    final uri = Uri.tryParse(website?.trim() ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'[\s%]').hasMatch(uri.host)) {
      return null;
    }
    return uri;
  }

  /// Hex-style colour reference for the type chip (not a Flutter Color).
  static String typeColorHex(ContractorType t) =>
      t == ContractorType.company ? '#1976D2' : '#388E3C';

  /// True when the user entered an email or a phone number.
  bool get hasContact =>
      (email?.isNotEmpty ?? false) || (phone?.isNotEmpty ?? false);

  /// "email · phone" for compact list subtitles. Blank parts are omitted and
  /// the result is empty when neither is set (callers hide the row then).
  String get contactLine {
    final parts = [email, phone]
        .map((s) => s?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }

  /// Payload for POST /contractors. `tenantId`/`userId` are owned by the
  /// server (set from the authenticated user) and must not be sent.
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'type': type.apiValue,
      'email': email,
      'phone': phone,
      if (website != null) 'website': website,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
    };
  }

  /// Payload for PUT /contractors/{id}. Only the editable fields are sent —
  /// active state is changed via the dedicated deactivate endpoint, not here.
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': type.apiValue,
      'email': email,
      'phone': phone,
      if (website != null) 'website': website,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
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
