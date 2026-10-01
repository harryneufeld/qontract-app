import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/main.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/session_notifier.dart';
import 'package:qontract_app/screens/tenant/tenants_screen.dart';
import 'package:qontract_app/screens/login/register_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

User _user(int tenant, {String role = 'User'}) => User(
    id: 1,
    name: 'Member',
    email: 'member@example.com',
    role: role,
    tenantId: tenant,
    createdAt: DateTime.utc(2025));

class _Api extends ApiService {
  _Api({this.admin = false}) : super(baseUrl: 'http://localhost');
  final bool admin;
  bool failSwitch = false;
  Completer<User>? pendingMe;
  Map<String, dynamic>? registration;
  @override
  Future<AuthResult> register(Map<String, dynamic> fields) async {
    registration = fields;
    return AuthResult(token: 'registered', user: _user(2));
  }

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult(
      token: 'initial', user: _user(1, role: admin ? 'TenantAdmin' : 'User'));
  @override
  Future<User> me() async =>
      pendingMe == null ? _user(1) : await pendingMe!.future;
  @override
  Future<AuthResult> switchTenant(int tenantId) async {
    if (failSwitch) {
      throw ApiException(message: 'Tenant is unavailable.', statusCode: 404);
    }
    return AuthResult(token: 'switched', user: _user(tenantId));
  }

  @override
  Future<AuthResult> redeemInvitation(String code) async =>
      AuthResult(token: 'invited', user: _user(2));
  @override
  Future<void> logout() async {}
  @override
  Future<List<Map<String, dynamic>>> getMemberships() async => [
        {
          'tenantId': 1,
          'name': 'First family',
          'role': admin ? 'TenantAdmin' : 'User',
          'type': 'Family'
        },
        {
          'tenantId': 2,
          'name': 'Second family',
          'role': 'User',
          'type': 'Family'
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> getTenantMembers(int tenantId) async => [
        {
          'id': 1,
          'name': 'Member',
          'email': 'member@example.com',
          'role': 'TenantAdmin',
          'isActive': true
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> getTenantInvitations(int tenantId) async =>
      [];
}

class _RealHttp extends HttpOverrides {}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('successful switch persists the selected tenant and role', () async {
    final api = _Api();
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    expect(await auth.switchTenant(2), true);
    expect(auth.user!.tenantId, 2);
    expect((await StorageService().getUser())!.tenantId, 2);
    expect(auth.user!.role, 'User');
  });

  test('failed switch preserves the current session', () async {
    final api = _Api()..failSwitch = true;
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    expect(await auth.switchTenant(2), false);
    expect(auth.user!.tenantId, 1);
    expect(auth.errorMessage, 'Tenant is unavailable.');
    expect((await StorageService().getUser())!.tenantId, 1);
  });

  test('a late session restore cannot overwrite a successful switch', () async {
    final api = _Api()..pendingMe = Completer<User>();
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    final restoring = auth.checkSession();
    await Future<void>.delayed(Duration.zero);
    expect(await auth.switchTenant(2), true);
    api.pendingMe!.complete(_user(1));
    await restoring;
    expect(auth.user!.tenantId, 2);
    expect((await StorageService().getUser())!.tenantId, 2);
  });

  test('disposed tenant providers ignore late notifications', () {
    final provider = SessionNotifier();
    provider.dispose();
    expect(provider.notifyListeners, returnsNormally);
  });

  testWidgets('switching tenant scope discards cached contract selection',
      (tester) async {
    late ContractProvider provider;
    Widget scope(String key) => TenantScope(
        key: ValueKey(key),
        child: MaterialApp(home: Builder(builder: (context) {
          provider = context.read<ContractProvider>();
          return Text(provider.selectedContract?.title ?? 'No selection');
        })));
    await tester.pumpWidget(scope('first'));
    final old = provider;
    old.setSelectedContract(Contract(
        id: 1,
        title: 'Private first-tenant contract',
        status: 'Active',
        createdAt: DateTime.utc(2025),
        modifiedAt: DateTime.utc(2025)));
    await tester.pumpWidget(scope('second'));
    expect(identical(provider, old), false);
    expect(provider.selectedContract, null);
    expect(find.text('Private first-tenant contract'), findsNothing);
    expect(old.notifyListeners, returnsNormally);
  });

  testWidgets(
      'ordinary members can switch and join but cannot administer tenants',
      (tester) async {
    final api = _Api();
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tenantSwitcher')), findsOneWidget);
    expect(find.text('Accept invitation'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    expect(find.text('Members'), findsNothing);
  });

  testWidgets('tenant administrators see member and invitation management',
      (tester) async {
    final api = _Api(admin: true);
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No invitations yet.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('No invitations yet.'), findsOneWidget);
  });

  testWidgets(
      'invitation signup sends the code without creating another tenant',
      (tester) async {
    final api = _Api();
    final auth = AuthProvider(api: api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
            home: const RegisterScreen(invitationOnly: true),
            routes: {
              '/dashboard': (_) => const Scaffold(body: Text('Joined'))
            })));
    await tester.enterText(find.byKey(const Key('registerName')), 'New member');
    await tester.enterText(
        find.byKey(const Key('registerEmail')), 'new@example.com');
    await tester.enterText(
        find.byKey(const Key('registerPassword')), 'strong-password');
    await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Confirm password'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'strong-password');
    await tester.scrollUntilVisible(find.byKey(const Key('registerCode')), 180,
        scrollable: find.byType(Scrollable).first);
    final code = List.filled(64, 'A').join();
    await tester.enterText(find.byKey(const Key('registerCode')), code);
    await tester.scrollUntilVisible(find.text('Join tenant'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Join tenant'));
    await tester.pumpAndSettle();
    expect(api.registration!['invitationCode'], code);
    expect(api.registration!.containsKey('tenantName'), false);
    expect(auth.user!.tenantId, 2);
    expect(find.text('Joined'), findsOneWidget);
  });

  test('late 401 from a previous tenant does not clear the replacement token',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'old-token'});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final started = Completer<HttpRequest>();
      final callback = ApiService.onUnauthorized;
      var unauthorized = false;
      ApiService.onUnauthorized = () => unauthorized = true;
      server.listen((request) async {
        if (request.uri.path.endsWith('/contracts')) {
          started.complete(request);
        } else if (request.uri.path.endsWith('/auth/switch-tenant')) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(
              {'accessToken': 'new-token', 'user': _user(2).toJson()}));
          await request.response.close();
        }
      });
      try {
        final api = ApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');
        final oldRequest = api.getContracts();
        final expectedFailure =
            expectLater(oldRequest, throwsA(isA<ApiException>()));
        final request = await started.future;
        expect(request.headers.value('Authorization'), 'Bearer old-token');
        await api.switchTenant(2);
        request.response.statusCode = 401;
        await request.response.close();
        await expectedFailure;
        expect(await api.getToken(), 'new-token');
        expect(unauthorized, false);
      } finally {
        ApiService.onUnauthorized = callback;
        await server.close(force: true);
      }
    }, _RealHttp());
  });
}
