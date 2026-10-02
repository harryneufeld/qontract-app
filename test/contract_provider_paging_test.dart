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

User _user() => User(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      role: 'User',
      tenantId: 7,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Contract _contract(int id) => Contract(
      id: id,
      title: 'Contract $id',
      status: 'Active',
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

/// Simulates the backend's offset paging (issue #21 / backend#43):
/// `page`/`pageSize` are 1-based and optional.
class _FakeApiService extends ApiService {
  _FakeApiService(this._contracts) : super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;

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
  Future<List<Contractor>> getContractors() async => [];
}

Future<AuthProvider> _seededAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
  final api = _FakeApiService([]);
  final auth = AuthProvider(api: api, storage: StorageService());
  await auth.checkSession();
  return auth;
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

  test('loadMore appends the next page; hasMore clears at the end', () async {
    // 25 contracts -> page 1 (20) + a short page 2 (5).
    final all = List.generate(25, _contract);
    final provider = ContractProvider(api: _FakeApiService(all));

    await provider.fetchContracts();
    expect(provider.contracts, hasLength(ContractProvider.pageSize));
    expect(provider.hasMore, isTrue, reason: 'full first page implies more');

    await provider.loadMore();
    expect(provider.contracts, hasLength(25));
    expect(provider.hasMore, isFalse, reason: 'short second page is the end');

    // A further loadMore is a no-op once the end is reached.
    await provider.loadMore();
    expect(provider.contracts, hasLength(25));
  });

  test('fetchContracts is bounded to one page for a large dataset', () async {
    final provider =
        ContractProvider(api: _FakeApiService(List.generate(200, _contract)));
    await provider.fetchContracts();
    expect(provider.contracts, hasLength(ContractProvider.pageSize));
    expect(provider.hasMore, isTrue);
  });

  testWidgets('dashboard shows Load more and appends the next page',
      (tester) async {
    final all = List.generate(25, _contract);
    final api = _FakeApiService(all);
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ContractProvider>.value(value: contracts),
            ChangeNotifierProvider<ContractorProvider>.value(
                value: contractors),
          ],
          child: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the first page is loaded; the footer offers to load more.
    expect(contracts.contracts, hasLength(ContractProvider.pageSize));
    await _showDashboard(tester, find.byKey(const Key('loadMore')));
    expect(find.byKey(const Key('loadMore')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('loadMore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loadMore')));
    await tester.pumpAndSettle();

    // The short second page appended; footer is gone at the end.
    expect(contracts.contracts, hasLength(25));
    expect(find.byKey(const Key('loadMore')), findsNothing);
  });
}
