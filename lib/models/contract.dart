import 'document.dart';

class Contract {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Document> documents;
  final String status; // draft, active, expired, cancelled
  final DateTime expiryDate;
  final double value;
  final String? currency;
  final String? contractId; // Legacy support

  Contract({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.documents,
    required this.status,
    required this.expiryDate,
    required this.value,
    this.currency = 'USD',
    this.contractId,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  
  bool get isExpiringSoon => expiryDate.difference(DateTime.now()).inDays <= 30;

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      documents: (json['documents'] as List<dynamic>?)
          ?.map((d) => Document.fromJson(d))
          .toList() ?? [],
      status: json['status'],
      expiryDate: DateTime.parse(json['expiryDate']),
      value: json['value'].toDouble(),
      currency: json['currency'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'status': status,
      'expiryDate': expiryDate.toIso8601String(),
      'value': value,
      'currency': currency,
    };
  }
}
