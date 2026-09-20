import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document.dart';
import '../services/api_service.dart';

/// Per-contract document state backed by the backend Documents API.
class DocumentProvider with ChangeNotifier {
  final ApiService _api;

  int? _contractId;
  List<Document> _documents = [];
  bool _isLoading = false;
  bool _isBusy = false; // upload or download in flight
  String? _errorMessage;
  String? _notice;

  DocumentProvider({ApiService? api}) : _api = api ?? ApiService();

  int? get contractId => _contractId;
  List<Document> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get notice => _notice;

  void _clearTransient() {
    _errorMessage = null;
    _notice = null;
  }

  /// Loads the document list for [contractId] (no-op if unchanged).
  Future<void> loadFor(int contractId) async {
    if (_contractId == contractId && !_isLoading && _documents.isNotEmpty) {
      return;
    }
    _contractId = contractId;
    _isLoading = true;
    _clearTransient();
    notifyListeners();
    try {
      _documents = await _api.getDocuments(contractId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _documents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lets the user pick a file and uploads it to the current contract.
  Future<void> pickAndUpload() async {
    final contractId = _contractId;
    if (contractId == null || _isBusy) return;

    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a document to upload',
      type: FileType.any,
      withData: true, // in-memory bytes so web (no file paths) works too
    );
    final file = picked?.files.singleOrNull;
    if (file == null) return; // user cancelled

    final name = file.name;
    List<int>? bytes = file.bytes;
    if (bytes == null) {
      final path = file.path;
      if (path == null) return;
      bytes = await File(path).readAsBytes();
    }
    _isBusy = true;
    _clearTransient();
    notifyListeners();
    try {
      await _api.uploadDocument(
        contractId,
        fileName: name,
        fileType: _guessMimeType(name),
        fileData: bytes,
      );
      _documents = await _api.getDocuments(contractId);
      _notice = 'Uploaded "$name".';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Upload failed: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(Document doc) async {
    if (_contractId == null || _isBusy) return;
    _isBusy = true;
    _clearTransient();
    notifyListeners();
    try {
      await _api.deleteDocument(doc.id);
      _documents = await _api.getDocuments(_contractId!);
      _notice = 'Deleted "${doc.fileName}".';
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Downloads [doc] to a local file and opens it with the system handler.
  Future<bool> downloadAndOpen(Document doc) async {
    if (_isBusy) return false;
    _isBusy = true;
    _clearTransient();
    notifyListeners();
    try {
      final bytes = await _api.downloadDocument(doc.id);
      final dir = await getTemporaryDirectory();
      final target = File(p.join(dir.path, doc.fileName));
      await target.writeAsBytes(bytes);

      final ok = await launchUrl(
        Uri.file(target.path),
        mode: LaunchMode.externalApplication,
      );
      _notice = ok ? 'Downloaded "${doc.fileName}".' : null;
      return ok;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Download failed: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Rough MIME guess from the file extension — good enough for the
  /// download's Content-Type and the backend's storage metadata.
  static String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'html':
        return 'text/html';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
