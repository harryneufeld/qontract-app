import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/document/document_list_screen.dart';
import 'package:qontract_app/screens/document/documents_section.dart';
import 'package:qontract_app/screens/document/image_preview_screen.dart';
import 'package:qontract_app/services/api_service.dart';

final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
Document image(
        {String name = 'receipt.PNG',
        String type = 'application/octet-stream'}) =>
    Document(
        id: 42,
        contractId: 7,
        fileName: name,
        title: 'Receipt photo',
        fileType: type,
        fileSize: 100,
        uploadedAt: DateTime.utc(2026),
        version: 1);

class ImageApi extends ApiService {
  final doc = image();
  final downloaded = <int>[];
  List<int> bytes = png;
  Completer<List<int>>? pending;
  @override
  Future<List<Document>> getDocuments(int contractId) async => [doc];
  @override
  Future<List<Document>> getLibraryDocuments(
          {String scope = 'Tenant',
          bool deleted = false,
          int page = 1}) async =>
      [doc];
  @override
  Future<List<int>> downloadDocument(int id) async {
    downloaded.add(id);
    if (pending != null) return await pending!.future;
    return bytes;
  }
}

Future<void> open(WidgetTester tester, ImageApi api, Widget page) async {
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DocumentProvider(api: api),
      child: MaterialApp(home: page)));
  await tester.pumpAndSettle();
}

Future<void> decode(WidgetTester tester) async {
  await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  test('recognizes common raster extensions and image MIME types', () {
    for (final extension in [
      'PNG',
      'jpg',
      'JPEG',
      'gif',
      'webp',
      'bmp',
      'wbmp'
    ]) {
      expect(image(name: 'scan.$extension').isImage, true);
    }
    expect(
        image(name: 'scan', type: 'IMAGE/JPEG; charset=binary').isImage, true);
    expect(image(name: 'scan.pdf', type: 'application/pdf').isImage, false);
  });

  testWidgets('library row opens an authenticated image with zoom and pan',
      (tester) async {
    final api = ImageApi();
    await open(tester, api, DocumentListScreen(api: api));
    await tester.tap(find.text('Receipt photo'));
    await tester.pumpAndSettle();
    await decode(tester);
    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const Key('documentImagePreview')), findsOneWidget);
    expect(find.text('Image preview unavailable.'), findsNothing);
    expect(api.downloaded, [42]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'contract attachment row and Preview action open the image viewer',
      (tester) async {
    final api = ImageApi();
    final contract = Contract(
        id: 7,
        title: 'Contract',
        status: 'Active',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026));
    await open(
        tester, api, Scaffold(body: DocumentsSection(contract: contract)));
    await tester.tap(find.text('Receipt photo'));
    await tester.pumpAndSettle();
    await decode(tester);
    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Document actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await decode(tester);
    expect(find.byType(ImagePreviewScreen), findsOneWidget);
    expect(api.downloaded, [42, 42]);
  });

  testWidgets(
      'download failure offers retry and recovers without leaving the viewer',
      (tester) async {
    final api = ImageApi()..pending = Completer<List<int>>();
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => DocumentProvider(api: api),
        child: MaterialApp(home: ImagePreviewScreen(doc: api.doc))));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.pending!
        .completeError(ApiException(message: 'Unavailable', statusCode: 503));
    await tester.pumpAndSettle();
    expect(find.text('Image preview unavailable.'), findsOneWidget);
    expect(find.text('Open in app'), findsOneWidget);
    api.pending = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await decode(tester);
    expect(find.text('Image preview unavailable.'), findsNothing);
    expect(api.downloaded, [42, 42]);
  });

  testWidgets('corrupt image bytes show a fallback instead of crashing',
      (tester) async {
    final api = ImageApi()..bytes = [1, 2, 3];
    await open(tester, api, ImagePreviewScreen(doc: api.doc));
    await decode(tester);
    expect(find.text('Image preview unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Open in app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
