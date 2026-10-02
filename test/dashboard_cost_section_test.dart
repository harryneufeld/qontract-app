import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

User _user() => User(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      role: 'User',
      tenantId: 7,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Contract _contract(
  int id,
  String title, {
  String status = 'Active',
  String? value,
  String? currency = 'EUR',
  String? startDate,
  String? endDate,
}) =>
    Contract(
      id: id,
      title: title,
      status: status,
      value: value,
      billingPeriod: 'Monthly',
      currency: currency,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

class _FakeApiService extends ApiService {
  _FakeApiService({
    required List<Contract> contracts,
    required List<Contractor> contractors,
  })  : _contracts = contracts,
        _contractors = contractors,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;
  bool failFullList = false;
  Completer<List<Contract>>? pending;

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts(
      {int page = 0, int pageSize = 0, String? status}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts.sublist(
        start, (start + pageSize).clamp(0, _contracts.length));
  }

  @override
  Future<List<Contract>> getContractList() async {
    if (failFullList) {
      throw ApiException(message: 'Unavailable', statusCode: 503);
    }
    if (pending != null) return await pending!.future;
    return _contracts;
  }

  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

  @override
  Future<List<Contractor>> getContractors() async => _contractors;
}

Future<AuthProvider> _seededAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
  final api = _FakeApiService(contracts: [], contractors: []);
  final auth = AuthProvider(api: api, storage: StorageService());
  await auth.checkSession();
  return auth;
}

Widget _harness({
  required AuthProvider auth,
  required ContractProvider contracts,
  required ContractorProvider contractorProvider,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ContractProvider>.value(value: contracts),
        ChangeNotifierProvider<ContractorProvider>.value(
            value: contractorProvider),
      ],
      child: const DashboardScreen(),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('late full-list responses cannot replace a newer complete cost set',
      () async {
    final api = _FakeApiService(contracts: [], contractors: [])
      ..pending = Completer<List<Contract>>();
    final provider = ContractProvider(api: api);
    final first = api.pending!;
    final firstLoad = provider.fetchAllContracts();
    expect(provider.costContracts, isEmpty);
    api.pending = Completer<List<Contract>>();
    final secondLoad = provider.fetchAllContracts();
    api.pending!.complete([_contract(2, 'Latest', value: '200')]);
    await secondLoad;
    first.complete([_contract(1, 'Older', value: '100')]);
    await firstLoad;
    expect(provider.costContracts.single.id, 2);
    expect(provider.isLoadingFullList, false);
    expect(provider.fullListError, isNull);
  });
  Future<void> open(WidgetTester tester, _FakeApiService api) async {
    await tester.pumpWidget(_harness(
        auth: await _seededAuth(),
        contracts: ContractProvider(api: api),
        contractorProvider: ContractorProvider(api: api)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'month quarter and year show complete separate currency totals together',
      (tester) async {
    final api = _FakeApiService(contracts: [
      for (var id = 1; id <= 25; id++)
        _contract(id, 'Monthly', value: '10', startDate: '2000-01-01'),
      _contract(26, 'USD',
          value: '5', currency: 'USD', startDate: '2000-01-01'),
      _contract(27, 'Draft', status: 'Draft', value: '999'),
    ], contractors: []);
    await open(tester, api);
    for (final label in ['This month', 'This quarter', 'This year']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final entry in {
      'month': '250.00',
      'quarter': '750.00',
      'year': '3,000.00'
    }.entries) {
      expect(
          tester
              .widget<Text>(find.byKey(ValueKey('cost.${entry.key}.EUR')))
              .data,
          'EUR ${entry.value}');
    }
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('cost.year.USD'))).data,
        'USD 60.00');
    expect(find.text('26 active contracts · entire tenant'), findsOneWidget);
    await tester.tap(find.byKey(const Key('statActive')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('cost.month.EUR'))).data,
        'EUR 250.00');
    await tester.enterText(find.byType(TextField).first, 'Draft');
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('cost.year.EUR'))).data,
        'EUR 3,000.00');
  });

  testWidgets(
      'failed complete load never presents partial page as total and can retry',
      (tester) async {
    final api = _FakeApiService(contracts: [
      for (var id = 1; id <= 25; id++)
        _contract(id, 'Monthly', value: '10', startDate: '2000-01-01'),
    ], contractors: [])
      ..failFullList = true;
    await open(tester, api);
    expect(find.byKey(const ValueKey('cost.month.EUR')), findsNothing);
    expect(find.byKey(const Key('retryCostOverview')), findsOneWidget);
    api.failFullList = false;
    await tester.tap(find.byKey(const Key('retryCostOverview')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('cost.month.EUR'))).data,
        'EUR 250.00');
  });

  testWidgets('complete list loading state never shows partial costs',
      (tester) async {
    final api = _FakeApiService(
        contracts: [_contract(1, 'Monthly', value: '100')], contractors: [])
      ..pending = Completer<List<Contract>>();
    await tester.pumpWidget(_harness(
        auth: await _seededAuth(),
        contracts: ContractProvider(api: api),
        contractorProvider: ContractorProvider(api: api)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Loading all active contract costs…'), findsOneWidget);
    expect(find.byKey(const ValueKey('cost.month.EUR')), findsNothing);
    api.pending!.complete(
        [_contract(1, 'Monthly', value: '100', startDate: '2000-01-01')]);
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('cost.month.EUR'))).data,
        'EUR 100.00');
  });

  testWidgets('empty costs and unclassified data stay explicit at phone width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final unknown = _contract(1, 'Missing period', value: '500').toJson()
      ..remove('billingPeriod');
    final contract = Contract.fromJson({
      ...unknown,
      'id': 1,
      'createdAt': '2000-01-01T00:00:00Z',
      'modifiedAt': '2000-01-01T00:00:00Z',
    });
    await open(tester, _FakeApiService(contracts: [contract], contractors: []));
    expect(find.text('No estimated costs'), findsNWidgets(3));
    expect(find.text('1 to review: missing or invalid billing data'),
        findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
