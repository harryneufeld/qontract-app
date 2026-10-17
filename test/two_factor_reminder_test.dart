import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/account/two_factor_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';
import 'package:qontract_app/config/api_config.dart';
import 'package:qontract_app/widgets/two_factor_reminder.dart';

final _user = User(
    id: 1,
    name: 'User',
    email: 'user@example.test',
    role: 'User',
    tenantId: 1,
    createdAt: DateTime.utc(2026));

class _Api extends ApiService {
  _Api({String? serverUrl}) : super(baseUrl: serverUrl);
  User currentUser = _user;
  bool enabled = false;
  bool fail = false;
  bool failLogin = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<AuthResult> login(String email, String password) async {
    if (failLogin) throw ApiException(message: 'Rejected');
    return AuthResult(token: 'token', user: currentUser);
  }

  @override
  Future<User> me() async => currentUser;
  @override
  Future<AuthResult> switchTenant(int tenantId) async =>
      AuthResult(token: 'replacement', user: _user);
  @override
  Future<void> logout() async {}
  @override
  Future<Map<String, dynamic>> twoFactorStatus() async {
    if (fail) throw ApiException(message: 'Offline');
    if (pending != null) return pending!.future;
    return {'enabled': enabled};
  }
}

void main() {
  late _Api api;
  late AuthProvider auth;
  tearDown(() => setSelectedApiBaseUrl(null));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    auth = AuthProvider(api: api);
    await auth.login('user@example.test', 'password');
  });

  test('dismissal is isolated by server and user, including API path and port',
      () async {
    final storage = StorageService();
    const server = 'https://one.example.test/api';
    await storage.setTwoFactorReminderDismissed(server, 1, true);
    expect(await storage.isTwoFactorReminderDismissed(server, 1), isTrue);
    for (final other in [
      'https://two.example.test/api',
      'http://one.example.test/api',
      'https://one.example.test:8443/api',
      'https://one.example.test/other/api',
    ]) {
      expect(await storage.isTwoFactorReminderDismissed(other, 1), isFalse,
          reason: other);
    }
    expect(await storage.isTwoFactorReminderDismissed(server, 2), isFalse);
    expect(
        await storage.isTwoFactorReminderDismissed(
            ' https://ONE.example.test/api/ ', 1),
        isTrue);
  });

  test('legacy user-only dismissal does not hide a scoped reminder', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('two_factor_reminder_dismissed_1', true);
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isTrue);
  });

  test('fresh login resets only its server and user dismissal', () async {
    final storage = StorageService();
    const serverA = 'https://one.example.test/api';
    const serverB = 'https://two.example.test/api';
    for (final server in [serverA, serverB]) {
      for (final id in [1, 2]) {
        await storage.setTwoFactorReminderDismissed(server, id, true);
      }
    }
    final scoped = AuthProvider(api: _Api(serverUrl: serverA));
    await scoped.login('user@example.test', 'password');
    await scoped.refreshTwoFactorReminder();
    expect(scoped.showTwoFactorReminder, isTrue);
    expect(await storage.isTwoFactorReminderDismissed(serverA, 1), isFalse);
    expect(await storage.isTwoFactorReminderDismissed(serverA, 2), isTrue);
    expect(await storage.isTwoFactorReminderDismissed(serverB, 1), isTrue);
    expect(await storage.isTwoFactorReminderDismissed(serverB, 2), isTrue);
    await scoped.dismissTwoFactorReminder();
    final restoredA = AuthProvider(api: _Api(serverUrl: serverA));
    await restoredA.checkSession();
    await restoredA.refreshTwoFactorReminder();
    expect(restoredA.showTwoFactorReminder, isFalse);
    final restoredB = AuthProvider(api: _Api(serverUrl: serverB));
    await restoredB.checkSession();
    await restoredB.refreshTwoFactorReminder();
    expect(restoredB.showTwoFactorReminder, isFalse);
  });

  test('another user on the same server still sees the reminder', () async {
    await auth.dismissTwoFactorReminder();
    final otherUser = User(
        id: 2,
        name: 'Other',
        email: 'other@example.test',
        role: 'User',
        tenantId: 1,
        createdAt: DateTime.utc(2026));
    await StorageService().saveUser(otherUser);
    final other = AuthProvider(api: _Api()..currentUser = otherUser);
    await other.checkSession();
    await other.refreshTwoFactorReminder();
    expect(other.showTwoFactorReminder, isTrue);
  });

  test('late status from the old server cannot show a hint on the new server',
      () async {
    setSelectedApiBaseUrl('https://one.example.test/api');
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isTrue);
    api.pending = Completer();
    final refresh = auth.refreshTwoFactorReminder();
    await Future<void>.delayed(Duration.zero);
    setSelectedApiBaseUrl('https://two.example.test/api');
    expect(auth.showTwoFactorReminder, isFalse);
    api.pending!.complete({'enabled': false});
    await refresh;
    expect(auth.showTwoFactorReminder, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getKeys().where((key) => key.startsWith('two_factor_reminder')),
        hasLength(1));
  });

  test('only confirmed disabled status shows the hint', () async {
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isTrue);
    api.enabled = true;
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isFalse);
  });

  test('unavailable status does not prompt or set an auth error', () async {
    api.fail = true;
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isFalse);
    expect(auth.errorMessage, isNull);
    expect(auth.isAuthenticated, isTrue);
  });

  test('dismissal survives refresh, workspace switch and app restart',
      () async {
    await auth.refreshTwoFactorReminder();
    await auth.dismissTwoFactorReminder();
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isFalse);
    await auth.switchTenant(2);
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isFalse);
    final restored = AuthProvider(api: api);
    await restored.checkSession();
    await restored.refreshTwoFactorReminder();
    expect(restored.showTwoFactorReminder, isFalse);
  });

  test('successful fresh login resets dismissal, failed login does not',
      () async {
    await auth.dismissTwoFactorReminder();
    api.failLogin = true;
    expect(await auth.login('user@example.test', 'wrong'), isFalse);
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isFalse);
    api.failLogin = false;
    await auth.logout();
    expect(await auth.login('user@example.test', 'password'), isTrue);
    await auth.refreshTwoFactorReminder();
    expect(auth.showTwoFactorReminder, isTrue);
  });

  test('late status responses cannot undo dismissal or signout', () async {
    await auth.refreshTwoFactorReminder();
    api.pending = Completer();
    final refresh = auth.refreshTwoFactorReminder();
    await Future<void>.delayed(Duration.zero);
    await auth.dismissTwoFactorReminder();
    api.pending!.complete({'enabled': false});
    await refresh;
    expect(auth.showTwoFactorReminder, isFalse);
    await auth.logout();
    expect(auth.showTwoFactorReminder, isFalse);
  });

  Future<void> pumpReminder(WidgetTester tester,
      {bool dark = false,
      Locale locale = const Locale('en'),
      double scale = 1}) async {
    await auth.refreshTwoFactorReminder();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(child: TwoFactorReminder(api: api))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('dismiss control hides hint and setup opens existing 2FA flow',
      (tester) async {
    await pumpReminder(tester);
    expect(find.text('Protect your account with 2FA'), findsOneWidget);
    await tester.tap(find.text('Set up 2FA'));
    await tester.pumpAndSettle();
    expect(find.byType(TwoFactorScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Protect your account with 2FA'), findsNothing);
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768)
  ]) {
    for (final dark in [false, true]) {
      testWidgets('hint fits $size dark=$dark with enlarged German text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpReminder(tester,
            dark: dark, locale: const Locale('de'), scale: 2);
        final setup = find.text('2FA einrichten');
        await tester.ensureVisible(setup);
        expect(setup, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
