import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_routes.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/main.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/login/password_reset_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  String? email;
  String? token;
  String? password;
  ApiException? failure;
  @override
  Future<void> requestPasswordReset(String email) async {
    this.email = email;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    this.token = token;
    password = newPassword;
    if (failure != null) throw failure!;
  }

  @override
  Future<User> me() async => User(
      id: 1,
      name: 'User',
      email: 'user@example.test',
      role: 'User',
      tenantId: 1,
      createdAt: DateTime.utc(2026));
}

class _RealHttp extends HttpOverrides {}

void main() {
  final token = 'A' * 64;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<AuthProvider> pump(WidgetTester tester, _Api api,
      {bool complete = false, String? link}) async {
    final auth = AuthProvider(api: api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {
            '/login': (_) => const Scaffold(body: Text('Login destination')),
            '/forgot-password': (_) => PasswordResetScreen(api: api)
          },
          home: PasswordResetScreen(api: api, complete: complete, token: link),
        )));
    return auth;
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('submitPasswordReset')));
    await tester.tap(find.byKey(const Key('submitPasswordReset')));
    await tester.pumpAndSettle();
  }

  Future<void> passwords(WidgetTester tester,
      {String confirmation = 'replacement123'}) async {
    await tester.enterText(
        find.byKey(const Key('resetNewPassword')), 'replacement123');
    await tester.enterText(
        find.byKey(const Key('resetConfirmPassword')), confirmation);
  }

  testWidgets('request acknowledges generically at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _Api();
    await pump(tester, api);
    await tester.enterText(
        find.byKey(const Key('resetEmail')), ' user@example.test ');
    await submit(tester);
    expect(api.email, 'user@example.test');
    expect(find.textContaining('If this account is eligible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('incomplete link offers another request without password input',
      (tester) async {
    await pump(tester, _Api(), complete: true);
    expect(find.textContaining('incomplete or invalid'), findsOneWidget);
    expect(find.byKey(const Key('resetNewPassword')), findsNothing);
    await tester.tap(find.text('Request a new link'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resetEmail')), findsOneWidget);
  });
  testWidgets('confirmation mismatch does not submit', (tester) async {
    final api = _Api();
    await pump(tester, api, complete: true, link: token);
    await passwords(tester, confirmation: 'different');
    await submit(tester);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(api.token, isNull);
  });
  testWidgets('expired link shows the server message and retains form',
      (tester) async {
    final api = _Api()
      ..failure = ApiException(
          message: 'This link is invalid or expired.', statusCode: 400);
    await pump(tester, api, complete: true, link: token);
    await passwords(tester);
    await submit(tester);
    expect(find.text('This link is invalid or expired.'), findsOneWidget);
    expect(find.byKey(const Key('resetNewPassword')), findsOneWidget);
    expect(find.text('Request a new link'), findsOneWidget);
  });
  testWidgets('successful reset clears stored session without automatic login',
      (tester) async {
    final api = _Api();
    await api.saveToken('old-token');
    final auth = await pump(tester, api, complete: true, link: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode((await api.me()).toJson()));
    await auth.checkSession();
    expect(auth.isAuthenticated, true);
    await passwords(tester);
    await submit(tester);
    expect(api.token, token);
    expect(api.password, 'replacement123');
    expect(auth.isAuthenticated, false);
    expect(await api.getToken(), isNull);
    expect(prefs.getString('user'), isNull);
    expect(find.textContaining('Password updated.'), findsOneWidget);
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });
  test('reset route captures token but removes it from route settings', () {
    final route = AppRoutes.resetLinkRoute('/reset-password?token=$token')!;
    expect(route.settings.name, '/reset-password');
    expect(route.settings.arguments, isNull);
    expect(AppRoutes.resetLinkRoute('/contracts'), isNull);
    expect(AppRoutes.resetLinkRoute('/reset-password?token=%FF'), isNotNull);
    expect(
        AppRoutes.resetLinkRoute('/reset-password?token=$token&token=$token'),
        isNotNull);
  });

  testWidgets('launching a reset deep link opens the public form directly',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/reset-password?token=$token';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resetNewPassword')), findsOneWidget);
    expect(find.text('Set password'), findsWidgets);
    final screen =
        tester.widget<PasswordResetScreen>(find.byType(PasswordResetScreen));
    expect(screen.token, token);
    expect(tester.takeException(), isNull);
  });

  test('public reset calls omit bearer headers and preserve actionable errors',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'existing-token'});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <Map<String, dynamic>>[];
      server.listen((request) async {
        expect(request.headers.value('Authorization'), isNull);
        seen.add(jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>);
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode =
            request.uri.path.endsWith('forgot-password') ? 503 : 400;
        request.response.write(jsonEncode({
          'message': request.uri.path.endsWith('forgot-password')
              ? 'Password reset is not available.'
              : 'This link is invalid or expired.'
        }));
        await request.response.close();
      });
      try {
        final api = ApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');
        await expectLater(
            api.requestPasswordReset('user@example.test'),
            throwsA(isA<ApiException>().having((e) => e.message, 'message',
                'Password reset is not available.')));
        await expectLater(
            api.resetPassword(token, 'replacement123'),
            throwsA(isA<ApiException>().having((e) => e.message, 'message',
                'This link is invalid or expired.')));
        expect(seen[0]['email'], 'user@example.test');
        expect(seen[1]['token'], token);
        expect(await api.getToken(), 'existing-token');
      } finally {
        await server.close(force: true);
      }
    }, _RealHttp());
  });
}
