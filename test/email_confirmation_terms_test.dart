import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/login/email_confirmation_screen.dart';
import 'package:qontract_app/screens/login/register_screen.dart';
import 'package:qontract_app/services/api_service.dart';

const _token =
    '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');

  RegistrationPolicy policy = const RegistrationPolicy(allowPublic: true);
  bool confirmationRequired = false;
  bool emailNotConfirmed = false;
  bool confirmSucceeds = true;
  Map<String, dynamic>? registration;
  String? confirmedToken;
  String? resentTo;
  TermsStatus terms = const TermsStatus();
  String? acceptedVersion;

  @override
  Future<RegistrationPolicy> registrationPolicy() async => policy;

  @override
  Future<AuthResult?> register(Map<String, dynamic> fields) async {
    registration = fields;
    if (confirmationRequired) return null;
    return AuthResult(token: 't', user: _user());
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    if (emailNotConfirmed) throw EmailNotConfirmedException();
    return AuthResult(token: 't', user: _user());
  }

  @override
  Future<void> resendEmailConfirmation(String email) async => resentTo = email;

  @override
  Future<void> confirmEmail(String token) async {
    confirmedToken = token;
    if (!confirmSucceeds) {
      throw ApiException(message: 'expired', statusCode: 400);
    }
  }

  @override
  Future<TermsStatus> termsStatus() async => terms;

  @override
  Future<TermsStatus> acceptTerms(String version) async {
    acceptedVersion = version;
    terms = TermsStatus(version: version, url: terms.url, accepted: true);
    return terms;
  }

  @override
  Future<void> saveToken(String token) async {}

  static User _user() => User.fromJson({
        'id': 1,
        'name': 'New user',
        'email': 'new@example.com',
        'role': 'TenantAdmin',
        'tenantId': 1,
        'createdAt': '2026-10-19T00:00:00Z',
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
      WidgetTester tester, AuthProvider auth, Widget home) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Dashboard')),
          '/login': (_) => const Scaffold(body: Text('Login')),
        },
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fillSignup(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('registerName')), 'New user');
    await tester.enterText(
        find.byKey(const Key('registerEmail')), 'new@example.com');
    await tester.enterText(
        find.byKey(const Key('registerPassword')), 'strong-password');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'strong-password');
    await tester.enterText(find.byKey(const Key('registerTenant')), 'Home');
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'signup requires accepting configured terms and sends the version',
      (tester) async {
    final api = _Api()
      ..policy = const RegistrationPolicy(
          allowPublic: true,
          termsVersion: '2026-10',
          termsUrl: 'https://qontract.example/terms');
    await mount(tester, AuthProvider(api: api), RegisterScreen(api: api));
    expect(find.text('Read the terms of use'), findsOneWidget);
    await fillSignup(tester);

    await submit(tester);
    expect(api.registration, isNull);
    expect(find.text('Please accept the terms of use to continue.'),
        findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await submit(tester);
    expect(api.registration!['acceptedTermsVersion'], '2026-10');
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('signup without configured terms shows no checkbox',
      (tester) async {
    final api = _Api();
    await mount(tester, AuthProvider(api: api), RegisterScreen(api: api));
    expect(find.byType(CheckboxListTile), findsNothing);
    await fillSignup(tester);
    await submit(tester);
    expect(api.registration!.containsKey('acceptedTermsVersion'), isFalse);
  });

  testWidgets('signup awaiting confirmation shows the inbox screen and resends',
      (tester) async {
    final api = _Api()..confirmationRequired = true;
    final auth = AuthProvider(api: api);
    await mount(tester, auth, RegisterScreen(api: api));
    await fillSignup(tester);
    await submit(tester);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorMessage, isNull);
    expect(find.textContaining('new@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resendConfirmation')));
    await tester.pumpAndSettle();
    expect(api.resentTo, 'new@example.com');
  });

  test('login with an unconfirmed email flags the account', () async {
    final api = _Api()..emailNotConfirmed = true;
    final auth = AuthProvider(api: api);
    expect(await auth.login('new@example.com', 'strong-password'), isFalse);
    expect(auth.emailNotConfirmed, isTrue);
    expect(auth.errorMessage, isNotNull);
    api.emailNotConfirmed = false;
    expect(await auth.login('new@example.com', 'strong-password'), isTrue);
    expect(auth.emailNotConfirmed, isFalse);
  });

  testWidgets('confirmation link confirms once and reports the result',
      (tester) async {
    final api = _Api();
    await mount(tester, AuthProvider(api: api),
        ConfirmEmailScreen(token: _token, api: api));
    expect(api.confirmedToken, _token);
    expect(find.text('Your email address is confirmed. You can now sign in.'),
        findsOneWidget);
  });

  testWidgets('expired or malformed links show the failure text',
      (tester) async {
    final api = _Api()..confirmSucceeds = false;
    await mount(tester, AuthProvider(api: api),
        ConfirmEmailScreen(token: _token, api: api));
    expect(find.textContaining('invalid or expired'), findsOneWidget);

    final other = _Api();
    await mount(tester, AuthProvider(api: other),
        ConfirmEmailScreen(token: 'abc', api: other));
    expect(other.confirmedToken, isNull);
    expect(find.textContaining('invalid or expired'), findsOneWidget);
  });

  test('changed terms are pending until accepted', () async {
    final api = _Api()
      ..terms = const TermsStatus(
          version: '2027-01',
          url: 'https://qontract.example/terms',
          accepted: false);
    final auth = AuthProvider(api: api);
    await auth.login('new@example.com', 'strong-password');
    await auth.refreshTermsStatus();
    expect(auth.pendingTerms?.version, '2027-01');
    expect(await auth.acceptPendingTerms(), isTrue);
    expect(api.acceptedVersion, '2027-01');
    expect(auth.pendingTerms, isNull);
  });

  test('registration policy parses empty terms as none', () {
    final policy = RegistrationPolicy.fromJson({
      'allowPublic': true,
      'requireEmailConfirmation': true,
      'termsVersion': '',
      'termsUrl': null,
    });
    expect(policy.allowPublic, isTrue);
    expect(policy.requireEmailConfirmation, isTrue);
    expect(policy.hasTerms, isFalse);
  });
}
