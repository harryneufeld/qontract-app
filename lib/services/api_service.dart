import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contract.dart';
import '../models/user.dart';

/// Single HTTP client for the Qontract backend.
///
/// Base URL defaults to the local dev API (http on 65533). Override with
/// `ApiService(baseUrl: ...)` for other environments — e.g. a production
/// host, or the platform-appropriate localhost when the app runs on a
/// device (10.0.2.2 on Android emulators).
class ApiService {
  static const String defaultBaseUrl = 'http://localhost:65533/api';

  final Dio _dio;
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Expired/invalid token: clear the session so the UI can re-login.
        if (error.response?.statusCode == 401 &&
            error.requestOptions.path != '/auth/login') {
          await clearToken();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  /// Called when a 401 clears the stored token (wired up by AuthProvider).
  static void Function()? onUnauthorized;

  // ---------------------------------------------------------------- tokens

  static const String _tokenKey = 'jwt_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ------------------------------------------------------------------- auth

  /// POST /auth/login -> { accessToken, userId, email, expiresAt, user }
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      final token = data['accessToken'] as String;
      final userJson = data['user'] as Map<String, dynamic>?;
      final user = userJson == null ? null : User.fromJson(userJson);
      if (user == null) {
        throw Exception('Login response did not include a user.');
      }
      await saveToken(token);
      return AuthResult(token: token, user: user);
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// POST /auth/logout (stateless — the client discards its token).
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException {
      // Logout is best-effort; the token is cleared locally regardless.
    }
    await clearToken();
  }

  /// GET /auth/me — validates the stored token and returns the current user.
  Future<User> me() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // -------------------------------------------------------------- contracts

  Future<List<Contract>> getContracts() async {
    try {
      final response = await _dio.get('/contracts');
      final list = response.data as List<dynamic>;
      return list
          .map((json) => Contract.fromJson(
              (json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Contract> getContract(int id) async {
    try {
      final response = await _dio.get('/contracts/$id');
      return Contract.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Contract> createContract(Contract contract) async {
    try {
      final response = await _dio.post('/contracts', data: contract.toJson());
      return Contract.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  Future<Contract> updateContract(int id, Contract contract) async {
    try {
      final response = await _dio.put('/contracts/$id',
          data: contract.toJson());
      return Contract.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  Future<void> deleteContract(int id) async {
    try {
      await _dio.delete('/contracts/$id');
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // ---------------------------------------------------------------- errors

  Exception _toApiException(DioException e, {bool fieldErrors = false}) {
    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        return ApiException(
          message: fieldErrors
              ? _extractFieldError(e) ?? 'Invalid request.'
              : 'Bad request.',
          statusCode: 400,
        );
      case 401:
        return ApiException(
            message: 'Session expired. Please login again.', statusCode: 401);
      case 403:
        return ApiException(
            message: 'You do not have permission to do this.', statusCode: 403);
      case 404:
        return ApiException(
            message: 'This item no longer exists.', statusCode: 404);
      case 409:
        return ApiException(message: 'Conflict.', statusCode: 409);
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError) {
          return ApiException(
              message: 'Cannot reach the Qontract server. Is it running?');
        }
        return ApiException(
            message: 'Server error (${status ?? 'unknown'}). Please try again.');
    }
  }

  /// Pulls the first fluent-validation / model-state error message from a
  /// 400 response body.
  static String? _extractFieldError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      // ASP.NET Core problem details: { errors: { field: [msg, ...] } }
      final errors = data['errors'] ?? data['Errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        if (first != null) return first.toString();
      }
      final title = data['title'] ?? data['Title'];
      if (title is String &&
          title.isNotEmpty &&
          title.toLowerCase() != 'one or more validation errors occurred.') {
        return title;
      }
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}

/// Result of a successful login.
class AuthResult {
  final String token;
  final User user;

  AuthResult({required this.token, required this.user});
}

/// Normalized API error carrying a user-presentable message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
