class Document {
  final String id;
  final String filename;
  final String type; // pdf, image, other
  final String url;
  final int size; // in bytes
  final DateTime uploadedAt;

  Document({
    required this.id,
    required this.filename,
    required this.type,
    required this.url,
    required this.size,
    required this.uploadedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      filename: json['filename'],
      type: json['type'],
      url: json['url'],
      size: json['size'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'type': type,
      'url': url,
      'size': size,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  String get fileSizeFormatted {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    double sizeInBytes = size.toDouble();
    int i = 0;
    while (sizeInBytes >= 1024 && i < suffixes.length - 1) {
      sizeInBytes /= 1024;
      i++;
    }
    return '${sizeInBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
