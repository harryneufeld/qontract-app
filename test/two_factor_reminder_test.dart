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
import 'package:qontract_app/widgets/two_factor_reminder.dart';

final _user = User(
    id: 1,
    name: 'User',
    email: 'user@example.test',
    role: 'User',
    tenantId: 1,
    createdAt: DateTime.utc(2026));

class _Api extends ApiService {
  bool enabled = false;
  bool fail = false;
  bool failLogin = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<AuthResult> login(String email, String password) async {
    if (failLogin) throw ApiException(message: 'Rejected');
    return AuthResult(token: 'token', user: _user);
  }

  @override
  Future<User> me() async => _user;
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    auth = AuthProvider(api: api);
    await auth.login('user@example.test', 'password');
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
