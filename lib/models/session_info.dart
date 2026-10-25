/// One signed-in device as listed by GET /auth/sessions.
class SessionInfo {
  final String id;
  final String? deviceName;
  final String clientType;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool current;

  const SessionInfo({
    required this.id,
    this.deviceName,
    required this.clientType,
    required this.createdAt,
    required this.lastUsedAt,
    required this.current,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'] as String,
        deviceName: json['deviceName'] as String?,
        clientType: (json['clientType'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
        current: json['current'] == true,
      );
}
