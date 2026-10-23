import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/contractor/contractor_list_screen.dart';
import 'package:qontract_app/screens/document/documents_section.dart';
import 'package:qontract_app/services/api_service.dart';

class SortApi extends ApiService {
  @override
  Future<List<Contractor>> getContractors() async => [
        for (final row in [(1, 'Zulu', 5), (2, 'Alpha', 1)])
          Contractor(
              id: row.$1,
              name: row.$2,
              contractCount: row.$3,
              type: ContractorType.company,
              tenantId: 1,
              isActive: true,
              createdAt: DateTime(2026),
              modifiedAt: DateTime(2026, row.$1)),
      ];
  @override
  Future<List<Document>> getDocuments(int contractId) async => [
        Document(
            id: 1,
            title: 'Older agreement',
            fileName: 'old.pdf',
            fileType: 'application/pdf',
            fileSize: 42,
            contractId: 1,
            uploadedAt: DateTime(2026, 10, 1),
            documentDate: DateTime(2026, 1, 5),
            version: 1),
        Document(
            id: 2,
            title: 'Newer agreement',
            fileName: 'new.pdf',
            fileType: 'application/pdf',
            fileSize: 42,
            contractId: 1,
            uploadedAt: DateTime(2026, 1, 1),
            documentDate: DateTime(2026, 5, 6),
            version: 1),
        Document(
            id: 3,
            fileName: 'undated.pdf',
            fileType: 'application/pdf',
            fileSize: 42,
            contractId: 1,
            uploadedAt: DateTime(2026, 12, 1),
            version: 1),
      ];
}

void main() {
  testWidgets(
      'contractor count follows search and sort does not mutate provider order',
      (tester) async {
    final api = SortApi();
    final contractors = ContractorProvider(api: api);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
      ChangeNotifierProvider.value(value: contractors),
    ], child: const MaterialApp(home: ContractorListScreen())));
    await tester.pumpAndSettle();
    expect(find.text('2 contractors'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Alpha')).dy,
        lessThan(tester.getTopLeft(find.text('Zulu')).dy));
    await tester.tap(find.byKey(const Key('contractorSort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most contracts'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Zulu')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy));
    expect(contractors.contractors.first.name, 'Zulu');
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Zulu'), findsNothing);
  });

  testWidgets(
      'documents sort by document date and display title above file metadata',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => DocumentProvider(api: SortApi()),
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: DocumentsSection(
                        contract: Contract(
                            id: 1,
                            title: 'Demo',
                            status: 'Active',
                            createdAt: DateTime(2026),
                            modifiedAt: DateTime(2026))))))));
    await tester.pumpAndSettle();
    List<String> titles() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data!)
        .toList();
    expect(
        titles(), ['Newer agreement', 'Older agreement', 'Untitled document']);
    final tile = tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Newer agreement'));
    final lines = ((tile.subtitle! as Column).children).cast<Text>();
    expect(lines[0].data, 'new.pdf');
    expect(lines[1].data, startsWith('2026-05-06'));
    expect(find.textContaining('2026-10-01'), findsNothing);
    expect(find.textContaining('2026-12-01'), findsNothing);
    expect(find.textContaining('Document date not set'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contractDocumentSort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Document date: oldest first'));
    await tester.pumpAndSettle();
    expect(
        titles(), ['Older agreement', 'Newer agreement', 'Untitled document']);
    expect(tester.takeException(), isNull);
  });
}
