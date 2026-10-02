import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/contract/contract_form_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  Contract? saved;
  @override
  Future<List<Contractor>> getContractors() async => [];
  @override
  Future<Contract> createContract(Contract c) async {
    saved = c;
    return c;
  }

  @override
  Future<Contract> updateContract(int id, Contract c) async {
    saved = c;
    return c;
  }
}

Contract _contract({String? type = 'Insurance'}) => Contract.fromJson({
      'id': 1,
      'title': 'Legacy contract',
      'status': 'Active',
      'iban': ' DE89 3704 0044 0532 0130 00 ',
      'notes': ' First line\nSecond line — ÄÖÜ\n ',
      'type': type,
      'createdAt': '2026-01-01T00:00:00Z',
      'modifiedAt': '2026-01-01T00:00:00Z',
    });

Future<void> _open(WidgetTester tester, _Api api, Contract? contract) async {
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
    ChangeNotifierProvider(create: (_) => ContractorProvider(api: api)),
  ], child: MaterialApp(home: ContractFormScreen(contract: contract))));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('all legacy types and raw metadata survive JSON round trips', () {
    for (final type in contractTypes.keys) {
      final contract = _contract(type: type);
      final json = contract.toJson();
      expect(json['type'], type);
      expect(json['iban'], contract.iban);
      expect(json['notes'], ' First line\nSecond line — ÄÖÜ\n ');
      expect(json['status'], 'Active');
      expect(json.containsKey('clearType'), false);
    }
    expect(_contract(type: null).toJson().containsKey('type'), false);
  });

  testWidgets('editing preserves legacy whitespace and future type values',
      (tester) async {
    final api = _Api();
    await _open(tester, api, _contract(type: 'FutureType'));
    await _show(tester, find.byKey(const Key('contractType')));
    expect(find.text('FutureType'), findsOneWidget);
    final save = find.widgetWithText(ElevatedButton, 'Update Contract');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.type, 'FutureType');
    expect(api.saved!.iban, _contract().iban);
    expect(api.saved!.notes, _contract().notes);
    expect(api.saved!.clearType, false);
  });

  testWidgets('editing can clear metadata and explicitly reset classification',
      (tester) async {
    final api = _Api();
    await _open(tester, api, _contract());
    await _show(tester, find.byKey(const Key('contractType')));
    await tester.tap(find.byKey(const Key('contractType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unclassified').last);
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const Key('contractIban')));
    await tester.enterText(find.byKey(const Key('contractIban')), '');
    await _show(tester, find.byKey(const Key('contractNotes')));
    await tester.enterText(find.byKey(const Key('contractNotes')), '');
    final save = find.widgetWithText(ElevatedButton, 'Update Contract');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.toJson()['clearType'], true);
    expect(api.saved!.toJson()['iban'], '');
    expect(api.saved!.toJson()['notes'], '');
  });

  testWidgets('new contracts submit category and multiline contract notes',
      (tester) async {
    final api = _Api();
    await _open(tester, api, null);
    await tester.enterText(
        find.byType(TextFormField).first, 'New subscription');
    await _show(tester, find.byKey(const Key('contractType')));
    await tester.tap(find.byKey(const Key('contractType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscription').last);
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const Key('contractNotes')));
    await tester.enterText(
        find.byKey(const Key('contractNotes')), 'Line one\nLine two');
    final save = find.widgetWithText(ElevatedButton, 'Create Contract');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.type, 'Subscription');
    expect(api.saved!.notes, 'Line one\nLine two');
    expect(api.saved!.priceNotes, null);
  });
}
