import 'dart:convert';

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

/// Fake of the NEW backend (app#36): honours the `?status=` bucket filter
/// server-side and serves the full unpaginated list to
/// [getContractList], mirroring GET /contracts without parameters.
class _StatusFakeApi extends ApiService {
  _StatusFakeApi({
    required List<Contract> contracts,
    required List<Contractor> contractors,
  })  : _contracts = contracts,
        _contractors = contractors,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;

  /// Every `status` value the provider requested (null = unfiltered).
  final List<String?> requestedStatuses = [];

  List<Contract> _filter(String? status) {
    switch (status) {
      case null:
        return List.of(_contracts);
      case 'active':
        return _contracts.where((c) => c.status == 'Active').toList();
      case 'expiring':
        return _contracts
            .where((c) => c.isExpiringSoon && !c.isExpired)
            .toList();
      case 'expired':
        return _contracts
            .where((c) => c.isExpired || c.status == 'Expired')
            .toList();
      case 'minDate':
        return _contracts
            .where((c) =>
                c.status == 'Active' &&
                c.reachesMinimumContractDateIn(days: 90))
            .toList();
      default:
        throw StateError('unexpected status filter: $status');
    }
  }

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts(
      {int page = 0, int pageSize = 0, String? status}) async {
    requestedStatuses.add(status);
    final list = _filter(status);
    if (page == 0 || pageSize == 0) return list;
    final start = (page - 1) * pageSize;
    if (start >= list.length) return [];
    return list.sublist(start, (start + pageSize).clamp(0, list.length));
  }

  @override
  Future<List<Contract>> getContractList() async => List.of(_contracts);

  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

  @override
  Future<List<Contractor>> getContractors() async => _contractors;
}

Future<AuthProvider> _seededAuth(ApiService api) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
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

Contract _contract(
  int id,
  String title, {
  String status = 'Active',
  String? value,
  String? startDate,
  String? endDate,
}) =>
    Contract(
      id: id,
      title: title,
      status: status,
      value: value,
      currency: 'EUR',
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'status chip fetches ALL matching contracts server-side, '
      'not just the loaded page (app#36)', (tester) async {
    // 26 contracts, page size 20: only the first page is loaded at first.
    // The three expired contracts are spread across BOTH pages, so a
    // client-side-only filter could only see the one on page 1.
    final now = DateTime.now();
    final contracts = <Contract>[
      for (var i = 1; i <= 15; i++)
        _contract(i, 'C$i', endDate: _iso(now.add(const Duration(days: 100)))),
      _contract(16, 'Expired A',
          endDate: _iso(now.subtract(const Duration(days: 1)))),
      for (var i = 17; i <= 22; i++)
        _contract(i, 'C$i', endDate: _iso(now.add(const Duration(days: 100)))),
      _contract(23, 'Expired B',
          endDate: _iso(now.subtract(const Duration(days: 1)))),
      for (var i = 24; i <= 25; i++)
        _contract(i, 'C$i', endDate: _iso(now.add(const Duration(days: 100)))),
      _contract(26, 'Expired C',
          status: 'Expired', endDate: _iso(now.add(const Duration(days: 100)))),
    ];
    final api = _StatusFakeApi(contracts: contracts, contractors: []);
    final contractsProvider = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth(api);
    await tester.pumpWidget(_harness(auth: auth,
        contracts: contractsProvider, contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // First page loaded: 20 of 26, "Load more" available.
    expect(contractsProvider.contracts.length, 20);
    expect(contractsProvider.hasMore, isTrue);
    // Only Expired A (page 1) of the three is in the loaded slice.
    // (The list is lazy, so check the provider state, not the viewport.)
    expect(contractsProvider.contracts.any((c) => c.title == 'Expired A'),
        isTrue);
    expect(contractsProvider.contracts.any((c) => c.title == 'Expired B'),
        isFalse);
    expect(contractsProvider.contracts.any((c) => c.title == 'Expired C'),
        isFalse);

    // Tap the "Expired" chip: a NEW server-side query must bring in ALL
    // three expired contracts, even the ones beyond page 1.
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();

    expect(api.requestedStatuses.last, 'expired');
    expect(find.text('Expired A'), findsOneWidget);
    expect(find.text('Expired B'), findsOneWidget);
    expect(find.text('Expired C'), findsOneWidget);
    expect(find.text('C1'), findsNothing);

    // Toggle the chip off: back to the unfiltered list (no status param).
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(api.requestedStatuses.last, isNull);
    expect(find.text('C1'), findsOneWidget);
    expect(contractsProvider.contracts.length, 20);
  });

  testWidgets(
      'cost summary covers the whole tenant, not the loaded page, '
      'and ignores active filters (app#36)', (tester) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    // 25 contracts, page size 20. Page 1 holds 19 value-10 actives and
    // one value-less expired contract; page 2 holds one value-10 active,
    // one value-less expired contract and three value-100 actives.
    // Tenant-wide: 20 x 10 + 3 x 100 = 500 EUR over 23 active contracts.
    // The loaded slice alone would show only 19 x 10 = 190 over 19.
    final list = <Contract>[
      for (var i = 1; i <= 10; i++)
        _contract(i, 'C$i',
            value: '10',
            startDate: _iso(monthStart),
            endDate: _iso(monthEnd)),
      _contract(11, 'Expired A',
          endDate: _iso(now.subtract(const Duration(days: 1)))),
      for (var i = 12; i <= 19; i++)
        _contract(i, 'C$i',
            value: '10',
            startDate: _iso(monthStart),
            endDate: _iso(monthEnd)),
      _contract(20, 'C20',
          value: '10',
          startDate: _iso(monthStart),
          endDate: _iso(monthEnd)),
      _contract(21, 'C21',
          value: '10',
          startDate: _iso(monthStart),
          endDate: _iso(monthEnd)),
      _contract(22, 'Expired B',
          status: 'Expired', endDate: _iso(now.add(const Duration(days: 100)))),
      for (var i = 23; i <= 25; i++)
        _contract(i, 'C$i',
            value: '100',
            startDate: _iso(monthStart),
            endDate: _iso(monthEnd)),
    ];
    final api = _StatusFakeApi(contracts: list, contractors: []);
    final contractsProvider = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth(api);
    await tester.pumpWidget(_harness(auth: auth,
        contracts: contractsProvider, contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // Only page 1 (20 rows) is loaded; the three value-100 actives and
    // one value-10 active sit on page 2. The tenant-wide set must drive
    // the summary: 20x10 + 3x100.
    expect(contractsProvider.contracts.length, 20);
    expect(contractsProvider.costContracts.length, 25);
    const costKey = ValueKey('cost.EUR');
    expect(tester.widget<Text>(find.byKey(costKey)).data, 'EUR 500.00');
    expect(find.text('23 contracts'), findsOneWidget);

    // Applying a status filter must NOT change the cost summary: it is
    // computed over the tenant-wide set, not the filtered view.
    await tester.tap(find.byKey(const Key('statActive')));
    await tester.pumpAndSettle();
    expect(api.requestedStatuses.last, 'active');
    expect(tester.widget<Text>(find.byKey(costKey)).data, 'EUR 500.00');
    expect(find.text('23 contracts'), findsOneWidget);
  });
}
