import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/account/account_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

/// Tests for the account page (app#11): the user can view their account
/// and change their password through the UI.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the signed-in account details (app#11)', (tester) async {
    final api = _FakeApi(contracts: [], contractors: []);
    final auth = await _seededAuth(api);
    await _pump(tester, api, auth);
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Role: User'), findsOneWidget);
    expect(find.text('Change password'), findsWidgets); // button label + section
  });

  testWidgets('rejects mismatched confirmation locally (app#11)', (tester) async {
    final api = _FakeApi(contracts: [], contractors: []);
    final auth = await _seededAuth(api);
    await _pump(tester, api, auth);
    await tester.pumpAndSettle();

    await _enter(tester, 'current1', 'newpass1', 'different1');
    await _tapButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(api.changePasswordCalls, 0); // never hit the API
  });

  testWidgets('rejects a new password shorter than 6 chars locally (app#11)',
      (tester) async {
    final api = _FakeApi(contracts: [], contractors: []);
    final auth = await _seededAuth(api);
    await _pump(tester, api, auth);
    await tester.pumpAndSettle();

    await _enter(tester, 'current1', 'abc', 'abc');
    await _tapButton(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    expect(api.changePasswordCalls, 0);
  });

  testWidgets('success path calls the API and reports changed (app#11)',
      (tester) async {
    final api = _FakeApi(contracts: [], contractors: []);
    api.changePasswordResult = true;
    final auth = await _seededAuth(api);
    await _pump(tester, api, auth);
    await tester.pumpAndSettle();

    await _enter(tester, 'current1', 'newpass1', 'newpass1');
    await _tapButton(tester);
    await tester.pumpAndSettle();

    expect(api.changePasswordCalls, 1);
    expect(api.lastCurrent, 'current1');
    expect(api.lastNew, 'newpass1');
    expect(find.text('Password changed.'), findsOneWidget);
    // Fields are cleared after success.
    for (final key in const [
      Key('currentPasswordField'),
      Key('newPasswordField'),
      Key('confirmPasswordField'),
    ]) {
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller?.text, isEmpty, reason: 'field $key not cleared');
    }
  });

  testWidgets('wrong current password surfaces the server error (app#11)',
      (tester) async {
    final api = _FakeApi(contracts: [], contractors: []);
    api.changePasswordException =
        ApiException(message: 'Current password is incorrect.', statusCode: 400);
    final auth = await _seededAuth(api);
    await _pump(tester, api, auth);
    await tester.pumpAndSettle();

    await _enter(tester, 'current1', 'newpass1', 'newpass1');
    await _tapButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
  });
}

// ---------------------------------------------------------------- helpers

Future<void> _pump(WidgetTester tester, _FakeApi api, AuthProvider auth) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ContractProvider>.value(
              value: ContractProvider(api: api)),
          ChangeNotifierProvider<ContractorProvider>.value(
              value: ContractorProvider(api: api)),
        ],
        child: const AccountScreen(),
      ),
    ),
  );
}

Future<void> _tapButton(WidgetTester tester) async {
  // The form is taller than the test viewport — scroll the submit button
  // into view before tapping.
  await tester.scrollUntilVisible(
    find.byKey(const Key('changePasswordButton')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('changePasswordButton')));
}

Future<void> _enter(
    WidgetTester tester, String current, String newPw, String confirm) async {
  await tester.enterText(find.byKey(const Key('currentPasswordField')), current);
  await tester.enterText(find.byKey(const Key('newPasswordField')), newPw);
  await tester.enterText(
      find.byKey(const Key('confirmPasswordField')), confirm);
  await tester.pumpAndSettle();
}

Future<AuthProvider> _seededAuth(_FakeApi api) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
  final auth = AuthProvider(api: api, storage: StorageService());
  await auth.checkSession();
  return auth;
}

User _user() => User(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      role: 'User',
      tenantId: 7,
      createdAt: DateTime.utc(2026, 1, 1),
    );

// ------------------------------------------------------------------- fakes

class _FakeApi extends ApiService {
  _FakeApi({
    required List<Contract> contracts,
    required List<Contractor> contractors,
  })  : _contracts = contracts,
        _contractors = contractors,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;

  // Change-password scripting.
  int changePasswordCalls = 0;
  String? lastCurrent;
  String? lastNew;
  bool changePasswordResult = true;
  Object? changePasswordException;

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    changePasswordCalls++;
    lastCurrent = currentPassword;
    lastNew = newPassword;
    final ex = changePasswordException;
    if (ex != null) throw ex;
    if (!changePasswordResult) {
      throw ApiException(message: 'Server error.', statusCode: 500);
    }
  }

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0, String? status}) async =>
      _contracts;

  @override
  Future<List<Contract>> getContractList() async => _contracts;

  @override
  Future<List<Contractor>> getContractors() async => _contractors;

  @override
  Future<Contract> createContract(Contract contract) async =>
      throw UnimplementedError();
}
