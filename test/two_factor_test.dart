import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/config/api_config.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/account/two_factor_screen.dart';
import 'package:qontract_app/screens/login/login_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/widgets/api_host_picker.dart';

final _user = User(
    id: 1,
    name: 'User',
    email: 'user@example.test',
    role: 'User',
    tenantId: 0,
    createdAt: DateTime.utc(2026));

class _Api extends ApiService {
  bool enabled = false;
  bool fail = false;
  String? receivedCode;
  bool? receivedRecovery;
  final actions = <String>[];
  @override
  Future<bool> publicRegistrationAllowed() async => false;
  @override
  Future<AuthResult> login(String email, String password) async =>
      throw TwoFactorRequiredException();
  @override
  Future<AuthResult> loginWithTwoFactor(
      String email, String password, String code,
      {bool recovery = false}) async {
    receivedCode = code;
    receivedRecovery = recovery;
    if (fail) throw ApiException(message: 'Invalid code');
    return AuthResult(token: 'jwt', user: _user);
  }

  @override
  Future<Map<String, dynamic>> twoFactorStatus() async =>
      {'enabled': enabled, 'recoveryCodesRemaining': 10};
  @override
  Future<Map<String, dynamic>> manageTwoFactor(String action, String password,
      {String code = '', bool recovery = false}) async {
    actions.add(action);
    receivedCode = code;
    receivedRecovery = recovery;
    if (fail) throw ApiException(message: 'Invalid code');
    if (action == 'setup') {
      return {
        'secret': 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        'authenticatorUri':
            'otpauth://totp/qontract?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
      };
    }
    return {
      'recoveryCodes': ['RECOVERY01', 'RECOVERY02']
    };
  }
}

class _RealHttp extends HttpOverrides {}

