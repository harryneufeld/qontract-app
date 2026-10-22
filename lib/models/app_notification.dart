/// Recommendation / reminder from the backend rule engine (`NotificationDTO`).
///
/// The server stores only the [kind] and its [params]; the app words the
/// text (see `notification_text.dart`).
library;

class NotificationKind {
  static const String noticeDeadline = 'noticeDeadline';
  static const String endDate = 'endDate';
  static const String minimumTerm = 'minimumTerm';
  static const String priceIncrease = 'priceIncrease';
  static const String insuranceReview = 'insuranceReview';
  static const String missingData = 'missingData';
  static const String adminWithout2fa = 'adminWithout2fa';

  static const List<String> values = [
    noticeDeadline,
    endDate,
    minimumTerm,
    priceIncrease,
    insuranceReview,
    missingData,
    adminWithout2fa,
  ];
}

class AppNotification {
  final String id;
  final String kind;
  final String severity; // Info, Warning, Urgent
  final int? contractId;
  final String? contractTitle;
  final String? dueOn; // 'yyyy-MM-dd'
  final Map<String, dynamic> params;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.kind,
    this.severity = 'Info',
    this.contractId,
    this.contractTitle,
    this.dueOn,
    this.params = const {},
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String,
        severity: (json['severity'] ?? 'Info').toString(),
        contractId: (json['contractId'] as num?)?.toInt(),
        contractTitle: json['contractTitle'] as String?,
        dueOn: json['dueOn'] as String?,
        params: Map<String, dynamic>.from(json['params'] as Map? ?? const {}),
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
      );

  AppNotification asRead() => AppNotification(
      id: id,
      kind: kind,
      severity: severity,
      contractId: contractId,
      contractTitle: contractTitle,
      dueOn: dueOn,
      params: params,
      createdAt: createdAt,
      readAt: readAt ?? DateTime.now());
}

class NotificationPreferences {
  final String digest; // Off, Daily, Weekly
  final Set<String> mutedKinds;

  const NotificationPreferences(
      {this.digest = 'Off', this.mutedKinds = const {}});

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        digest: (json['digest'] ?? 'Off').toString(),
        mutedKinds: ((json['mutedKinds'] as List?) ?? const [])
            .map((k) => k.toString())
            .toSet(),
      );

  Map<String, dynamic> toJson() =>
      {'digest': digest, 'mutedKinds': mutedKinds.toList()};
}
