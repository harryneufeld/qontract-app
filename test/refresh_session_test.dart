import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';
import 'package:qontract_app/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttp extends HttpOverrides {}

class _Recorded {
  final String method;
  final String path;
  final String? authorization;
  final String? client;
  final Map<String, dynamic>? body;
  _Recorded(this.method, this.path, this.authorization, this.client, this.body);
}

/// Local stand-in for the backend: accepts `Bearer new-access` only, and hands
/// out that token on /auth/refresh.
class _Backend {
  _Backend({this.refreshStatus = 200, this.refreshDelay = Duration.zero});

  final int refreshStatus;
  final Duration refreshDelay;
  final requests = <_Recorded>[];
  late final HttpServer server;

  String get baseUrl => 'http://127.0.0.1:${server.port}/api';
  int count(String path) => requests.where((r) => r.path == path).length;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>;
      final path = request.uri.path.replaceFirst('/api', '');
      requests.add(_Recorded(
          request.method,
          path,
          request.headers.value('Authorization'),
          request.headers.value('X-Qontract-Client'),
          body));
      request.response.headers.contentType = ContentType.json;
      switch (path) {
        case '/auth/refresh':
          await Future<void>.delayed(refreshDelay);
          request.response.statusCode = refreshStatus;
          if (refreshStatus == 200) {
            request.response.write(jsonEncode({
              'accessToken': 'new-access',
              'refreshToken': 'rt-2',
              'accessTokenExpiresAt':
                  DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
            }));
          }
        case '/auth/login':
          request.response.write(jsonEncode({
            'accessToken': 'login-access',
            'refreshToken': body?['client'] == 'web' ? null : 'rt-login',
            'accessTokenExpiresAt':
                DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
            'user': _userJson,
          }));
        case '/auth/me':
          if (request.headers.value('Authorization') == 'Bearer new-access') {
            request.response.write(jsonEncode(_userJson));
          } else {
            request.response.statusCode = 401;
          }
        default:
          if (request.headers.value('Authorization') == 'Bearer new-access') {
            request.response.write('[]');
          } else {
            request.response.statusCode = 401;
          }
      }
      await request.response.close();
    });
  }

  Future<void> stop() => server.close(force: true);
}

final _userJson = {
  'id': 1,
  'name': 'Alice',
  'email': 'a@b.c',
  'role': 'User',
  'tenantId': 1,
  'createdAt': '2026-01-01T00:00:00Z',
};

class _Storage extends StorageService {
  User? saved = User.fromJson(_userJson);
  @override
  Future<User?> getUser() async => saved;
  @override
  Future<void> saveUser(User user) async => saved = user;
  @override
  Future<void> clearUser() async => saved = null;
}

Future<void> _seed(TokenStore store, String baseUrl,
    {String access = 'old-access',
    String? refresh = 'rt-1',
    Duration expiresIn = const Duration(hours: 1)}) async {
  await store.startSession(baseUrl,
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: DateTime.now().toUtc().add(expiresIn));
}

