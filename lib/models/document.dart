import '../l10n/strings.dart';
import 'package:intl/intl.dart';

/// Document model mirroring the backend `DocumentDTO` (camelCase JSON).
///
/// File contents are not part of the DTO — they are fetched on demand via
/// `GET /api/documents/{id}/download`.
class Document {
  final int id;

  /// User-chosen readable title (app#5). Null/blank -> fall back to [fileName].
  final String? title;
  final String fileName;
  final String fileType; // MIME-ish, e.g. 'application/pdf', 'text/plain'
  final int fileSize; // bytes
  final int? contractId;
  final int? tenantId;
  final int? userId;
  final String scope;
  final String? description;
  final String? category;
  final DateTime? deletedAt;
  final DateTime? expiresAt;
  final bool retainedForInvoice;
  final List<int> additionalContractIds;
  List<int> get contractIds =>
      {if (contractId != null) contractId!, ...additionalContractIds}.toList();
  final DateTime uploadedAt;

  /// User-chosen document date (app#5). Null -> fall back to [uploadedAt].
  final DateTime? documentDate;
  final int version;
  final String? createdBy;
  final String? modifiedBy;

  Document({
    required this.id,
    this.title,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.contractId,
    this.tenantId,
    this.userId,
    this.scope = 'Tenant',
    this.description,
    this.category,
    this.deletedAt,
    this.expiresAt,
    this.retainedForInvoice = false,
    this.additionalContractIds = const [],
    required this.uploadedAt,
    this.documentDate,
    required this.version,
    this.createdBy,
    this.modifiedBy,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String?,
      fileName: json['fileName'] as String,
      fileType: (json['fileType'] as String?) ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      contractId: (json['contractId'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      scope: json['scope'] as String? ?? 'Tenant',
      description: json['description'] as String?,
      category: json['category'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      retainedForInvoice: json['retainedForInvoice'] == true,
      additionalContractIds: (json['contractIds'] as List? ?? [])
          .map((id) => (id as num).toInt())
          .toList(),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      documentDate: json['documentDate'] == null
          ? null
          : DateTime.parse(json['documentDate'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  /// What the UI shows as the document name: the user title when present,
  /// otherwise the raw file name.
  String get displayName {
    final t = title?.trim();
    return (t == null || t.isEmpty) ? fileName : t;
  }

  /// The business date shown in the list: user date when set,
  /// otherwise the upload time.
  DateTime get displayDate => documentDate ?? uploadedAt;

  bool get isPdf =>
      fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      fileType.trim().toLowerCase().startsWith('image/') ||
      const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'wbmp'}
          .contains(extension);

  String get fileSizeFormatted {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = fileSize.toDouble();
    var i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${NumberFormat('0.0', S.languageCode).format(size)} ${suffixes[i]}';
  }

  /// Extension guessed from the file name (without leading dot).
  String get extension {
    final idx = fileName.lastIndexOf('.');
    return (idx >= 0 && idx < fileName.length - 1)
        ? fileName.substring(idx + 1).toLowerCase()
        : '';
  }
}
