import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Records calls and serves canned data instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._initial) : super(baseUrl: 'http://localhost');

  List<Document> _initial;
  final List<String> calls = [];
  int? deletedId;
  Map<int, (String?, DateTime?)>? metadataUpdates;

  List<Document> get documents => _initial;

  @override
  Future<List<Document>> getDocuments(int contractId) async {
    calls.add('get:$contractId');
    return List.of(_initial);
  }

  @override
  Future<Document> updateDocumentMetadata(
    int id, {
    String? title,
    DateTime? documentDate,
  }) async {
    calls.add('updateMeta:$id');
    metadataUpdates ??= {};
    metadataUpdates![id] = (title, documentDate);
    // Simulate the backend: patch the in-memory list.
    _initial = [
      for (final d in _initial)
        if (d.id == id)
          Document(
            id: d.id,
            title: title ?? d.title,
            fileName: d.fileName,
            fileType: d.fileType,
            fileSize: d.fileSize,
            contractId: d.contractId,
            uploadedAt: d.uploadedAt,
            documentDate: documentDate ?? d.documentDate,
            version: d.version,
            createdBy: d.createdBy,
            modifiedBy: d.modifiedBy,
          )
        else
          d,
    ];
    return _initial.firstWhere((d) => d.id == id);
  }

  @override
  Future<void> deleteDocument(int id) async {
    calls.add('delete:$id');
    deletedId = id;
    // Simulate the backend soft-delete: the document disappears from reads.
    _initial = _initial.where((d) => d.id != id).toList();
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
  group('DocumentProvider.deleteDocument', () {
    test('removes the document from the list and notes the 90-day retention',
        () async {
      final api = _FakeApiService([_doc(1), _doc(2, fileName: 'other.pdf')]);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);
      expect(provider.documents.length, 2);

      await provider.deleteDocument(provider.documents.first);

      expect(api.deletedId, 1);
      expect(provider.documents.length, 1);
      expect(provider.documents.single.id, 2);
      expect(provider.errorMessage, isNull);
      expect(provider.notice, isNotNull);
      expect(provider.notice, contains('90 days'));
    });

    test('surfaces the API error and keeps the list intact on failure',
        () async {
      final api = _ThrowingApiService();
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);
      expect(provider.documents.length, 1);

      await provider.deleteDocument(provider.documents.single);

      expect(provider.errorMessage, isNotNull);
      expect(provider.notice, isNull);
      // Failed delete must not drop the document from the local list.
      expect(provider.documents.length, 1);
    });
  });

  group('DocumentProvider.updateMetadata', () {
    test('sends title + date and refreshes the list', () async {
      final api = _FakeApiService([_doc(1)]);
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      await provider.updateMetadata(
        provider.documents.single,
        title: 'Lease 2026',
        documentDate: DateTime(2026, 1, 15),
      );

      expect(api.metadataUpdates?[1], ('Lease 2026', DateTime(2026, 1, 15)));
      expect(api.calls.any((c) => c.startsWith('updateMeta:1')), isTrue);
      expect(provider.documents.single.title, 'Lease 2026');
      expect(provider.documents.single.documentDate, DateTime(2026, 1, 15));
      expect(provider.documents.single.displayName, 'Lease 2026');
      expect(provider.notice, isNotNull);
      expect(provider.errorMessage, isNull);
    });

    test('surfaces the API error without changing the list', () async {
      final api = _ThrowingApiService();
      final provider = DocumentProvider(api: api);
      await provider.loadFor(7);

      await provider.updateMetadata(
        provider.documents.single,
        title: 'Nope',
        documentDate: DateTime(2026, 2, 1),
      );

      expect(provider.errorMessage, isNotNull);
      expect(provider.documents.single.title, isNull);
      expect(provider.documents.length, 1);
    });
  });
}

/// Always fails on delete to exercise the error path.
class _ThrowingApiService extends ApiService {
  _ThrowingApiService() : super(baseUrl: 'http://localhost');

  final _docs = [_doc(9, fileName: 'keep.pdf')];

  @override
  Future<List<Document>> getDocuments(int contractId) async {
    return List.of(_docs);
  }

  @override
  Future<void> deleteDocument(int id) async {
    throw ApiException(message: 'Server error', statusCode: 500);
  }

  @override
  Future<Document> updateDocumentMetadata(
    int id, {
    String? title,
    DateTime? documentDate,
  }) async {
    throw ApiException(message: 'Server error', statusCode: 500);
  }
}