void main() {
  const capture = bool.fromEnvironment('QONTRACT_CAPTURE_2FA');
  const previewDir = String.fromEnvironment('QONTRACT_PREVIEW_DIR');
  const fontDir = String.fromEnvironment('QONTRACT_PREVIEW_FONT_DIR');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    S.languageCode = 'en';
    setSelectedApiBaseUrl(null);
  });
  tearDown(() => setSelectedApiBaseUrl(null));
  Future<AuthProvider> pump(WidgetTester tester, _Api api, Widget screen,
      {Locale locale = const Locale('en'),
      bool dark = false,
      double scale = 1}) async {
    final auth = AuthProvider(api: api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!),
          routes: {
            '/dashboard': (_) =>
                const Scaffold(body: Text('Dashboard destination')),
            '/login': (_) => const Scaffold(body: Text('Login destination'))
          },
          home: RepaintBoundary(key: const Key('capture2fa'), child: screen),
        )));
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('login defers session until second factor and supports recovery',
      (tester) async {
    final api = _Api();
    final auth = await pump(tester, api, LoginScreen(api: api));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tap(tester, 'Login');
    expect(auth.isAuthenticated, false);
    expect(find.text('Authenticator code'), findsOneWidget);
    await tap(tester, 'Use a recovery code');
    await tester.enterText(find.byType(TextFormField), 'RECOVERY01');
    await tap(tester, 'Login');
    expect(api.receivedRecovery, true);
    expect(api.receivedCode, 'RECOVERY01');
    expect(auth.isAuthenticated, true);
    expect(find.text('Dashboard destination'), findsOneWidget);
  });

  testWidgets('a complete authenticator code signs in without pressing Login',
      (tester) async {
    final api = _Api();
    final auth = await pump(tester, api, LoginScreen(api: api));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tap(tester, 'Login');
    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, false);
    await tester.enterText(find.byType(TextFormField), '123 456');
    await tester.pumpAndSettle();
    expect(api.receivedRecovery, false);
    expect(api.receivedCode, '123456');
    expect(auth.isAuthenticated, true);
    expect(find.text('Dashboard destination'), findsOneWidget);
  });

  testWidgets('server switch clears pending second factor and password',
      (tester) async {
    final api = _Api();
    final auth = await pump(tester, api, LoginScreen(api: api));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tap(tester, 'Login');
    final hostButton = tester.widget<ApiHostButton>(find.byType(ApiHostButton));
    // Closing the dialog without changing servers preserves the current step.
    hostButton.onChanged!();
    await tester.pumpAndSettle();
    expect(find.text('Authenticator code'), findsOneWidget);
    setSelectedApiBaseUrl('https://new.example.test/api');
    hostButton.onChanged!();
    await tester.pumpAndSettle();
    expect(auth.requiresTwoFactor, false);
    expect(find.text('Authenticator code'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('invalid code stays on second factor and back clears password',
      (tester) async {
    final api = _Api()..fail = true;
    final auth = await pump(tester, api, LoginScreen(api: api));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tap(tester, 'Login');
    await tester.enterText(find.byType(TextFormField), '123456');
    await tap(tester, 'Login');
    expect(auth.isAuthenticated, false);
    expect(find.text('Authenticator code'), findsOneWidget);
    await tap(tester, 'Back to password sign-in');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('setup confirms code and keeps recovery codes until acknowledged',
      (tester) async {
    final api = _Api();
    await pump(tester, api, TwoFactorScreen(api: api));
    await tester.enterText(find.byType(TextFormField), 'password123');
    await tap(tester, 'Set up authenticator');
    expect(find.text('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tap(tester, 'Activate two-factor authentication');
    expect(api.actions, ['setup', 'enable']);
    expect(find.textContaining('RECOVERY01'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tap(tester, 'I saved my codes — sign in again');
    expect(find.text('Login destination'), findsOneWidget);
  });

  testWidgets('disable accepts recovery proof and signs out', (tester) async {
    final api = _Api()..enabled = true;
    await pump(tester, api, TwoFactorScreen(api: api));
    await tester.enterText(find.byType(TextFormField).first, 'password123');
    await tap(tester, 'Use a recovery code');
    await tester.enterText(find.byType(TextFormField).last, 'RECOVERY01');
    await tap(tester, 'Disable two-factor authentication');
    expect(api.actions, ['disable']);
    expect(api.receivedRecovery, true);
    expect(find.text('Login destination'), findsOneWidget);
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768)
  ]) {
    for (final dark in [false, true]) {
      testWidgets('2FA setup fits $size dark=$dark with enlarged German text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (capture) {
          await tester.runAsync(() async {
            final font = FontLoader('Roboto')
              ..addFont(Future.value(ByteData.sublistView(
                  await File('$fontDir/roboto-regular.ttf').readAsBytes())));
            await font.load();
            final mono = FontLoader('monospace')
              ..addFont(Future.value(ByteData.sublistView(
                  await File('$fontDir/roboto-regular.ttf').readAsBytes())));
            await mono.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(Future.value(ByteData.sublistView(
                  await File('$fontDir/materialicons-regular.otf')
                      .readAsBytes())));
            await icons.load();
          });
        }
        final api = _Api();
        await pump(tester, api, TwoFactorScreen(api: api),
            locale: const Locale('de'), dark: dark, scale: 2);
        await tester.enterText(find.byType(TextFormField), 'password123');
        await tap(tester, 'Authenticator einrichten');
        expect(find.text('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'), findsOneWidget);
        if (capture && previewDir.isNotEmpty) {
          await tester
              .ensureVisible(find.text('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'));
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('capture2fa')));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(previewDir).create(recursive: true);
            await File('$previewDir/setup-${size.width.toInt()}-$dark.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(
            find.text('Zwei-Faktor-Authentifizierung aktivieren'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('HTTP login stores no session for challenge or rejected code', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <Map<String, dynamic>>[];
      server.listen((request) async {
        expect(request.headers.value('Authorization'), isNull);
        final data = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        seen.add(data);
        request.response.headers.contentType = ContentType.json;
        if (data['twoFactorCode'] == null) {
          request.response.write(jsonEncode({'requiresTwoFactor': true}));
        } else if (data['twoFactorCode'] == '123456') {
          request.response.statusCode = 401;
          request.response.write('{}');
        } else {
          request.response.write(
              jsonEncode({'accessToken': 'new-token', 'user': _user.toJson()}));
        }
        await request.response.close();
      });
      try {
        final api = ApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');
        await expectLater(api.login('user@example.test', 'password123'),
            throwsA(isA<TwoFactorRequiredException>()));
        expect(await api.getToken(), isNull);
        await expectLater(
            api.loginWithTwoFactor(
                'user@example.test', 'password123', '123456'),
            throwsA(isA<ApiException>()));
        expect(await api.getToken(), isNull);
        await api.loginWithTwoFactor(
            'user@example.test', 'password123', ' RECOVERY01 ',
            recovery: true);
        expect(await api.getToken(), 'new-token');
        expect(seen.last['twoFactorCode'], 'RECOVERY01');
        expect(seen.last['useRecoveryCode'], true);
      } finally {
        await server.close(force: true);
      }
    }, _RealHttp());
  });
}
