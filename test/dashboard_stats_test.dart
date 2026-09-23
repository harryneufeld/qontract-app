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
  Future<List<Contract>> getContracts() async => _contracts;

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
      child: const DashboardScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('stat chips are compact and tappable quick filters',
      (tester) async {
    final now = DateTime.now();
    final plus = (int days) => _iso(now.add(Duration(days: days)));
    final api = _FakeApiService(
      contracts: [
        _contract(1, 'One', endDate: plus(16), contractorId: 10),
        _contract(2, 'Two', status: 'Expired', endDate: plus(-5), contractorId: 20),
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
    await tester.pumpWidget(
        _harness(auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // All five stat chips render in the single horizontal row.
    for (final key in [
      'statTotal',
      'statActive',
      'statExpiring',
      'statExpired',
      'statMinDate',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: 'chip $key');
    }

    // Tapping "Expired" filters the list down to the expired contract.
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Three'), findsNothing);

    // Tapping again clears the filter (toggle).
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('expanding/collapsing persists per tenant', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dashboard.statsExpanded.7': false,
    });
    final api = _FakeApiService(contracts: [], contractors: []);
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(
        _harness(auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // Restored from prefs: secondary filters hidden.
    expect(find.byKey(const Key('contractorFilter')), findsNothing);

    // Expand.
    await tester.tap(find.byKey(const Key('statsExpand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contractorFilter')), findsOneWidget);
    expect(find.byKey(const Key('endingFilter')), findsOneWidget);

    // Expanded state persisted for tenant 7.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dashboard.statsExpanded.7'), isTrue);

    // Collapse again.
    await tester.tap(find.byKey(const Key('statsExpand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contractorFilter')), findsNothing);
    expect(prefs.getBool('dashboard.statsExpanded.7'), isFalse);
  });

  testWidgets('clear-filters button resets status filter', (tester) async {
    final now = DateTime.now();
    final plus = (int days) => _iso(now.add(Duration(days: days)));
    final api = _FakeApiService(
      contracts: [
        _contract(1, 'One', status: 'Active', endDate: plus(16), contractorId: 10),
        _contract(2, 'Two', status: 'Active', endDate: plus(120), contractorId: 20),
      ],
      contractors: [
        _contractor(10, 'Acme'),
        _contractor(20, 'Beta'),
      ],
    );
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(
        _harness(auth: auth, contracts: contracts, contractorProvider: contractors));
    await tester.pumpAndSettle();

    // Apply status filter "active" via chip.
    await tester.tap(find.byKey(const Key('statActive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clearFilters')), findsOneWidget);

    // Clear it with the clear-filters button in the overview header.
    await tester.tap(find.byKey(const Key('clearFilters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clearFilters')), findsNothing);
    // Both contracts visible again.
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
  });
}
