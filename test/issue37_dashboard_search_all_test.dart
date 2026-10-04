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
import 'package:qontract_app/screens/contract/contract_list_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
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

/// Fake backend mirroring GET /contracts: offset paging with optional
/// `?status=` bucket filter (app#36) and the full unpaginated list via
/// [getContractList].
class _FakeApi extends ApiService {
  _FakeApi({
    required List<Contract> contracts,
    required List<Contractor> contractors,
  })  : _contracts = contracts,
        _contractors = contractors,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;

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
      child: const ContractListScreen(),
    ),
  );
}

Contract _contract(int id, String title,
        {String status = 'Active', String? endDate}) =>
    Contract(
      id: id,
      title: title,
      status: status,
      currency: 'EUR',
      endDate: endDate,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _showDashboard(WidgetTester tester, Finder target,
    {double delta = 200}) async {
  await tester.scrollUntilVisible(target, delta,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'search covers ALL tenant contracts, not just the loaded page '
      '(app#37)', (tester) async {
    // 26 contracts, page size 20: only page 1 is loaded at first.
    // 'Searchable Alpha' sits on page 1, 'Searchable Beta' on page 2,
    // so a search over the loaded slice alone could only find Alpha.
    final future = DateTime.now().add(const Duration(days: 100));
    final contracts = <Contract>[
      _contract(1, 'Searchable Alpha', endDate: _iso(future)),
      for (var i = 2; i <= 20; i++) _contract(i, 'C$i', endDate: _iso(future)),
      _contract(21, 'Searchable Beta', endDate: _iso(future)),
      for (var i = 22; i <= 26; i++) _contract(i, 'C$i', endDate: _iso(future)),
    ];
    final api = _FakeApi(contracts: contracts, contractors: []);
    final contractsProvider = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth(api);
    await tester.pumpWidget(_harness(
        auth: auth,
        contracts: contractsProvider,
        contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // Page 1 only: 20 of 26 loaded, full tenant list fetched in background.
    expect(contractsProvider.contracts.length, 20);
    expect(contractsProvider.hasMore, isTrue);
    expect(contractsProvider.hasFullList, isTrue);
    expect(contractsProvider.costContracts.length, 26);
    expect(contractsProvider.contracts.any((c) => c.title == 'Searchable Beta'),
        isFalse);

    // The "Load more" footer is available for the plain list view...
    await _showDashboard(tester, find.byKey(const Key('loadMore')));
    expect(find.byKey(const Key('loadMore')), findsOneWidget);
    await _showDashboard(tester, find.byType(TextField), delta: -200);

    // ...but typing in the search field must find the page-2 match too.
    await tester.enterText(find.byType(TextField), 'Searchable');
    await tester.pumpAndSettle();

    expect(find.text('Searchable Alpha'), findsOneWidget);
    expect(find.text('Searchable Beta'), findsOneWidget);

    // The list is complete while searching, so the footer is hidden:
    // loading more list pages cannot add matches.
    expect(find.byKey(const Key('loadMore')), findsNothing);
  });

  testWidgets(
      'search composes with status and finds page-two results when status is cleared '
      '(app#37)', (tester) async {
    // The active page-two match is excluded by Expired, then appears
    // when the status is cleared without changing the search term.
    final now = DateTime.now();
    final future = _iso(now.add(const Duration(days: 100)));
    final contracts = <Contract>[
      _contract(1, 'Expired A',
          endDate: _iso(now.subtract(const Duration(days: 1)))),
      for (var i = 2; i <= 20; i++) _contract(i, 'C$i', endDate: future),
      _contract(21, 'Gamma Hidden', endDate: future),
      for (var i = 22; i <= 26; i++) _contract(i, 'C$i', endDate: future),
    ];
    final api = _FakeApi(contracts: contracts, contractors: []);
    final contractsProvider = ContractProvider(api: api);
    final contractorProvider = ContractorProvider(api: api);
    final auth = await _seededAuth(api);
    await tester.pumpWidget(_harness(
        auth: auth,
        contracts: contractsProvider,
        contractorProvider: contractorProvider));
    await tester.pumpAndSettle();

    // Activate the "Expired" chip: server-side refetch, the loaded slice
    // is now the single expired contract only.
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(api.requestedStatuses.last, 'expired');
    expect(contractsProvider.contracts, hasLength(1));
    expect(contractsProvider.contracts.first.title, 'Expired A');
    expect(find.text('Gamma Hidden'), findsNothing);

    // Search narrows the selected workflow state across the full tenant.
    await tester.enterText(find.byType(TextField), 'Gamma');
    await tester.pumpAndSettle();
    expect(find.text('Gamma Hidden'), findsNothing);
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('Expired A'), findsNothing);

    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(find.text('Gamma Hidden'), findsOneWidget);
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();

    // Clearing the search returns to the filtered view.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Gamma Hidden'), findsNothing);
    expect(find.text('Expired A'), findsOneWidget);
  });
}
