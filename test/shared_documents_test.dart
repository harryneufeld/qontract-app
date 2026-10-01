import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/document/documents_section.dart';
import 'package:qontract_app/services/api_service.dart';

Contract contract(int id) => Contract(
    id: id,
    title: 'Contract $id',
    status: 'Active',
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026));

class SharedApi extends ApiService {
  bool removed = false;
  int? linkedTo;
  final document = Document(
      id: 10,
      fileName: 'evidence.pdf',
      fileType: 'application/pdf',
      fileSize: 42,
      contractId: 1,
      additionalContractIds: [2],
      uploadedAt: DateTime(2026),
      version: 1);
  @override
  Future<List<Document>> getDocuments(int contractId) async =>
      removed ? [] : [document];
  @override
  Future<List<Contract>> getContractList() async =>
      [contract(1), contract(2), contract(3)];
  @override
  Future<Document> setDocumentContractLink(int id, int contractId,
      {required bool linked}) async {
    if (linked) {
      linkedTo = contractId;
    } else {
      removed = true;
    }
    return document;
  }
}

Future<void> showDocuments(WidgetTester tester, SharedApi api, int id) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DocumentProvider(api: api),
      child: MaterialApp(
          home: Scaffold(body: DocumentsSection(contract: contract(id))))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'secondary link removal confirms and refreshes without deleting the file',
      (tester) async {
    final api = SharedApi();
    await showDocuments(tester, api, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Document actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from this contract'));
    await tester.pumpAndSettle();
    expect(api.removed, false);
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();
    expect(api.removed, true);
    expect(find.text('evidence.pdf'), findsNothing);
  });
  testWidgets(
      'link picker excludes existing contracts and primary removal is unavailable',
      (tester) async {
    final api = SharedApi();
    await showDocuments(tester, api, 1);
    await tester.tap(find.byTooltip('Document actions'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from this contract'), findsNothing);
    await tester.tap(find.text('Link to another contract'));
    await tester.pumpAndSettle();
    expect(find.text('Contract 1'), findsNothing);
    expect(find.text('Contract 2'), findsNothing);
    await tester.tap(find.text('Contract 3'));
    await tester.pumpAndSettle();
    expect(api.linkedTo, 3);
    expect(tester.takeException(), isNull);
  });
}
