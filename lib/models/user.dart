/// User model mirroring the backend `AuthUserDTO` (camelCase JSON).
/// Never contains secrets — the backend omits password hashes here.
class User {
  final int id;
  final String name;
  final String email;
  final String role; // TenantAdmin, User, Contractor
  final int tenantId;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] ?? 'User').toString(),
      tenantId: (json['tenantId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
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
    };
  }
}
