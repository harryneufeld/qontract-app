/// Contractor address mirroring the backend `AddressDTO` (camelCase JSON).
///
/// The backend stores addresses on a shared `Address` entity keyed by
/// `EntityType` + the owning entity id. Contractor addresses use
/// `EntityType.Contractor` and the owning contractor's id, so the client only
/// needs to send those two plus the street/city/zip/country (see #24).
class Address {
  final int id;
  final String? street;
  final String? city;
  final String? zip;
  final String? country;
  final int? contractorId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  const Address({
    this.id = 0,
    this.street,
    this.city,
    this.zip,
    this.country,
    this.contractorId,
    this.isActive = true,
    this.createdAt,
    this.modifiedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: (json['id'] as num).toInt(),
      street: json['street'] as String?,
      city: json['city'] as String?,
      zip: json['zip'] as String?,
      country: json['country'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  /// A copy of this address with the given fields replaced.
  Address copyWith({
    int? id,
    String? street,
    String? city,
    String? zip,
    String? country,
    int? contractorId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Address(
      id: id ?? this.id,
      street: street ?? this.street,
      city: city ?? this.city,
      zip: zip ?? this.zip,
      country: country ?? this.country,
      contractorId: contractorId ?? this.contractorId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// True when the user entered any part of the address.
  bool get hasContent =>
      _has(street) || _has(city) || _has(zip) || _has(country);

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  static String? _clean(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// Payload for POST /addresses and PUT /addresses/{id}. The backend owns
  /// the tenant id and audit fields, so they are never sent.
  Map<String, dynamic> toCreateJson() => {
        'entityType': 'Contractor',
        'contractorId': contractorId,
        'street': _clean(street),
        'city': _clean(city),
        'zip': _clean(zip),
        'country': _clean(country),
      };

  Map<String, dynamic> toUpdateJson() => toCreateJson();

  /// Single-line display, e.g. "Musterstraße 5, 10115 Berlin, Germany".
  /// Blank parts are omitted; an all-empty address renders as an empty
  /// string so callers can hide the row cleanly.
  String get display {
    final street = _clean(this.street) ?? '';
    final zipCity = [zip, city].where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');
    final first = [street, zipCity].where((s) => s.isNotEmpty).join(', ');
    final country = _clean(this.country) ?? '';
    if (first.isEmpty) return country;
    if (country.isEmpty) return first;
    return '$first, $country';
  }
}
