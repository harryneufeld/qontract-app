import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/screens/contract/contract_trash_screen.dart';
import 'package:qontract_app/services/api_service.dart';

Contract item(int id, DateTime deadline) => Contract(
    id: id,
    title: 'Contract $id',
    status: 'Active',
    isActive: false,
    deletedAt: DateTime.now(),
    retentionExpiresAt: deadline,
    createdAt: DateTime.utc(2025),
    modifiedAt: DateTime.utc(2025));

class TrashApi extends ApiService {
  TrashApi() : super(baseUrl: 'http://localhost');
  final rows = [
    item(1, DateTime.now().add(const Duration(days: 1))),
    item(2, DateTime.now().subtract(const Duration(days: 1)))
  ];
  bool fail = false;
  final restored = <int>[];
  @override
  Future<List<Contract>> getContractTrash() async {
    if (fail) {
      throw ApiException(message: 'Temporarily unavailable', statusCode: 503);
    }
    return List.of(rows);
  }

  @override
  Future<Contract> restoreContract(int id) async {
    restored.add(id);
    final row = rows.firstWhere((c) => c.id == id);
    rows.remove(row);
    return row;
  }

  @override
  Future<List<Contract>> getContracts(
          {int page = 0, int pageSize = 0, String? status}) async =>
      [];
  @override
  Future<List<Contract>> getContractList() async => [];
}

void main() {
  testWidgets('trash restores recoverable contracts and disables expired ones',
      (tester) async {
    final api = TrashApi();
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => ContractProvider(api: api),
        child: MaterialApp(home: ContractTrashScreen(api: api))));
    await tester.pumpAndSettle();
    final buttons =
        tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();
    expect(buttons.first.onPressed, isNotNull);
    expect(buttons.last.onPressed, isNull);
    await tester.tap(find.text('Restore').first);
    await tester.pumpAndSettle();
    expect(api.restored, [1]);
    expect(find.text('Contract 1'), findsNothing);
    expect(find.text('Contract 2'), findsOneWidget);
  });
  testWidgets('trash load errors can be retried', (tester) async {
    final api = TrashApi()..fail = true;
    await tester.pumpWidget(MaterialApp(home: ContractTrashScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Temporarily unavailable'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Temporarily unavailable'), findsNothing);
    expect(find.text('Contract 1'), findsOneWidget);
  });
}
