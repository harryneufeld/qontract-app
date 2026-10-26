import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/session_info.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/app_lock_provider.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/account/sessions_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/biometric_authenticator.dart';
import 'package:qontract_app/services/storage_service.dart';
import 'package:qontract_app/widgets/app_lock_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthenticator implements BiometricAuthenticator {
  bool available = true;
  bool succeeds = true;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}

class _SessionsApi extends ApiService {
  _SessionsApi(this.sessions) : super(baseUrl: 'http://localhost');
  List<SessionInfo> sessions;
  final revoked = <String>[];
  int revokedOthers = 0;

  @override
  Future<List<SessionInfo>> listSessions() async => List.of(sessions);

  @override
  Future<void> revokeSession(String id) async {
    revoked.add(id);
    sessions = sessions.where((s) => s.id != id).toList();
  }

  @override
  Future<int> revokeOtherSessions() async {
    revokedOthers++;
    sessions = sessions.where((s) => s.current).toList();
    return 1;
  }
}

class _SignedInAuth extends AuthProvider {
  _SignedInAuth() : super(api: ApiService(baseUrl: 'http://localhost'), storage: StorageService());
  @override
  bool get isAuthenticated => true;
  @override
  User? get user => null;
}

SessionInfo _session(String id, String name, {bool current = false}) =>
    SessionInfo(
        id: id,
        deviceName: name,
        clientType: 'mobile',
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: DateTime.utc(2026, 1, 2),
        current: current);

void main() {
  late _FakeAuthenticator authenticator;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authenticator = _FakeAuthenticator();
    now = DateTime.utc(2026, 5, 1, 12);
  });

  AppLockProvider provider() =>
      AppLockProvider(authenticator: authenticator, clock: () => now);

  group('AppLockProvider', () {
    test('is off and unavailable by default on unsupported devices', () async {
      authenticator.available = false;
      final lock = provider();
      await lock.init();
      expect(lock.available, isFalse);
      expect(lock.locked, isFalse);
    });

    test('enabling needs a successful unlock first', () async {
      final lock = provider();
      await lock.init();

      authenticator.succeeds = false;
      expect(await lock.setEnabled(true), isFalse);
      expect(lock.enabled, isFalse);

      authenticator.succeeds = true;
      expect(await lock.setEnabled(true), isTrue);
      expect(lock.enabled, isTrue);
      expect(lock.locked, isFalse, reason: 'just unlocked');
      expect((await SharedPreferences.getInstance()).getBool(AppLockProvider.storageKey), isTrue);
    });

    test('locks on a cold start when enabled', () async {
      SharedPreferences.setMockInitialValues({AppLockProvider.storageKey: true});
      final lock = provider();
      await lock.init();
      expect(lock.locked, isTrue);

      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });

    test('a declined prompt keeps it locked', () async {
      SharedPreferences.setMockInitialValues({AppLockProvider.storageKey: true});
      final lock = provider();
      await lock.init();
      authenticator.succeeds = false;

      expect(await lock.unlock(), isFalse);
      expect(lock.locked, isTrue);
    });

    test('locks after more than five minutes in the background only', () async {
      SharedPreferences.setMockInitialValues({AppLockProvider.storageKey: true});
      final lock = provider();
      await lock.init();
      await lock.unlock();

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 4));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.locked, isFalse);

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 6));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.locked, isTrue);
    });

    test('the lock never engages while disabled', () async {
      final lock = provider();
      await lock.init();
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 1));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.locked, isFalse);
    });
  });

  testWidgets('the overlay hides the app while locked and prompts to unlock',
      (tester) async {
    SharedPreferences.setMockInitialValues({AppLockProvider.storageKey: true});
    final lock = provider();
    await lock.init();
    authenticator.succeeds = false;

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLockProvider>.value(value: lock),
        ChangeNotifierProvider<AuthProvider>(create: (_) => _SignedInAuth()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppLockOverlay(child: Scaffold(body: Text('secret contracts'))),
      ),
    ));
    await tester.pump();

    expect(find.text('secret contracts'), findsNothing);
    expect(find.byKey(const Key('unlockButton')), findsOneWidget);
    expect(authenticator.prompts, 1, reason: 'prompts on its own');

    authenticator.succeeds = true;
    await tester.tap(find.byKey(const Key('unlockButton')));
    await tester.pumpAndSettle();
    expect(find.text('secret contracts'), findsOneWidget);
    expect(find.byKey(const Key('unlockButton')), findsNothing);
  });

  group('SessionsScreen', () {
    Future<void> pump(WidgetTester tester, _SessionsApi api) =>
        tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionsScreen(api: api),
        ));

    testWidgets('marks this device and revokes another after confirmation',
        (tester) async {
      final api = _SessionsApi(
          [_session('a', 'Pixel 8', current: true), _session('b', 'Old tablet')]);
      await pump(tester, api);
      await tester.pumpAndSettle();

      expect(find.textContaining('Pixel 8 · This device'), findsOneWidget);
      expect(find.byKey(const Key('session-a')), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out this device?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(api.revoked, ['b']);
      expect(find.text('Old tablet'), findsNothing);
    });

    testWidgets('signs out all other devices', (tester) async {
      final api = _SessionsApi(
          [_session('a', 'Pixel 8', current: true), _session('b', 'Old tablet')]);
      await pump(tester, api);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('signOutOthersButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(api.revokedOthers, 1);
      expect(find.byKey(const Key('signOutOthersButton')), findsNothing);
    });
  });
}
