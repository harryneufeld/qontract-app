import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/config/api_config.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/api_host_provider.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';
import 'package:qontract_app/widgets/api_host_picker.dart';

const _staging = 'https://staging.example.com/api';
const _prod = 'https://qontract.example.com/api';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setSelectedApiBaseUrl(null));

  group('parseApiHostInput', () {
    test('normalizes and defaults to https', () {
      expect(parseApiHostInput(' staging.example.com/ '), _staging);
      expect(parseApiHostInput('http://10.0.2.2:65533'),
          'http://10.0.2.2:65533/api');
      expect(parseApiHostInput('https://staging.example.com/api'), _staging);
    });

    test('rejects non-http, credentials, queries and empty input', () {
      for (final input in [
        '',
        '   ',
        'not a url',
        'ftp://example.com',
        'https://user:pw@example.com',
        'https://example.com?x=1',
        'https://',
      ]) {
        expect(parseApiHostInput(input), isNull, reason: input);
      }
    });
  });

  group('ApiHostProvider', () {
    test('defaults to the configured host', () async {
      final hosts = ApiHostProvider();
      await hosts.init();
      expect(hosts.hosts, isEmpty);
      expect(hosts.activeUrl, isNull);
      expect(hosts.effectiveUrl, defaultApiBaseUrl());
      expect(ApiService().baseUrl, kDefaultApiBaseUrl);
    });

    test('save validates, names by host and dedupes by url', () async {
      final hosts = ApiHostProvider();
      await hosts.init();
      expect(await hosts.save('not a url'), isNull);
      final saved = await hosts.save('staging.example.com');
      expect(saved?.name, 'staging.example.com');
      expect(saved?.url, _staging);
      await hosts.save('https://staging.example.com/api/', name: 'Staging');
      expect(hosts.hosts.map((h) => h.name), ['Staging']);
    });

    test('select switches existing ApiService instances', () async {
      final api = ApiService();
      final hosts = ApiHostProvider();
      await hosts.init();
      await hosts.save(_staging);
      await hosts.select(_staging);
      expect(api.baseUrl, _staging);
      await hosts.select(null);
      expect(api.baseUrl, kDefaultApiBaseUrl);
    });

    test('ignores unsaved hosts and an explicit url still wins', () async {
      final hosts = ApiHostProvider();
      await hosts.init();
      await hosts.select(_prod);
      expect(hosts.activeUrl, isNull);
      await hosts.save(_prod);
      await hosts.select(_prod);
      expect(ApiService(baseUrl: 'http://localhost').baseUrl,
          'http://localhost/api');
    });

    test('persists hosts and selection across restarts', () async {
      final first = ApiHostProvider();
      await first.init();
      await first.save(_staging, name: 'Staging');
      await first.save(_prod, name: 'Production');
      await first.select(_prod);
      setSelectedApiBaseUrl(null);

      final second = ApiHostProvider();
      await second.init();
      expect(second.hosts.map((h) => h.name), ['Staging', 'Production']);
      expect(second.activeUrl, _prod);
      expect(resolveApiBaseUrl(), _prod);
    });

    test('recovers from corrupt or dangling stored values', () async {
      SharedPreferences.setMockInitialValues({
        ApiHostProvider.hostsKey: '{oops',
        ApiHostProvider.activeKey: _prod,
      });
      final hosts = ApiHostProvider();
      await hosts.init();
      expect(hosts.hosts, isEmpty);
      expect(hosts.activeUrl, isNull);
      expect(resolveApiBaseUrl(), kDefaultApiBaseUrl);
    });

    test('the active host cannot be removed', () async {
      final hosts = ApiHostProvider();
      await hosts.init();
      await hosts.save(_staging);
      await hosts.save(_prod);
      await hosts.select(_prod);
      await hosts.remove(_prod);
      await hosts.remove(_staging);
      expect(hosts.hosts.map((h) => h.url), [_prod]);
    });
  });

  group('server picker', () {
    testWidgets('adding a server while signed out switches to it',
        (tester) async {
      final hosts = ApiHostProvider();
      await hosts.init();
      await tester.pumpWidget(_app(hosts, AuthProvider(api: _Api())));

      await tester.tap(find.byKey(const Key('apiHostButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addApiHostButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveApiHostButton')));
      await tester.pumpAndSettle();
      expect(find.text(S.current.enterAValidServerAddress), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('apiHostAddressField')), 'staging.example.com');
      await tester.enterText(
          find.byKey(const Key('apiHostNameField')), 'Staging');
      await tester.tap(find.byKey(const Key('saveApiHostButton')));
      await tester.pumpAndSettle();

      expect(hosts.activeUrl, _staging);
      expect(find.text('Staging'), findsOneWidget);
      expect(find.text(S.current.switchServerQuestion), findsNothing);
    });

    testWidgets('signed in: confirms, then logs out on the old host first',
        (tester) async {
      final hosts = ApiHostProvider();
      await hosts.init();
      await hosts.save(_staging, name: 'Staging');
      final api = _Api();
      final auth = AuthProvider(api: api, storage: StorageService());
      await tester.runAsync(() => auth.login('a@example.test', 'pw'));
      await tester.pumpWidget(_app(hosts, auth));

      await tester.tap(find.byKey(const Key('apiHostButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apiHost-$_staging')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.cancel));
      await tester.pumpAndSettle();
      expect(hosts.activeUrl, isNull);
      expect(auth.isAuthenticated, isTrue);

      await tester.tap(find.byKey(const Key('apiHost-$_staging')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmSwitchServer')));
      await tester.pumpAndSettle();

      expect(api.logoutBaseUrl, kDefaultApiBaseUrl);
      expect(auth.isAuthenticated, isFalse);
      expect(hosts.activeUrl, _staging);
    });
  });
}

Widget _app(ApiHostProvider hosts, AuthProvider auth) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: hosts),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: ApiHostButton())),
      ),
    );

class _Api extends ApiService {
  String? logoutBaseUrl;

  @override
  Future<AuthResult> login(String email, String password) async => AuthResult(
        token: 't',
        user: User(
            id: 1,
            name: 'Alex',
            email: email,
            role: 'User',
            tenantId: 1,
            createdAt: DateTime.utc(2026)),
      );

  @override
  Future<void> logout() async => logoutBaseUrl = baseUrl;
}
