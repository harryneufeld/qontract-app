import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/address.dart';
import '../models/contract.dart';
import '../models/contractor.dart';
import '../models/document.dart';
import '../models/user.dart';

/// Single HTTP client for the Qontract backend.
///
/// Base URL defaults to the local dev API (http on 65533). Override with
/// `ApiService(baseUrl: ...)` for other environments — e.g. a production
/// host, or the platform-appropriate localhost when the app runs on a
/// device (10.0.2.2 on Android emulators).
///
/// Configuration priority (see [resolveApiBaseUrl]):
/// explicit argument > `--dart-define=QONTRACT_API_BASE_URL` > runtime
/// environment variable `QONTRACT_API_BASE_URL` > default.
class ApiService {
  static const String defaultBaseUrl = kDefaultApiBaseUrl;

  final Dio _dio;
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = resolveApiBaseUrl(explicit: baseUrl),
        _dio = Dio(
          BaseOptions(
            baseUrl: resolveApiBaseUrl(explicit: baseUrl),
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

  /// GET /contracts, optionally offset-paged (issue #21 / backend#43).
  ///
  /// When [page] &gt; 0 and [pageSize] &gt; 0 a single page is requested
  /// (`?page=&pageSize=`); otherwise the backend returns the full list
  /// (historic behaviour). Returns the raw JSON rows so callers can page.
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0}) async {
    try {
      final query = <String, dynamic>{};
      if (page > 0 && pageSize > 0) {
        query['page'] = page;
        query['pageSize'] = pageSize;
      }
      final response =
          await _dio.get('/contracts', queryParameters: query.isEmpty ? null : query);
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

  // -------------------------------------------------------------- documents

  Future<List<Document>> getDocuments(int contractId) async {
    try {
      final response = await _dio.get('/documents/contract/$contractId/documents');
      final list = response.data as List<dynamic>;
      return list
          .map((json) => Document.fromJson(
              (json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // -------------------------------------------------------------- contractors

  Future<List<Contractor>> getContractors() async {
    try {
      final response = await _dio.get('/contractors');
      final list = response.data as List<dynamic>;
      return list
          .map((json) => Contractor.fromJson(
              (json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Contractor> getContractor(int id) async {
    try {
      final response = await _dio.get('/contractors/$id');
      return Contractor.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// POST /contractors. The server scopes the new contractor to the
  /// authenticated tenant and sets the audit fields.
  Future<Contractor> createContractor(Contractor contractor) async {
    try {
      final response =
          await _dio.post('/contractors', data: contractor.toCreateJson());
      return Contractor.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PUT /contractors/{id} — updates the editable fields (name, type,
  /// contact info). Active state is not changed here.
  Future<Contractor> updateContractor(Contractor contractor) async {
    try {
      final response =
          await _dio.put('/contractors/${contractor.id}', data: contractor.toUpdateJson());
      return Contractor.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PATCH /contractors/{id}/deactivate — soft deactivates the contractor
  /// so it is kept for history but no longer selectable on new contracts.
  Future<Contractor> deactivateContractor(int id) async {
    try {
      final response = await _dio.patch('/contractors/$id/deactivate');
      return Contractor.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // ---------------------------------------------------------------- addresses

  /// GET /contractors/{id}/addresses — active addresses of a contractor
  /// (backend #41). Returns an empty list when the contractor has none.
  Future<List<Address>> getContractorAddresses(int contractorId) async {
    try {
      final response = await _dio.get('/contractors/$contractorId/addresses');
      final list = response.data as List<dynamic>;
      return list
          .map((json) =>
              Address.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// POST /addresses — creates a contractor address. The server scopes it to
  /// the authenticated tenant; [address.contractorId] must be set and
  /// [address.toCreateJson()] always stamps the `Contractor` entity type.
  Future<Address> createAddress(Address address) async {
    try {
      final response = await _dio.post('/addresses', data: address.toCreateJson());
      return Address.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PUT /addresses/{id} — updates an existing address in place.
  Future<Address> updateAddress(Address address) async {
    try {
      final response =
          await _dio.put('/addresses/${address.id}', data: address.toUpdateJson());
      return Address.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PATCH /addresses/{id}/deactivate — soft-deletes an address so it is
  /// excluded from reads while keeping the row for history.
  Future<Address> deactivateAddress(int id) async {
    try {
      final response = await _dio.patch('/addresses/$id/deactivate');
      return Address.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Uploads a file to the given contract. [fileData] is the raw file
  /// content; it is base64-encoded and sent as a JSON body (the backend
  /// stores the bytes and derives the size server-side).
  Future<Document> uploadDocument(
    int contractId, {
    required String fileName,
    required String fileType,
    required List<int> fileData,
  }) async {
    try {
      final response = await _dio
          .post('/documents/contract/$contractId/documents', data: {
        'fileName': fileName,
        'fileType': fileType,
        'fileData': base64Encode(fileData),
        'contractId': contractId,
      });
      return Document.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      await _dio.delete('/documents/$id');
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Downloads the raw bytes of a document.
  Future<List<int>> downloadDocument(int id) async {
    try {
      final response = await _dio
          .get<List<int>>('/documents/$id/download',
              options: Options(responseType: ResponseType.bytes));
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw Exception('Download returned no data.');
      }
      return data;
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
