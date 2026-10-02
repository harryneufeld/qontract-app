import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/document/document_list_screen.dart';
import 'package:qontract_app/services/api_service.dart';

Document file(int id, String scope) => Document(
    id: id,
    scope: scope,
    userId: 42,
    tenantId: scope == 'Tenant' ? 1 : null,
    fileName: '$scope-$id.pdf',
    title: '$scope file $id',
    fileType: 'application/pdf',
    fileSize: 42,
    uploadedAt: DateTime(2026),
    version: 1,
    category: 'Receipts',
    description: 'File description');

class LibraryApi extends ApiService {
  final tenant = [file(1, 'Tenant')], personal = [file(2, 'Personal')];
  final trashed = <int>{};
  Map<String, dynamic>? uploaded, patched;
  String? uploadedScope, failure;
  final calls = <String>[];
  @override
  Future<List<Document>> getLibraryDocuments(
      {String scope = 'Tenant', bool deleted = false, int page = 1}) async {
    calls.add('$scope/$deleted/$page');
    if (failure != null) throw ApiException(message: failure!);
    return (scope == 'Tenant' ? tenant : personal)
        .where((d) => trashed.contains(d.id) == deleted)
        .toList();
  }

  @override
  Future<Document> uploadLibraryDocument(
      {required String scope,
      required String fileName,
      required String fileType,
      required List<int> fileData,
      String? title,
      String? description,
      String? category,
      DateTime? documentDate}) async {
    uploadedScope = scope;
    uploaded = {
      'fileName': fileName,
      'bytes': fileData,
      'title': title,
      'category': category,
      'description': description
    };
    final doc = file(3, scope);
    (scope == 'Tenant' ? tenant : personal).add(doc);
    return doc;
  }

  @override
  Future<Document> patchLibraryMetadata(
      int id, Map<String, dynamic> data) async {
    patched = data;
    return file(id, 'Tenant');
  }

  @override
  Future<void> deleteDocument(int id) async {
    trashed.add(id);
  }

  @override
  Future<Document> restoreDocument(int id) async {
    trashed.remove(id);
    return file(id, 'Tenant');
  }
}

class DelayedLibraryApi extends LibraryApi {
  final old = Completer<List<Document>>();
  @override
  Future<List<Document>> getLibraryDocuments(
          {String scope = 'Tenant',
          bool deleted = false,
          int page = 1}) async =>
      scope == 'Tenant' ? await old.future : personal;
}

Future<void> library(WidgetTester tester, LibraryApi api,
    {Future<PickedDocument?> Function()? pick}) async {
  await tester.pumpWidget(
      MaterialApp(home: DocumentListScreen(api: api, pickFile: pick)));
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, String text) async {
  await tester.tap(find.byTooltip('File actions').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  test('library documents parse nullable contract and owner/scope metadata',
      () {
    final doc = Document.fromJson({
      'id': 1,
      'scope': 'Personal',
      'userId': 42,
      'fileName': 'a',
      'uploadedAt': '2026-10-01T00:00:00Z',
      'description': 'Saved',
      'category': 'Notes'
    });
    expect(doc.contractId, isNull);
    expect(doc.contractIds, isEmpty);
    expect(doc.userId, 42);
    expect(doc.scope, 'Personal');
    expect(doc.category, 'Notes');
  });
  testWidgets(
      'tenant and personal views stay separate and personal actions cannot share',
      (tester) async {
    final api = LibraryApi();
    await library(tester, api);
    expect(find.text('Tenant file 1'), findsOneWidget);
    expect(find.text('Personal file 2'), findsNothing);
    await tester.tap(find.text('My files'));
    await tester.pumpAndSettle();
    expect(find.text('Personal file 2'), findsOneWidget);
    expect(find.text('Tenant file 1'), findsNothing);
    await tester.tap(find.byTooltip('File actions'));
    await tester.pumpAndSettle();
    expect(find.text('Link to contract'), findsNothing);
    expect(find.text('Upload new version'), findsOneWidget);
  });
  testWidgets(
      'personal upload sends scope, bytes and full metadata without a contract',
      (tester) async {
    final api = LibraryApi();
    await library(tester, api,
        pick: () async =>
            const PickedDocument(name: 'test.pdf', bytes: [1, 2, 3]));
    await tester.tap(find.text('My files'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Upload file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Personal receipt');
    await tester.enterText(fields.at(1), 'Bills');
    await tester.enterText(fields.at(2), 'Receipt description');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.uploadedScope, 'Personal');
    expect(api.uploaded!['bytes'], [1, 2, 3]);
    expect(api.uploaded!['category'], 'Bills');
    expect(api.uploaded!['description'], 'Receipt description');
    expect(find.text('Personal file 3'), findsOneWidget);
  });
  testWidgets('trash requires confirmation and restore refreshes active files',
      (tester) async {
    final api = LibraryApi();
    await library(tester, api);
    await menu(tester, 'Move to trash');
    expect(api.trashed, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await tester.pumpAndSettle();
    expect(api.trashed, contains(1));
    expect(find.text('Tenant file 1'), findsNothing);
    await tester.tap(find.byTooltip('Show trash'));
    await tester.pumpAndSettle();
    await menu(tester, 'Restore');
    expect(api.trashed, isEmpty);
    await tester.tap(find.byTooltip('Show active files'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant file 1'), findsOneWidget);
  });
  testWidgets('failed library request shows error and refresh recovers',
      (tester) async {
    final api = LibraryApi()..failure = 'Cannot load files.';
    await library(tester, api);
    expect(find.text('Cannot load files.'), findsOneWidget);
    api.failure = null;
    await tester.tap(find.byTooltip('Refresh files'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant file 1'), findsOneWidget);
  });
  testWidgets('a late tenant result cannot replace the personal view',
      (tester) async {
    final api = DelayedLibraryApi();
    await tester.pumpWidget(MaterialApp(home: DocumentListScreen(api: api)));
    await tester.pump();
    await tester.tap(find.text('My files'));
    await tester.pumpAndSettle();
    api.old.complete(api.tenant);
    await tester.pumpAndSettle();
    expect(find.text('Personal file 2'), findsOneWidget);
    expect(find.text('Tenant file 1'), findsNothing);
  });
  testWidgets(
      'evidence selection exposes tenant files without personal or trash controls',
      (tester) async {
    final api = LibraryApi();
    await tester.pumpWidget(
        MaterialApp(home: DocumentListScreen(api: api, selectEvidence: true)));
    await tester.pumpAndSettle();
    expect(find.text('Tenant file 1'), findsOneWidget);
    expect(find.text('My files'), findsNothing);
    expect(find.byTooltip('Show trash'), findsNothing);
    expect(find.byTooltip('Upload file'), findsNothing);
    expect(find.byTooltip('File actions'), findsNothing);
  });
}
