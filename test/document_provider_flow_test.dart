import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Configurable [ApiService] with an in-memory document store.
class _FakeApi extends ApiService {
  _FakeApi(this._docs) : super(baseUrl: 'http://localhost');

  List<Document> _docs;
  final List<String> calls = [];
  Map<String, Object?>? lastUpload;
  List<int>? downloadBytes;
  Object? Function()? uploadImpl; // null -> success
  Object? Function()? downloadImpl; // null -> success

  List<Document> get documents => _docs;
  Object? Function()? getImpl; // null -> serve the in-memory list

  @override
  Future<List<Document>> getDocuments(int contractId) async {
    calls.add('get:$contractId');
    final impl = getImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    return List.of(_docs);
  }

  @override
  Future<Document> uploadDocument(
    int contractId, {
    required String fileName,
    required String fileType,
    required List<int> fileData,
    String? title,
    DateTime? documentDate,
  }) async {
    calls.add('upload:$contractId');
    lastUpload = {
      'contractId': contractId,
      'fileName': fileName,
      'fileType': fileType,
      'fileData': fileData,
      'title': title,
      'documentDate': documentDate,
    };
    final impl = uploadImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    final stored = Document(
      id: 1000 + _docs.length,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileData.length,
      contractId: contractId,
      uploadedAt: DateTime.utc(2026, 6, 1),
      documentDate: documentDate,
      version: 1,
      createdBy: 'harry@harry-neufeld.de',
      title: (title?.trim().isEmpty ?? true) ? null : title!.trim(),
    );
    _docs = [..._docs, stored];
    return stored;
  }

  @override
  Future<List<int>> downloadDocument(int id) async {
    calls.add('download:$id');
    final impl = downloadImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    final bytes = downloadBytes ?? utf8.encode('pdf-bytes-$id');
    if (bytes.isEmpty) throw Exception('Download returned no data.');
    return bytes;
  }
}

Document _doc(int id, {String fileName = 'contract.pdf'}) => Document(
      id: id,
      fileName: fileName,
      fileType: 'application/pdf',
      fileSize: 2048,
      contractId: 7,
      uploadedAt: DateTime.utc(2026, 1, 1),
      version: 1,
      createdBy: 'harry@harry-neufeld.de',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentProvider.loadFor (list)', () {
    test('loads the documents of the given contract', () async {
      final api = _FakeApi([_doc(1), _doc(2, fileName: 'other.pdf')]);
      final provider = DocumentProvider(api: api);

      await provider.loadFor(7);

      expect(provider.contractId, 7);
      expect(provider.documents.map((d) => d.id).toSet(), {1, 2});
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('re-using the same contract with a loaded list is a no-op', () async {
      final api = _FakeApi([_doc(1)]);
      final provider = DocumentProvider(api: api);

      await provider.loadFor(7);
      await provider.loadFor(7);

      expect(api.calls.where((c) => c == 'get:7'), hasLength(1));
    });

    test('switching contracts refetches the list', () async {
      final api = _FakeApi([_doc(1)]);
      final provider = DocumentProvider(api: api);

      await provider.loadFor(7);
      await provider.loadFor(8);

      expect(api.calls, contains('get:7'));
      expect(api.calls, contains('get:8'));
      expect(provider.contractId, 8);
    });

    test('API error leaves an empty list and surfaces the message', () async {
      final api = _FakeApi([])
        ..getImpl = () => throw ApiException(
            message: 'Server error (500). Please try again.', statusCode: 500);
      final provider = DocumentProvider(api: api);

      await provider.loadFor(7);

      expect(provider.documents, isEmpty);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoading, isFalse);
    });
  });

  group('DocumentProvider.uploadDocument', () {
    test('uploads name/bytes/metadata and refreshes the list', () async {
      final api = _FakeApi([]);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      final bytes = utf8.encode('hello upload');
      await provider.uploadDocument(
        PickedDocument(name: 'invoice.pdf', bytes: bytes),
        title: '  Q2 Invoice ',
        documentDate: DateTime(2026, 5, 1),
      );

      expect(api.calls, contains('upload:7'));
      expect(api.lastUpload!['fileName'], 'invoice.pdf');
      expect(api.lastUpload!['fileType'], 'application/pdf');
      expect(api.lastUpload!['fileData'], bytes);
      // The provider passes metadata through untouched; ApiService
      // applies the trim/defaults before the request goes out.
      expect(api.lastUpload!['title'], '  Q2 Invoice ');
      expect(api.lastUpload!['documentDate'], DateTime(2026, 5, 1));
      // The list now contains the uploaded document.
      expect(
          provider.documents.map((d) => d.fileName), contains('invoice.pdf'));
      expect(provider.notice, isNotNull);
      expect(provider.notice, contains('invoice.pdf'));
      expect(provider.errorMessage, isNull);
      expect(provider.isBusy, isFalse);
    });

    test('MIME type is guessed from the extension', () async {
      final api = _FakeApi([]);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      await provider.uploadDocument(
          const PickedDocument(name: 'plan.xlsx', bytes: [1, 2, 3]));

      expect(api.lastUpload!['fileType'],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    });

    test('API error surfaces the message and drops no state', () async {
      final api = _FakeApi([_doc(1)])
        ..uploadImpl =
            () => ApiException(message: 'File too large.', statusCode: 400);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      await provider
          .uploadDocument(const PickedDocument(name: 'big.pdf', bytes: [1]));

      expect(provider.errorMessage, 'File too large.');
      expect(provider.notice, isNull);
      expect(provider.documents.map((d) => d.id), [1]); // list intact
      expect(provider.isBusy, isFalse);
    });

    test('is a no-op when no contract has been loaded yet', () async {
      final api = _FakeApi([]);
      final provider = DocumentProvider(api: api);

      await provider
          .uploadDocument(const PickedDocument(name: 'orphan.pdf', bytes: [1]));

      expect(api.calls.where((c) => c.startsWith('upload:')), isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });

  group('DocumentProvider.downloadAndOpen', () {
    late Directory scratch;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('qontract_dl_test_');
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'), null);
      if (scratch.existsSync()) {
        await scratch.delete(recursive: true);
      }
    });

    void mockPlatforms() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            call.method == 'getTemporaryDirectory' ? scratch.path : null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async =>
            call.method == 'canLaunch' || call.method == 'launch' ? true : null,
      );
    }

    test('download failure reports the error and opens nothing', () async {
      final api = _FakeApi([_doc(1)])
        ..downloadImpl = () => ApiException(
            message: 'This item no longer exists.', statusCode: 404);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      final ok = await provider.downloadAndOpen(provider.documents.single);

      expect(ok, isFalse);
      expect(provider.errorMessage, 'This item no longer exists.');
      expect(provider.notice, isNull);
      expect(provider.isBusy, isFalse);
    });

    test('downloads to a local file and opens it with the system handler',
        () async {
      mockPlatforms();
      final api = _FakeApi([_doc(1)])..downloadBytes = [9, 8, 7, 6];
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      final ok = await provider.downloadAndOpen(provider.documents.single);

      expect(ok, isTrue);
      final target = File('${scratch.path}/contract.pdf');
      expect(target.existsSync(), isTrue);
      expect(await target.readAsBytes(), [9, 8, 7, 6]);
      expect(provider.notice, isNotNull);
      expect(provider.notice, contains('contract.pdf'));
      expect(provider.errorMessage, isNull);
      expect(provider.isBusy, isFalse);
    });
  });
}
