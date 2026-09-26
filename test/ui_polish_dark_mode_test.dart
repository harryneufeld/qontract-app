import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/contractor/contractor_list_screen.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';
import 'package:qontract_app/widgets/wordmark.dart';

/// Regression tests for app#32: dark-mode readability of contractor names
/// and the dashboard drawer header. Both must stay bound to the theme
/// (light text on dark surfaces) instead of hard-coded colours.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('dark mode: contractor name is theme-aware (app#32)',
      (tester) async {
    final api = _FakeApiService(
        contracts: [], contractors: [_contractor(1, 'Acme')]);
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ContractProvider>.value(value: contracts),
            ChangeNotifierProvider<ContractorProvider>.value(
                value: contractors),
          ],
          child: const ContractorListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text('Acme').first);
    expect(name.style?.color, AppTheme.dark.colorScheme.onSurface);
  });

  testWidgets('dark mode: drawer header text is theme-aware (app#32)',
      (tester) async {
    final api = _FakeApiService(contracts: [], contractors: []);
    final contracts = ContractProvider(api: api);
    final contractors = ContractorProvider(api: api);
    final auth = await _seededAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
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

    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();

    // app#23: the drawer header now carries the brand wordmark; in the
    // dark theme its "ontract" span must stay light (app#32 intent).
    final wordmarkText = tester.widget<Text>(
        find.descendant(of: find.byType(QontractWordmark),
            matching: find.byType(Text)));
    final wSpans = (wordmarkText.textSpan! as TextSpan)
        .children!
        .cast<TextSpan>()
        .toList();
    expect(wSpans.first.text, 'q');
    expect(wSpans.first.style!.color, Colors.black);
    expect(wSpans.last.text, 'ontract');
    expect(wSpans.last.style!.color, Colors.white);

    final email = tester.widget<Text>(find.text('test@example.com'));
    expect(email.style?.color, AppTheme.dark.colorScheme.onSurfaceVariant);
  });
}

// ---------------------------------------------------------------- fakes

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
