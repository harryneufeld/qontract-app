import '../l10n/strings.dart';
import 'document_text_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../providers/document_provider.dart';

class PendingDocument {
  final String id;
  final String name;
  const PendingDocument(this.id, this.name);
}

class DocumentText {
  final String text;
  final String? warning;
  final List<DocumentTextLine> lines;
  const DocumentText(this.text, {this.warning, this.lines = const []});
}

/// The native inbox retains shared files until explicitly saved or discarded.
/// OCR never sends file content to a remote recognition service.
class DocumentImportService {
  static const channel = MethodChannel('qontract/document_import');
  static const maxBytes = 20 * 1024 * 1024;
  static final _inboxListeners = <VoidCallback>{};

  static void addInboxListener(VoidCallback listener) {
    if (_inboxListeners.isEmpty) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'inboxChanged') {
          for (final callback in _inboxListeners.toList()) {
            callback();
          }
        }
      });
    }
    _inboxListeners.add(listener);
  }

  static void removeInboxListener(VoidCallback listener) {
    _inboxListeners.remove(listener);
    if (_inboxListeners.isEmpty) channel.setMethodCallHandler(null);
  }

  bool get supportsOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<List<PendingDocument>> pending() async {
    if (!supportsOcr) return [];
    final rows = await channel.invokeListMethod<dynamic>('pending') ?? [];
    return rows
        .map(
          (row) => PendingDocument(row['id'] as String, row['name'] as String),
        )
        .toList();
  }

  Future<PickedDocument> read(String id) async {
    final row = await channel.invokeMapMethod<String, dynamic>('read', {
      'id': id,
    });
    if (row == null) {
      throw StateError(S.current.importUnavailable);
    }
    return PickedDocument(
      name: row['name'] as String,
      bytes: row['bytes'] as Uint8List,
    );
  }

  Future<void> discard(String id) =>
      channel.invokeMethod<void>('discard', {'id': id});

  Future<DocumentText> recognize(PickedDocument file) async {
    if (file.bytes.isEmpty || file.bytes.length > maxBytes) {
      throw StateError(S.current.importSizeLimit);
    }
    if (!supportsOcr) {
      return DocumentText('', warning: S.current.importOcrMobileOnly);
    }
    final row = await channel.invokeMapMethod<String, dynamic>('recognize', {
      'name': file.name,
      'bytes': Uint8List.fromList(file.bytes),
    });
    return DocumentText(
      row?['text'] as String? ?? '',
      warning: row?['warning'] as String?,
      lines: [
        for (final line in (row?['lines'] as List? ?? []))
          if (line is Map &&
              line['text'] is String &&
              line['top'] is num &&
              line['left'] is num)
            DocumentTextLine(line['text'] as String,
                top: (line['top'] as num).toDouble(),
                left: (line['left'] as num).toDouble(),
                height: (line['height'] as num?)?.toDouble() ?? 0,
                isBold: line['isBold'] == true)
      ],
    );
  }
}
