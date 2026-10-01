import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/models/address.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/contract/contract_detail_screen.dart';
import 'package:qontract_app/screens/contractor/address_editor_dialog.dart';
import 'package:qontract_app/screens/contractor/contractor_list_screen.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

/// Regression tests for app#33:
///  1. address form: entered street is actually saved (was sent as null)
///  2. contract detail: field values use a theme-aware (dark) background
///  3. contractors page: per-contractor count is the server-side total
///  4. dashboard: stat chips use tenant-wide totals, not the loaded page
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ------------------------------------------------------------ bug 1
  testWidgets('address dialog: entered fields are saved (app#33)',
      (tester) async {
    Address? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAddressEditorDialog(
                  context,
                  contractorId: 5,
                  address: null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Field order: Street, ZIP, City, Country.
    await tester.enterText(find.byType(TextFormField).at(0), 'Musterstr. 5');
    await tester.enterText(find.byType(TextFormField).at(1), '10115');
    await tester.enterText(find.byType(TextFormField).at(2), 'Berlin');
    await tester.enterText(find.byType(TextFormField).at(3), 'Germany');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(result, isNotNull, reason: 'dialog should pop the new address');
    // The street must be the entered value — previously the draft was
    // never synced from the controller, so this was null and the
    // backend rejected the create with "Street is required".
    expect(result!.street, 'Musterstr. 5');
    expect(result!.zip, '10115');
    expect(result!.city, 'Berlin');
    expect(result!.country, 'Germany');
    expect(result!.contractorId, 5);
  });

  testWidgets('address dialog: edit keeps untouched fields (app#33)',
      (tester) async {
    const existing = Address(
      id: 9,
      street: 'Old St 1',
      city: 'Old City',
      zip: '12345',
      country: 'Germany',
      contractorId: 5,
    );
    Address? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAddressEditorDialog(
                  context,
                  contractorId: 5,
                  address: existing,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New St 2');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.street, 'New St 2');
    expect(result!.city, 'Old City', reason: 'untouched fields must be kept');
    expect(result!.zip, '12345');
    expect(result!.id, 9);
  });

  // ------------------------------------------------------------ bug 2
  testWidgets('dark mode: contract detail uses dark field backgrounds',
      (tester) async {
    final contract = Contract(
      id: 1,
      title: 'Detail',
      status: 'Active',
      value: '123.45',
      currency: 'EUR',
      startDate: '2026-01-01',
      endDate: '2027-01-01',
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );
    final api = _FakeApiService(
        contracts: [contract], contractors: [], stats: null);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ContractorProvider>.value(
                value: ContractorProvider(api: api)),
            ChangeNotifierProvider<DocumentProvider>.value(
                value: DocumentProvider(api: api)),
            ChangeNotifierProvider<ContractProvider>.value(
                value: ContractProvider(api: api)),
          ],
          child: ContractDetailScreen(contract: contract),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expected = AppTheme.dark.colorScheme.surfaceContainerHighest;
    final darkBoxes = find.byWidgetPredicate(
        (w) => w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == expected);
    expect(darkBoxes, findsWidgets,
        reason: 'field value boxes must use the dark surface token');

    final lightBoxes = find.byWidgetPredicate(
        (w) => w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == Colors.grey[100]);
    expect(lightBoxes, findsNothing,
        reason: 'hard-coded light background must be gone');
  });

  // ------------------------------------------------------------ bug 3
  testWidgets('contractors page: count is the server-side total (app#33)',
      (tester) async {
    // 25 contracts for contractor 1 — only the first 20 are loaded, but
    // the tile must show the server-side total of 25.
    final api = _FakeApiService(
      contracts: List.generate(25,
          (i) => _contract(i + 1, contractorId: 1)),
      contractors: [_contractor(1, 'Acme', contractCount: 25)],
      stats: null,
    );
    final contracts = ContractProvider(api: api);
    await contracts.fetchContracts();
    expect(contracts.contracts, hasLength(ContractProvider.pageSize));
    expect(contracts.hasMore, isTrue);

    await _pumpContractorList(tester, api, contracts);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('25'), findsOneWidget,
        reason: 'count must come from the server total, not the loaded page');
  });

  testWidgets('contractors page: fallback to slice when backend has no '
      'contractCount and the list is complete (app#33)', (tester) async {
    final api = _FakeApiService(
      contracts: [
        _contract(1, contractorId: 1),
        _contract(2, contractorId: 1),
      ],
      contractors: [_contractor(1, 'Acme', contractCount: 0)],
      stats: null,
    );
    final contracts = ContractProvider(api: api);
    await contracts.fetchContracts();
    expect(contracts.hasMore, isFalse);

    await _pumpContractorList(tester, api, contracts);
    expect(find.text('2'), findsOneWidget,
        reason: 'with a fully loaded slice the old counting still works');
  });

  testWidgets('contractors page: no count when slice is partial and '
      'backend has no contractCount (app#33)', (tester) async {
    final api = _FakeApiService(
      contracts: List.generate(25, (i) => _contract(i + 1, contractorId: 1)),
      contractors: [_contractor(1, 'Acme', contractCount: 0)],
      stats: null,
    );
    final contracts = ContractProvider(api: api);
    await contracts.fetchContracts();
    expect(contracts.hasMore, isTrue);

    await _pumpContractorList(tester, api, contracts);
    expect(find.text('20'), findsNothing,
        reason: 'a partial slice must not be shown as the total');
  });

  // ------------------------------------------------------------ bug 4
  testWidgets('dashboard: stat chips use tenant-wide stats (app#33)',
      (tester) async {
    final api = _FakeApiService(
      contracts: [
        _contract(1, contractorId: 1),
        _contract(2, contractorId: 1),
        _contract(3, contractorId: 1),
      ],
      contractors: [_contractor(1, 'Acme', contractCount: 3)],
      stats: const ContractStats(
        total: 100,
        active: 40,
        expiring: 5,
        expired: 10,
        minDateApproaching: 2,
      ),
    );
    final contracts = ContractProvider(api: api);
    final auth = await _seededAuth();
    await _pumpDashboard(tester, auth, api, contracts);
    await tester.pumpAndSettle();

    // Only 3 contracts are loaded — the chips must show the tenant-wide
    // totals from GET /contracts/stats, not the slice counts.
    _expectChip(tester, 'statTotal', '100');
    _expectChip(tester, 'statActive', '40');
    _expectChip(tester, 'statExpiring', '5');
    _expectChip(tester, 'statExpired', '10');
    _expectChip(tester, 'statMinDate', '2');
  });

  testWidgets('dashboard: falls back to slice counts without stats '
      'endpoint (app#33)', (tester) async {
    // stats: null -> the fake throws 404, mirroring an older backend.
    final api = _FakeApiService(
      contracts: [
        _contract(1, contractorId: 1),
        _contract(2, contractorId: 1),
        _contract(3, contractorId: 1),
      ],
      contractors: [_contractor(1, 'Acme', contractCount: 3)],
      stats: null,
    );
    final contracts = ContractProvider(api: api);
    final auth = await _seededAuth();
    await _pumpDashboard(tester, auth, api, contracts);
    await tester.pumpAndSettle();

    _expectChip(tester, 'statTotal', '3');
    _expectChip(tester, 'statActive', '3');
    _expectChip(tester, 'statExpired', '0');
  });
}

