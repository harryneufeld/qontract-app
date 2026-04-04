class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime? createdAt;
  final String? role;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.createdAt,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt?.toIso8601String(),
      'role': role,
    };
  }
}
