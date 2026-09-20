/// Document model mirroring the backend `DocumentDTO` (camelCase JSON).
///
/// File contents are not part of the DTO — they are fetched on demand via
/// `GET /api/documents/{id}/download`.
class Document {
  final int id;
  final String fileName;
  final String fileType; // MIME-ish, e.g. 'application/pdf', 'text/plain'
  final int fileSize; // bytes
  final int contractId;
  final DateTime uploadedAt;
  final int version;
  final String? createdBy;
  final String? modifiedBy;

  Document({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.contractId,
    required this.uploadedAt,
    required this.version,
    this.createdBy,
    this.modifiedBy,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: (json['id'] as num).toInt(),
      fileName: json['fileName'] as String,
      fileType: (json['fileType'] as String?) ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      contractId: (json['contractId'] as num).toInt(),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdBy: json['createdBy'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
    );
  }

  bool get isPdf =>
      fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  bool get isImage => fileType.startsWith('image/');

  String get fileSizeFormatted {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = fileSize.toDouble();
    var i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Extension guessed from the file name (without leading dot).
  String get extension {
    final idx = fileName.lastIndexOf('.');
    return (idx >= 0 && idx < fileName.length - 1)
        ? fileName.substring(idx + 1).toLowerCase()
        : '';
  }
}