// --------------------------------------------------------------- helpers

User _user() => User(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      role: 'User',
      tenantId: 7,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Contractor _contractor(int id, String name, {int contractCount = 0}) =>
    Contractor(
      id: id,
      name: name,
      type: ContractorType.individual,
      tenantId: 7,
      isActive: true,
      contractCount: contractCount,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

Contract _contract(int id, {int? contractorId}) => Contract(
      id: id,
      title: 'Contract $id',
      status: 'Active',
      contractorId: contractorId,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

/// Fake API: serves canned contracts/contractors and an optional stats
/// payload (null -> 404, like a backend without the stats endpoint).
class _FakeApiService extends ApiService {
  _FakeApiService({
    required List<Contract> contracts,
    required List<Contractor> contractors,
    required ContractStats? stats,
  })  : _contracts = contracts,
        _contractors = contractors,
        _stats = stats,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;
  final ContractStats? _stats;

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0, String? status}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts
        .sublist(start, (start + pageSize).clamp(0, _contracts.length));
  }

  @override
  Future<List<Contract>> getContractList() async => _contracts;

  @override
  Future<ContractStats> getContractStats() async {
    final stats = _stats;
    if (stats == null) {
      throw ApiException(message: 'Not Found.', statusCode: 404);
    }
    return stats;
  }

  @override
  Future<List<Contractor>> getContractors() async => _contractors;
}

Future<AuthProvider> _seededAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
  final api = _FakeApiService(contracts: [], contractors: [], stats: null);
  final auth = AuthProvider(api: api, storage: StorageService());
  await auth.checkSession();
  return auth;
}

Future<void> _pumpContractorList(
  WidgetTester tester,
  _FakeApiService api,
  ContractProvider contracts,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ContractProvider>.value(value: contracts),
          ChangeNotifierProvider<ContractorProvider>.value(
              value: ContractorProvider(api: api)),
        ],
        child: const ContractorListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  AuthProvider auth,
  _FakeApiService api,
  ContractProvider contracts,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ContractProvider>.value(value: contracts),
          ChangeNotifierProvider<ContractorProvider>.value(
              value: ContractorProvider(api: api)),
        ],
        child: const DashboardScreen(),
      ),
    ),
  );
}

void _expectChip(WidgetTester tester, String key, String value) {
  expect(
    find.descendant(of: find.byKey(Key(key)), matching: find.text(value)),
    findsOneWidget,
    reason: 'chip $key should show $value',
  );
}
