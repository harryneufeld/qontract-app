import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/widgets/currency_field.dart';
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
  String defaultCurrency = 'EUR';
  @override
  Future<String> getDefaultCurrency() async => defaultCurrency;
  @override
  Future<List<Map<String, dynamic>>> getResponsibleMembers() async => [
        {'id': 1, 'name': 'First member'},
        {'id': 2, 'name': 'Second member'}
      ];
  @override
  Future<Contract> updateContract(int id, Contract c) async {
    saved = c;
    return c;
  }

  @override
  Future<List<Contractor>> getContractors() async => [];
  @override
  Future<Contract> createContract(Contract c) async {
    saved = c;
    return c;
  }
}

void main() {
  testWidgets(
      'new contracts use the tenant default and edits keep their currency',
      (tester) async {
    final api = _Api()..defaultCurrency = 'USD';
    Widget harness(Contract? contract) => MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
              ChangeNotifierProvider(
                  create: (_) => ContractorProvider(api: api)),
            ],
            child: MaterialApp(
                home: ContractFormScreen(api: api, contract: contract)));
    await tester.pumpWidget(harness(null));
    await tester.pumpAndSettle();
    final currency = find.byType(CurrencyField);
    await tester.scrollUntilVisible(currency, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: currency, matching: find.text(r'$ · USD')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(Contract(
        id: 1,
        title: 'Existing',
        status: 'Active',
        currency: 'GBP',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(currency, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: currency, matching: find.text('£ · GBP')),
        findsOneWidget);
  });
  test(
      'price history decodes dates, period and notes without becoming client edit data',
      () {
    final contract = Contract.fromJson({
      'id': 1,
      'title': 'Subscription',
      'status': 'Active',
      'value': '120',
      'billingPeriod': 'Quarterly',
      'createdAt': '2026-01-01T00:00:00Z',
      'modifiedAt': '2026-07-01T00:00:00Z',
      'priceHistory': [
        {
          'id': 'history-id',
          'value': '100',
          'currency': 'EUR',
          'billingPeriod': 'Monthly',
          'effectiveFrom': '2026-01-01',
          'effectiveUntil': '2026-07-01',
          'notes': 'Original price'
        }
      ],
    });
    expect(contract.billingPeriod, 'Quarterly');
    expect(contract.priceHistory.single.notes, 'Original price');
    expect(contract.priceHistory.single.intervalLabel,
        '2026-01-01 through 2026-06-30');
    expect(contract.toJson()['billingPeriod'], 'Quarterly');
    expect(contract.toJson().containsKey('priceHistory'), false);
  });
  test(
      'unknown billing periods are preserved and same-day revisions show supersession',
      () {
    final price = ContractPrice.fromJson({
      'value': '100 EUR',
      'effectiveFrom': '2026-01-01',
      'effectiveUntil': '2026-01-01'
    });
    expect(price.billingPeriod, null);
    expect(price.value, '100 EUR');
    expect(price.intervalLabel, 'Superseded on 2026-01-01');
  });
  testWidgets('contract form submits the selected billing period',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
      ChangeNotifierProvider(create: (_) => ContractorProvider(api: api)),
    ], child: const MaterialApp(home: ContractFormScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Subscription');
    await tester.scrollUntilVisible(find.byKey(const Key('billingPeriod')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('billingPeriod')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('billingPeriod')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quarterly').last);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(ElevatedButton, 'Create Contract');
    await tester.scrollUntilVisible(save, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.billingPeriod, 'Quarterly');
  });
  testWidgets(
      'editing reassigns or clears responsibility while preserving inactivity',
      (tester) async {
    for (final selection in ['Second member', 'Unassigned']) {
      final api = _Api();
      final existing = Contract(
          id: 1,
          title: 'Inactive agreement',
          status: 'Active',
          isActive: false,
          responsibleUserId: 1,
          responsibleUserName: 'First member',
          createdAt: DateTime.utc(2025),
          modifiedAt: DateTime.utc(2025));
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
            ChangeNotifierProvider(create: (_) => ContractorProvider(api: api))
          ],
          child: MaterialApp(
              home: ContractFormScreen(contract: existing, api: api))));
      await tester.pumpAndSettle();
      final member = find.byKey(const ValueKey('responsible-2'));
      await tester.scrollUntilVisible(member, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(member);
      await tester.tap(member);
      await tester.pumpAndSettle();
      await tester.tap(find.text(selection).last);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'Update Contract');
      await tester.scrollUntilVisible(save, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.saved, isNotNull);
      expect(api.saved!.isActive, false);
      expect(
          api.saved!.responsibleUserId, selection == 'Unassigned' ? null : 2);
      expect(api.saved!.clearResponsibleUser, selection == 'Unassigned');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
