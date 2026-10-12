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

Contractor _contractor(int id, String name) => Contractor(
      id: id,
      name: name,
      type: ContractorType.individual,
      tenantId: 7,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

Contract _contract(
  int id,
  String title, {
  String status = 'Active',
  String? endDate,
  int? contractorId,
}) =>
    Contract(
      id: id,
      title: title,
      status: status,
      endDate: endDate,
      contractorId: contractorId,
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
  Future<List<Contract>> getContracts(
      {int page = 0, int pageSize = 0, String? status}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts.sublist(
        start, (start + pageSize).clamp(0, _contracts.length));
  }

  @override
  Future<List<Contract>> getContractList() async => _contracts;
  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

  @override
  Future<List<Contractor>> getContractors() async => _contractors;
}

/// Builds an already-authenticated AuthProvider by seeding a user in
/// shared prefs and validating it through [AuthProvider.checkSession]
/// against the fake API.
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
      child: const ContractListScreen(),
    ),
  );
}

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

  testWidgets('status chips wrap and toggle contract results', (tester) async {
    final now = DateTime.now();
    String plus(int days) => _iso(now.add(Duration(days: days)));
    final api = _FakeApiService(
      contracts: [
        _contract(1, 'One', endDate: plus(16), contractorId: 10),
        _contract(2, 'Two',
            status: 'Expired', endDate: plus(-5), contractorId: 20),
        _contract(3, 'Three', contractorId: 20),
      ],
      contractors: [
        _contractor(10, 'Acme'),
        _contractor(20, 'Beta'),
      ],
    );
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // Workflow states are filters, with no dashboard statistics attached.
    for (final key in [
      'statTotal',
      'statActive',
      'statExpired',
      'statTerminated',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: 'chip $key');
    }

    // Tapping "Expired" filters the list down to the expired contract.
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    await _showDashboard(tester, find.text('Two'));
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Three'), findsNothing);

    await _showDashboard(tester, find.byKey(const Key('statExpired')),
        delta: -200);
    // Tapping again clears the filter (toggle).
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    await _showDashboard(tester, find.text('One'));
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('additional filters are staged and cancellation keeps the view',
      (tester) async {
    final api = _FakeApiService(contracts: [], contractors: []);
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // Secondary filters appear only in the staged panel.
    expect(find.byKey(const Key('contractorFilter')), findsNothing);

    await tester.tap(find.byKey(const Key('openFilters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contractorFilter')), findsOneWidget);
    expect(find.byKey(const Key('endingFilter')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('reviewBillingFilter')));
    await tester.tap(find.byKey(const Key('reviewBillingFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contractorFilter')), findsNothing);
    expect(find.byKey(const Key('clearFilters')), findsNothing);
  });

  testWidgets('clear-filters button resets status filter', (tester) async {
    final now = DateTime.now();
    String plus(int days) => _iso(now.add(Duration(days: days)));
    final api = _FakeApiService(
      contracts: [
        _contract(1, 'One',
            status: 'Active', endDate: plus(16), contractorId: 10),
        _contract(2, 'Two',
            status: 'Active', endDate: plus(120), contractorId: 20),
      ],
      contractors: [
        _contractor(10, 'Acme'),
        _contractor(20, 'Beta'),
      ],
    );
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(_harness(
        auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // Apply status filter "active" via chip.
    await tester.tap(find.byKey(const Key('statActive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clearFilters')), findsOneWidget);

    // Clear it with the clear-filters button beside the active filter selections.
    await tester.tap(find.byKey(const Key('clearFilters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clearFilters')), findsNothing);
    // Both contracts visible again.
    await _showDashboard(tester, find.text('One'));
    expect(find.text('One'), findsOneWidget);
    await _showDashboard(tester, find.text('Two'));
    expect(find.text('Two'), findsOneWidget);
  });
}
