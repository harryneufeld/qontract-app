import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts.sublist(
        start, (start + pageSize).clamp(0, _contracts.length));
  }

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cost section shows per-currency sums and switches periods',
      (tester) async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastMonth = now.subtract(const Duration(days: 30));

    final api = _FakeApiService(
      contracts: [
        // Fully inside the current month: 100 in month AND all-active.
        _contract(
          1,
          'InMonth',
          value: '100',
          startDate: _iso(firstOfMonth),
          endDate: _iso(now),
        ),
        // Spans the previous month: 200 in all-active, only a prorated
        // share in the current month.
        _contract(
          2,
          'Spanning',
          value: '200',
          startDate: _iso(lastMonth),
          endDate: _iso(now),
        ),
        // Not active: never counted.
        _contract(3, 'Drafted', status: 'Draft', value: '999'),
      ],
      contractors: [],
    );
    final contracts = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // Section with the four period pills renders.
    expect(find.byKey(const Key('costSection')), findsOneWidget);
    expect(find.text('Costs (active)'), findsOneWidget);
    for (final key in [
      'costPeriod.month',
      'costPeriod.halfYear',
      'costPeriod.year',
      'costPeriod.allActive',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }

    // Default period is "month": the spanning contract contributes a
    // prorated share, so the EUR sum is between 100.00 and 300.00.
    final costKey = const ValueKey('cost.EUR');
    final monthText = tester.widget<Text>(find.byKey(costKey)).data!;
    expect(monthText, startsWith('EUR '));
    final monthValue = double.parse(monthText.substring(4).replaceAll(',', ''));
    expect(monthValue, greaterThan(100));
    expect(monthValue, lessThan(300));
    expect(find.text('2 contracts'), findsOneWidget);

    // Switch to "all active": full values of both active contracts.
    await tester.tap(find.byKey(const ValueKey('costPeriod.allActive')));
    await tester.pumpAndSettle();
    expect(find.byKey(costKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(costKey)).data, 'EUR 300.00');
    expect(find.text('2 contracts'), findsOneWidget);
  });

  testWidgets('cost period selection persists per tenant', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dashboard.costPeriod.7': 'year',
    });
    final api = _FakeApiService(contracts: [], contractors: []);
    final contracts = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // Restored from prefs: the "Year" pill is highlighted (primary
    // fill) while "Month" is not.
    final theme =
        Theme.of(tester.element(find.byKey(const Key('costSection'))));
    Container _pill(String key) => tester.widget<Container>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Container),
          ),
        );
    final yearDeco = _pill('costPeriod.year').decoration! as BoxDecoration;
    final monthDeco = _pill('costPeriod.month').decoration! as BoxDecoration;
    expect(yearDeco.color, theme.colorScheme.primary);
    expect(monthDeco.color, isNot(theme.colorScheme.primary));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dashboard.costPeriod.7'), 'year');
  });

  testWidgets('cost section shows empty state without active costs',
      (tester) async {
    final api = _FakeApiService(
      contracts: [
        _contract(1, 'Gone', status: 'Expired', value: '500'),
      ],
      contractors: [],
    );
    final contracts = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('costSection')), findsOneWidget);
    expect(find.text('No active contract costs in this period'), findsOneWidget);
    expect(find.byKey(const ValueKey('cost.')), findsNothing);
  });
}