void main() {
  late TokenStore store;
  late _Backend backend;
  var unauthorized = 0;
  void Function()? previousHandler;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = TokenStore.shared =
        TokenStore(backend: MemorySecretBackend(), web: false);
    unauthorized = 0;
    previousHandler = ApiService.onUnauthorized;
    ApiService.onUnauthorized = () => unauthorized++;
  });

  tearDown(() {
    ApiService.onUnauthorized = previousHandler;
    TokenStore.shared = TokenStore(backend: MemorySecretBackend());
  });

  Future<void> withBackend(_Backend b, Future<void> Function() body) =>
      HttpOverrides.runWithHttpOverrides(() async {
        backend = b;
        await b.start();
        try {
          await body();
        } finally {
          await b.stop();
        }
      }, _RealHttp());

  test('a 401 triggers exactly one refresh for N concurrent requests',
      () async {
    await withBackend(_Backend(refreshDelay: const Duration(milliseconds: 150)),
        () async {
      await _seed(store, backend.baseUrl);
      final apis = List.generate(5, (_) => ApiService(baseUrl: backend.baseUrl));
      final results = await Future.wait(apis.map((api) => api.listSessions()));

      expect(results, everyElement(isEmpty));
      expect(backend.count('/auth/refresh'), 1);
      expect(backend.requests.firstWhere((r) => r.path == '/auth/refresh').body,
          {'refreshToken': 'rt-1'});
      // Every request ended up carrying the new token.
      expect(
          backend.requests
              .where((r) => r.path == '/auth/sessions')
              .last
              .authorization,
          'Bearer new-access');
      final stored = await store.read(backend.baseUrl);
      expect(stored.accessToken, 'new-access');
      expect(stored.refreshToken, 'rt-2');
      expect(unauthorized, 0);
    });
  });

  test('refreshes before the request when the access token is about to expire',
      () async {
    await withBackend(_Backend(), () async {
      await _seed(store, backend.baseUrl, expiresIn: const Duration(seconds: 20));
      await ApiService(baseUrl: backend.baseUrl).listSessions();

      expect(backend.count('/auth/refresh'), 1);
      final sessions = backend.requests.where((r) => r.path == '/auth/sessions');
      expect(sessions, hasLength(1), reason: 'no doomed first attempt');
      expect(sessions.single.authorization, 'Bearer new-access');
    });
  });

  test('a refresh the server rejects ends the session', () async {
    await withBackend(_Backend(refreshStatus: 401), () async {
      await _seed(store, backend.baseUrl);
      await expectLater(ApiService(baseUrl: backend.baseUrl).listSessions(),
          throwsA(isA<ApiException>()));

      expect((await store.read(backend.baseUrl)).accessToken, isNull);
      expect((await store.read(backend.baseUrl)).refreshToken, isNull);
      expect(unauthorized, 1);
    });
  });

  test('a refresh that cannot reach the server keeps the session', () async {
    await withBackend(_Backend(refreshStatus: 503), () async {
      await _seed(store, backend.baseUrl);
      await expectLater(
          ApiService(baseUrl: backend.baseUrl).listSessions(),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', isNull)));

      final stored = await store.read(backend.baseUrl);
      expect(stored.accessToken, 'old-access');
      expect(stored.refreshToken, 'rt-1');
      expect(unauthorized, 0);
    });
  });

  test('a session without a refresh token keeps today\'s 401 behaviour',
      () async {
    await withBackend(_Backend(), () async {
      await _seed(store, backend.baseUrl, refresh: null);
      await expectLater(ApiService(baseUrl: backend.baseUrl).listSessions(),
          throwsA(isA<ApiException>()));

      expect(backend.count('/auth/refresh'), 0);
      expect((await store.read(backend.baseUrl)).accessToken, isNull);
      expect(unauthorized, 1);
    });
  });

  test('a tenant switch keeps the refresh token', () async {
    await withBackend(_Backend(), () async {
      await _seed(store, backend.baseUrl);
      await ApiService(baseUrl: backend.baseUrl)
          .saveToken('switched', keepRefreshToken: true);

      final stored = await store.read(backend.baseUrl);
      expect(stored.accessToken, 'switched');
      expect(stored.refreshToken, 'rt-1');
    });
  });

  test('mobile login sends client and device name and keeps the refresh token',
      () async {
    await withBackend(_Backend(), () async {
      await ApiService(baseUrl: backend.baseUrl).login('a@b.c', 'secret');

      final login = backend.requests.singleWhere((r) => r.path == '/auth/login');
      expect(login.body!['client'], 'mobile');
      expect(login.body!['deviceName'], isNotEmpty);
      final stored = await store.read(backend.baseUrl);
      expect(stored.accessToken, 'login-access');
      expect(stored.refreshToken, 'rt-login');
      expect(stored.accessExpiresAt, isNotNull);
    });
  });

  test('web login keeps no refresh token and sends the client header',
      () async {
    store = TokenStore.shared =
        TokenStore(backend: MemorySecretBackend(), web: true);
    await withBackend(_Backend(), () async {
      await ApiService(baseUrl: backend.baseUrl).login('a@b.c', 'secret');

      final login = backend.requests.singleWhere((r) => r.path == '/auth/login');
      expect(login.body!['client'], 'web');
      expect(login.client, 'web');
      final stored = await store.read(backend.baseUrl);
      expect(stored.accessToken, 'login-access');
      expect(stored.refreshToken, isNull);
    });
  });

  group('TokenStore', () {
    test('moves the old token out of shared preferences', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'legacy-token'});
      final backendStore = MemorySecretBackend();
      final first = TokenStore(backend: backendStore, web: false);

      expect((await first.read('https://api.example/api')).accessToken,
          'legacy-token');
      expect((await SharedPreferences.getInstance()).getString('jwt_token'),
          isNull);
      // A restarted app finds it in the secret store.
      final second = TokenStore(backend: backendStore, web: false);
      expect((await second.read('https://api.example/api')).accessToken,
          'legacy-token');
    });

    test('keeps tokens per server', () async {
      await store.startSession('https://a.example/api', accessToken: 'a');
      expect((await store.read('https://b.example/api')).accessToken, isNull);
      await store.clear('https://a.example/api');
      expect((await store.read('https://a.example/api')).accessToken, isNull);
    });

    test('web keeps nothing outside memory', () async {
      final secrets = MemorySecretBackend();
      final web = TokenStore(backend: secrets, web: true);
      await web.startSession('https://a.example/api', accessToken: 'a');

      expect((await web.read('https://a.example/api')).accessToken, 'a');
      expect(await secrets.read('qontract.access|https://a.example/api'), isNull);
    });
  });

  group('checkSession', () {
    test('on web refreshes first, then validates the user', () async {
      store = TokenStore.shared =
          TokenStore(backend: MemorySecretBackend(), web: true);
      await withBackend(_Backend(), () async {
        final api = ApiService(baseUrl: backend.baseUrl);
        final provider = AuthProvider(api: api, storage: _Storage());

        expect(await provider.checkSession(), isTrue);

        final order = backend.requests.map((r) => r.path).toList();
        expect(order, ['/auth/refresh', '/auth/me']);
        expect(backend.requests.last.authorization, 'Bearer new-access');
        expect(provider.user!.email, 'a@b.c');
      });
    });

    test('on web an ended session logs the user out', () async {
      store = TokenStore.shared =
          TokenStore(backend: MemorySecretBackend(), web: true);
      await withBackend(_Backend(refreshStatus: 401), () async {
        final provider = AuthProvider(
            api: ApiService(baseUrl: backend.baseUrl), storage: _Storage());

        expect(await provider.checkSession(), isFalse);
        expect(provider.isAuthenticated, isFalse);
        expect(backend.count('/auth/me'), 0);
      });
    });

    test('on web offline keeps the cached user', () async {
      store = TokenStore.shared =
          TokenStore(backend: MemorySecretBackend(), web: true);
      await withBackend(_Backend(refreshStatus: 503), () async {
        final provider = AuthProvider(
            api: ApiService(baseUrl: backend.baseUrl), storage: _Storage());

        expect(await provider.checkSession(), isTrue);
        expect(provider.isAuthenticated, isTrue);
        expect(unauthorized, 0);
      });
    });

    test('on mobile refreshes only when the access token has expired',
        () async {
      await withBackend(_Backend(), () async {
        await _seed(store, backend.baseUrl, access: 'new-access');
        final api = ApiService(baseUrl: backend.baseUrl);
        expect(await AuthProvider(api: api, storage: _Storage()).checkSession(),
            isTrue);
        expect(backend.count('/auth/refresh'), 0);

        await _seed(store, backend.baseUrl, expiresIn: const Duration(minutes: -5));
        expect(await AuthProvider(api: api, storage: _Storage()).checkSession(),
            isTrue);
        expect(backend.count('/auth/refresh'), 1);
      });
    });
  });
}
