import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/locale_provider.dart';
import 'package:qontract_app/screens/onboarding/setup_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');

  Map<String, dynamic>? saved;

  @override
  Future<AuthResult> login(String email, String password) async =>
      AuthResult(
          token: 't',
          user: User.fromJson({
            'id': 1,
            'name': 'ada',
            'email': 'ada@example.com',
            'role': 'User',
            'tenantId': 0,
            'createdAt': '2026-10-22T00:00:00Z',
            'onboardingCompleted': false,
          }));

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<User> updateProfile(
      {String? name,
      String? defaultCurrency,
      String? language,
      bool? onboardingCompleted}) async {
    saved = {
      'name': name,
      'defaultCurrency': defaultCurrency,
      'language': language,
      'onboardingCompleted': onboardingCompleted,
    };
    return User.fromJson({
      'id': 1,
      'name': name ?? 'ada',
      'email': 'ada@example.com',
      'role': 'User',
      'tenantId': 0,
      'createdAt': '2026-10-22T00:00:00Z',
      'defaultCurrency': defaultCurrency,
      'onboardingCompleted': true,
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the default currency follows the device region', () {
    expect(SetupScreen.defaultCurrencyFor('CH'), 'CHF');
    expect(SetupScreen.defaultCurrencyFor('US'), 'USD');
    expect(SetupScreen.defaultCurrencyFor('DE'), 'EUR');
    expect(SetupScreen.defaultCurrencyFor(null), 'EUR');
  });

  Future<AuthProvider> signedIn(WidgetTester tester, _Api api) async {
    final auth = AuthProvider(api: api);
    expect(await auth.login('ada@example.com', 'pw'), isTrue);
    return auth;
  }

  testWidgets('setup asks for name, currency and language and saves them',
      (tester) async {
    final api = _Api();
    final seed = await signedIn(tester, api);
    expect(seed.user!.onboardingCompleted, isFalse);
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: seed),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SetupScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // The placeholder name taken from the email is not prefilled.
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('setupName')))
            .controller!
            .text,
        isEmpty);

    await tester.tap(find.byKey(const Key('setupContinue')));
    await tester.pumpAndSettle();
    expect(api.saved, isNull); // the name is required

    await tester.enterText(find.byKey(const Key('setupName')), 'Ada Lovelace');
    await tester.tap(find.byKey(const Key('setupContinue')));
    await tester.pumpAndSettle();
    expect(api.saved!['name'], 'Ada Lovelace');
    expect(SetupScreen.currencies, contains(api.saved!['defaultCurrency']));
    expect(api.saved!['onboardingCompleted'], isTrue);
    expect(seed.user!.onboardingCompleted, isTrue);
  });

  testWidgets('skipping only marks setup as done', (tester) async {
    final api = _Api();
    final seed = await signedIn(tester, api);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: seed),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SetupScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setupSkip')));
    await tester.pumpAndSettle();
    expect(api.saved, {
      'name': null,
      'defaultCurrency': null,
      'language': null,
      'onboardingCompleted': true,
    });
  });
}
