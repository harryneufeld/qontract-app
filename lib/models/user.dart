/// User model mirroring the backend `AuthUserDTO` (camelCase JSON).
/// Never contains secrets — the backend omits password hashes here.
class User {
  final int id;
  final String name;
  final String email;
  final String role; // TenantAdmin, User, Contractor
  final int tenantId;
  bool get isPersonal => tenantId == 0;
  final DateTime createdAt;
  final String? defaultCurrency;
  final String? language;

  /// False until first-run setup (name, currency, language) is done or skipped.
  final bool onboardingCompleted;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.createdAt,
    this.defaultCurrency,
    this.language,
    this.onboardingCompleted = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] ?? 'User').toString(),
      tenantId: (json['tenantId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      defaultCurrency: json['defaultCurrency'] as String?,
      language: json['language'] as String?,
      // Older servers do not send the flag; their users never see setup.
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'tenantId': tenantId,
      'createdAt': createdAt.toIso8601String(),
      'defaultCurrency': defaultCurrency,
      'language': language,
      'onboardingCompleted': onboardingCompleted,
    };
  }
}
