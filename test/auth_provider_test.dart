import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

/// In-memory replacement for the shared-prefs backed [StorageService].
class _FakeStorage extends StorageService {
  User? _user;
  int saveCount = 0;
  int clearCount = 0;

  User? get storedUser => _user;

  /// Test helper: seed a previously saved user snapshot.
  set _seed(User? u) => _user = u;

  @override
  Future<void> saveUser(User user) async {
    _user = user;
    saveCount++;
  }

  @override
  Future<User?> getUser() async => _user;

  @override
  Future<void> clearUser() async {
    _user = null;
    clearCount++;
  }
}

/// Configurable [ApiService] stand-in: scripted results per call count.
class _FakeApi extends ApiService {
  _FakeApi() : super(baseUrl: 'http://localhost');

  Object? Function()? loginImpl; // null -> default success
  Object? Function()? meImpl; // null -> default success
  int loginCalls = 0;
  int meCalls = 0;
  int logoutCalls = 0;
  String? lastLoginEmail;
  String? lastLoginPassword;

  @override
  Future<AuthResult> login(String email, String password) async {
    loginCalls++;
    lastLoginEmail = email;
    lastLoginPassword = password;
    final impl = loginImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
      return r as AuthResult;
    }
    return AuthResult(token: 'jwt-1', user: _user(1, 'a@b.c'));
  }

  @override
  Future<User> me() async {
    meCalls++;
    final impl = meImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
      return r as User;
    }
    return _user(1, 'a@b.c');
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

User _user(int id, String email, {String name = 'Alice'}) => User(
      id: id,
      name: name,
      email: email,
      role: 'User',
      tenantId: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late _FakeStorage storage;
  late _FakeApi api;
  late AuthProvider provider;

  setUp(() {
    storage = _FakeStorage();
    api = _FakeApi();
    provider = AuthProvider(api: api, storage: storage);
  });

  group('login', () {
    test('stores the session and reports success', () async {
      final ok = await provider.login('a@b.c', 'secret');

      expect(ok, isTrue);
      expect(api.loginCalls, 1);
      expect(api.lastLoginEmail, 'a@b.c');
      expect(api.lastLoginPassword, 'secret');
      expect(provider.user, isNotNull);
      expect(provider.user!.email, 'a@b.c');
      expect(provider.isAuthenticated, isTrue);
      expect(storage.storedUser, isNotNull);
      expect(storage.storedUser!.email, 'a@b.c');
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('API error (e.g. bad credentials) keeps the user out', () async {
      api.loginImpl = () =>
          ApiException(message: 'Invalid email or password.', statusCode: 400);

      final ok = await provider.login('a@b.c', 'wrong');

      expect(ok, isFalse);
      expect(provider.user, isNull);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage, 'Invalid email or password.');
      expect(storage.storedUser, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('unexpected error is reported as a generic failure', () async {
      api.loginImpl = () => StateError('boom');

      final ok = await provider.login('a@b.c', 'secret');

      expect(ok, isFalse);
      expect(provider.user, isNull);
      expect(provider.errorMessage, isNotNull);
      expect(provider.errorMessage, contains('boom'));
    });

    test('clearError resets the last failure message', () async {
      api.loginImpl = () =>
          ApiException(message: 'Invalid email or password.', statusCode: 400);
      await provider.login('a@b.c', 'wrong');
      expect(provider.errorMessage, isNotNull);

      provider.clearError();

      expect(provider.errorMessage, isNull);
      expect(provider.user, isNull);
    });
  });

  group('logout', () {
    test('calls the API, drops the cached user and the session', () async {
      storage._seed = _user(1, 'a@b.c');
      await provider.checkSession();
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();

      expect(api.logoutCalls, 1);
      expect(provider.user, isNull);
      expect(provider.isAuthenticated, isFalse);
      expect(storage.storedUser, isNull);
      expect(storage.clearCount, 1);
    });
  });

  group('checkSession (session restore)', () {
    test('no saved user: nothing to restore', () async {
      final ok = await provider.checkSession();

      expect(ok, isFalse);
      expect(provider.user, isNull);
      expect(api.meCalls, 0); // server round-trip is pointless without a token
    });

    test('saved user: refreshes from the server and re-caches it', () async {
      storage._seed = _user(1, 'old@b.c', name: 'Old Name');

      final ok = await provider.checkSession();

      expect(ok, isTrue);
      expect(api.meCalls, 1);
      expect(provider.user, isNotNull);
      expect(provider.user!.email, 'a@b.c');
      // The fresh snapshot replaces the cached one.
      expect(storage.storedUser!.email, 'a@b.c');
    });

    test('server 401: the stored session is discarded', () async {
      storage._seed = _user(1, 'a@b.c');
      api.meImpl = () =>
          ApiException(message: 'Session expired. Please login again.',
              statusCode: 401);

      final ok = await provider.checkSession();

      expect(ok, isFalse);
      expect(provider.user, isNull);
      expect(provider.isAuthenticated, isFalse);
      expect(storage.storedUser, isNull);
      expect(storage.clearCount, 1);
    });

    test('server unreachable: the cached user is kept (offline)', () async {
      storage._seed = _user(1, 'a@b.c', name: 'Cached');
      api.meImpl = () => ApiException(
          message: 'Cannot reach the qontract server. Is it running?');

      final ok = await provider.checkSession();

      expect(ok, isTrue);
      expect(provider.user, isNotNull);
      expect(provider.user!.email, 'a@b.c');
      expect(provider.user!.name, 'Cached');
      expect(storage.storedUser, isNotNull); // cache untouched
    });
  });

  group('401 handling (ApiService.onUnauthorized)', () {
    test('a rejected token drops the local session', () async {
      storage._seed = _user(1, 'a@b.c');
      await provider.checkSession();
      expect(provider.isAuthenticated, isTrue);

      // The API layer calls this after clearing the token on a 401.
      ApiService.onUnauthorized?.call();

      expect(provider.user, isNull);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage,
          'Your session expired. Please login again.');
    });

    test('works even when the session was established by login()', () async {
      await provider.login('a@b.c', 'secret');
      expect(provider.isAuthenticated, isTrue);

      ApiService.onUnauthorized?.call();

      expect(provider.user, isNull);
      expect(provider.errorMessage,
          'Your session expired. Please login again.');
    });
  });
}
