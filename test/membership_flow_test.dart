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
  final appliedCurrencies = <bool>[];
  @override
  Future<int> applyTenantCurrency(int id,
      {bool replaceExisting = false}) async {
    appliedCurrencies.add(replaceExisting);
    return 7;
  }

  @override
  Future<List<Contract>> getContracts(
          {int page = 0, int pageSize = 0, String? status}) async =>
      [];
  @override
  Future<List<Contract>> getContractList() async => [];
  @override
  Future<Map<String, dynamic>> getTenantDetails(int tenantId) async => {
        'id': tenantId,
        'settings': jsonEncode({'documentRetentionDays': 60, ...?savedSettings})
      };
  Map<String, dynamic>? savedSettings;
  @override
  Future<void> updateTenantSettings(int id, String settings) async {
    savedSettings = jsonDecode(settings) as Map<String, dynamic>;
  }

  bool failSwitch = false;
  bool noMemberships = false;
  Completer<User>? pendingMe;
  Map<String, dynamic>? registration;
  ({String name, String type})? createdTenant;
  @override
  Future<Map<String, dynamic>> createTenant(String name, String type) async {
    createdTenant = (name: name, type: type);
    return {'id': 3, 'name': name, 'type': type};
  }

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
  Future<List<Map<String, dynamic>>> getMemberships() async => noMemberships
      ? []
      : [
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
          if (createdTenant != null)
            {
              'tenantId': 3,
              'name': createdTenant!.name,
              'role': 'TenantAdmin',
              'type': createdTenant!.type,
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

  testWidgets(
      'tenant currency preserves settings and bulk replacement is explicit',
      (tester) async {
    final api = _Api(admin: true);
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
    ], child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, 'Default currency');
    await tester.scrollUntilVisible(tile, 160,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.tap(find.descendant(of: tile, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        ' usd ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(api.savedSettings,
        {'documentRetentionDays': 60, 'defaultCurrency': 'USD'});
    Future<void> open() async {
      await tester.ensureVisible(find.text('Apply currency to contracts'));
      await tester.tap(find.text('Apply currency to contracts'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.appliedCurrencies, isEmpty);
    await open();
    await tester.tap(find.text('Fill missing currencies'));
    await tester.pumpAndSettle();
    expect(api.appliedCurrencies, [false]);
    await open();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to all'));
    await tester.pumpAndSettle();
    expect(api.appliedCurrencies, [false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant retention changes preserve other settings',
      (tester) async {
    final api = _Api(admin: true);
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, 'Contract deletion retention');
    await tester.scrollUntilVisible(tile, 160,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.tap(find.descendant(of: tile, matching: find.text('Change')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        '120');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(api.savedSettings,
        {'documentRetentionDays': 60, 'contractRetentionDays': 120});
    expect(find.text('120 days · changes apply to future deletions'),
        findsOneWidget);
  });

  testWidgets('switching to Personal persists workspace and opens dashboard',
      (tester) async {
    final api = _Api(admin: true);
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(home: TenantsScreen(api: api), routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Personal dashboard'))
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tenantSwitcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
    expect(auth.user!.isPersonal, true);
    expect(auth.user!.role, 'User');
    expect((await StorageService().getUser())!.tenantId, 0);
    expect(find.text('Personal dashboard'), findsOneWidget);
  });

  testWidgets('Personal remains usable without tenant memberships',
      (tester) async {
    final api = _Api()..noMemberships = true;
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await auth.switchTenant(0);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    expect(
        find.text(
            'Only you can access contracts, contractors and documents created here.'),
        findsOneWidget);
    expect(find.text('Accept invitation'), findsOneWidget);
    expect(find.text('Members'), findsNothing);
    expect(find.text('Create another tenant'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    await tester.scrollUntilVisible(find.text('Invite'), 150,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Create another tenant'), findsOneWidget);
    expect(find.text('Create another family'), findsNothing);
    await tester.tap(find.text('Create another tenant'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant name'), findsOneWidget);
    expect(find.text('Family name'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No invitations yet.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('No invitations yet.'), findsOneWidget);
  });

  for (final type in ['Family', 'Company']) {
    testWidgets('creating a $type tenant sends its type and switches workspace',
        (tester) async {
      final api = _Api(admin: true);
      final auth = AuthProvider(api: api);
      await auth.login('member@example.com', 'password');
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Create another tenant'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Create another tenant'));
      await tester.pumpAndSettle();
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Family'), findsNothing);
      await tester.enterText(
          find.byKey(const Key('createTenantName')), '  New workspace  ');
      if (type == 'Company') {
        await tester.tap(find.byKey(const Key('createTenantType')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Company').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Create tenant'));
      await tester.pumpAndSettle();
      expect(api.createdTenant, (name: 'New workspace', type: type));
      expect(auth.user!.tenantId, 3);
      expect((await StorageService().getUser())!.tenantId, 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'tenant creation validates the name and cancellation writes nothing',
      (tester) async {
    final api = _Api(admin: true);
    final auth = AuthProvider(api: api);
    await auth.login('member@example.com', 'password');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth, child: MaterialApp(home: TenantsScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create another tenant'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create another tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('createTenantName')), '   ');
    await tester.tap(find.text('Create tenant'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a tenant name.'), findsOneWidget);
    expect(api.createdTenant, isNull);
    await tester.tap(find.byKey(const Key('createTenantType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.createdTenant, isNull);
    expect(auth.user!.tenantId, 1);
    expect(tester.takeException(), isNull);
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
