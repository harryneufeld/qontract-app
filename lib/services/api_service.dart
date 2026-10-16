import '../l10n/strings.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/staging_certificate_stub.dart'
    if (dart.library.io) '../config/staging_certificate_io.dart';
import '../models/address.dart';
import '../models/contract.dart';
import '../models/contract_stats.dart';
import '../models/contractor.dart';
import '../models/document.dart';
import '../models/invoice.dart';
import '../models/user.dart';

/// Single HTTP client for the qontract backend.
///
/// Base URL defaults to the local dev API (http on 65533). Override with
/// `ApiService(baseUrl: ...)` for other environments — e.g. a production
/// host, or the platform-appropriate localhost when the app runs on a
/// device (10.0.2.2 on Android emulators).
///
/// Configuration priority (see [resolveApiBaseUrl]):
/// explicit argument > host selected in the app >
/// `--dart-define=QONTRACT_API_BASE_URL` > runtime environment variable
/// `QONTRACT_API_BASE_URL` > default.
class ApiService {
  static const String defaultBaseUrl = kDefaultApiBaseUrl;

  final Dio _dio;
  final String? _explicitBaseUrl;

  /// Resolved per request, so a host switch applies to existing instances.
  String get baseUrl => resolveApiBaseUrl(explicit: _explicitBaseUrl);

  ApiService({String? baseUrl})
      : _explicitBaseUrl = baseUrl,
        _dio = Dio(
          BaseOptions(
            baseUrl: resolveApiBaseUrl(explicit: baseUrl),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    configureStagingCertificateTrust(_dio, this.baseUrl);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = this.baseUrl;
        options.headers['Accept-Language'] = S.languageCode;
        final token = await getToken();
        if (options.extra['publicAuth'] != true &&
            token != null &&
            token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Expired/invalid token: clear the session so the UI can re-login.
        if (error.response?.statusCode == 401 &&
            error.requestOptions.extra['publicAuth'] != true &&
            error.requestOptions.path != '/auth/login') {
          final token = await getToken();
          final requestToken = error.requestOptions.headers['Authorization'];
          // A late response from the previous tenant/session must not clear
          // the replacement token after a successful switch.
          if (requestToken == (token == null ? null : 'Bearer $token')) {
            await clearToken();
            onUnauthorized?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  /// Called when a 401 clears the stored token (wired up by AuthProvider).
  static void Function()? onUnauthorized;

  // ---------------------------------------------------------------- tokens

  static const String _tokenKey = 'jwt_token';
  static int _sessionGeneration = 0;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _sessionGeneration++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _sessionGeneration++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ------------------------------------------------------------------- auth

  /// POST /auth/login -> { accessToken, userId, email, expiresAt, user }
  Future<AuthResult> login(String email, String password) async {
    final generation = _sessionGeneration;
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
        throw Exception(S.current.loginResponseDidNotIncludeAUser);
      }
      if (generation != _sessionGeneration) {
        throw ApiException(message: S.current.yourSessionChangedPleaseTryAgain);
      }
      await saveToken(token);
      return AuthResult(token: token, user: user);
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// POST /auth/logout revokes the server session; always clear the local token.
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } on DioException {
      // Logout is best-effort; the token is cleared locally regardless.
    }
    await clearToken();
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await _dio.post('/auth/forgot-password',
          data: {'email': email},
          options: Options(extra: {'publicAuth': true}));
    } on DioException catch (e) {
      throw _resetException(e);
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _dio.post('/auth/reset-password',
          data: {'token': token, 'newPassword': newPassword},
          options: Options(extra: {'publicAuth': true}));
    } on DioException catch (e) {
      throw _resetException(e);
    }
  }

  Exception _resetException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 429) {
      return ApiException(
          message: S.current.tooManyRequestsPleaseTryAgainLater,
          statusCode: status);
    }
    if (status == 400 || status == 409 || status == 503) {
      return ApiException(
          message: _extractFieldError(e) ??
              S.current.unableToCompleteResetPleaseTryAgain,
          statusCode: status);
    }
    return _toApiException(e);
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

  /// POST /auth/change-password — self-service password change for the
  /// authenticated user (app#11). Throws [ApiException] with the server's
  /// field-error message when the current password is wrong.
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  // -------------------------------------------------------------- contracts

  Future<dynamic> _membershipRequest(String method, String path,
      {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.request(path,
          data: data, options: Options(method: method));
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  Future<List<Invoice>> getInvoices(
      {int? contractId, bool deleted = false, int page = 1}) async {
    final path =
        '/invoices?deleted=$deleted&page=$page&pageSize=50${contractId == null ? '' : '&contractId=$contractId'}';
    return (await _membershipRequest('GET', path) as List)
        .map((row) => Invoice.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Document> getDocument(int id) async =>
      Document.fromJson(Map<String, dynamic>.from(
          await _membershipRequest('GET', '/documents/$id') as Map));
  Future<Invoice> saveInvoice(Map<String, dynamic> data, {String? id}) async =>
      Invoice.fromJson(Map<String, dynamic>.from(await _membershipRequest(
          id == null ? 'POST' : 'PUT',
          id == null ? '/invoices' : '/invoices/$id',
          data: data) as Map));
  Future<void> archiveInvoice(String id) async {
    await _membershipRequest('DELETE', '/invoices/$id');
  }

  Future<List<Document>> getLibraryDocuments(
          {String scope = 'Tenant',
          bool deleted = false,
          int page = 1}) async =>
      (await _membershipRequest('GET',
                  '/documents?scope=$scope&deleted=$deleted&page=$page&pageSize=50')
              as List)
          .map(
              (row) => Document.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
  Future<Document> uploadLibraryDocument(
          {required String scope,
          required String fileName,
          required String fileType,
          required List<int> fileData,
          String? title,
          String? description,
          String? category,
          DateTime? documentDate}) async =>
      Document.fromJson(Map<String, dynamic>.from(
          await _membershipRequest('POST', '/documents?scope=$scope', data: {
        'fileName': fileName,
        'fileType': fileType,
        'fileData': base64Encode(fileData),
        'title': title,
        'description': description,
        'category': category,
        if (documentDate != null) 'documentDate': _dateOnlyIso(documentDate),
      }) as Map));
  Future<Document> patchLibraryMetadata(
          int id, Map<String, dynamic> data) async =>
      Document.fromJson(Map<String, dynamic>.from(await _membershipRequest(
          'PATCH', '/documents/$id/metadata',
          data: data) as Map));
  Future<Document> restoreDocument(int id) async =>
      Document.fromJson(Map<String, dynamic>.from(
          await _membershipRequest('POST', '/documents/$id/restore') as Map));
  Future<List<Document>> getDocumentVersions(int id) async =>
      (await _membershipRequest('GET', '/documents/$id/versions') as List)
          .map(
              (row) => Document.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
  Future<Document> reuploadDocument(int id,
          {required String fileName,
          required String fileType,
          required List<int> fileData}) async =>
      Document.fromJson(Map<String, dynamic>.from(
          await _membershipRequest('POST', '/documents/$id/reupload', data: {
        'fileName': fileName,
        'fileType': fileType,
        'fileData': base64Encode(fileData),
      }) as Map));

  Future<void> restoreInvoice(String id) async {
    await _membershipRequest('POST', '/invoices/$id/restore');
  }

  Future<Document> setDocumentContractLink(int id, int contractId,
          {required bool linked}) async =>
      Document.fromJson(Map<String, dynamic>.from(await _membershipRequest(
          linked ? 'POST' : 'DELETE',
          '/documents/$id/contracts/$contractId') as Map));

  Future<AuthResult> _newSession(String path, Map<String, dynamic> data) async {
    final generation = _sessionGeneration;
    final result = Map<String, dynamic>.from(
        await _membershipRequest('POST', path, data: data) as Map);
    final user =
        User.fromJson(Map<String, dynamic>.from(result['user'] as Map));
    final token = result['accessToken'] as String;
    if (generation != _sessionGeneration) {
      throw ApiException(message: S.current.yourSessionChangedPleaseTryAgain);
    }
    await saveToken(token);
    return AuthResult(token: token, user: user);
  }

  Future<bool> publicRegistrationAllowed() async =>
      (await _membershipRequest('GET', '/auth/registration')
          as Map)['allowPublic'] ==
      true;

  Future<AuthResult> register(Map<String, dynamic> fields) =>
      _newSession('/auth/register', fields);

  Future<AuthResult> switchTenant(int tenantId) =>
      _newSession('/auth/switch-tenant', {'tenantId': tenantId});

  Future<AuthResult> redeemInvitation(String code) =>
      _newSession('/auth/invitations/redeem', {'code': code.trim()});

  Future<List<Map<String, dynamic>>> _membershipList(String path) async =>
      (await _membershipRequest('GET', path) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  Future<List<Map<String, dynamic>>> getMemberships() =>
      _membershipList('/auth/memberships');

  Future<List<Map<String, dynamic>>> getTenantMembers(int tenantId) =>
      _membershipList('/tenants/$tenantId/members');

  Future<List<Map<String, dynamic>>> getTenantInvitations(int tenantId) =>
      _membershipList('/tenants/$tenantId/invitations');

  Future<void> updateMember(int tenantId, int userId,
      {String? role, bool? isActive}) async {
    await _membershipRequest('PATCH', '/tenants/$tenantId/members/$userId',
        data: {
          if (role != null) 'role': role,
          if (isActive != null) 'isActive': isActive
        });
  }

  Future<void> removeMember(int tenantId, int userId) async {
    await _membershipRequest('DELETE', '/tenants/$tenantId/members/$userId');
  }

  Future<Map<String, dynamic>> inviteMember(int tenantId,
          {String? email, String role = 'User'}) async =>
      Map<String, dynamic>.from(await _membershipRequest(
          'POST', '/tenants/$tenantId/invitations',
          data: {
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
            'role': role,
          }) as Map);

  Future<void> revokeInvitation(int tenantId, String invitationId) async {
    await _membershipRequest(
        'DELETE', '/tenants/$tenantId/invitations/$invitationId');
  }

  Future<Map<String, dynamic>> createTenant(String name, String type) async =>
      Map<String, dynamic>.from(await _membershipRequest('POST', '/tenants',
          data: {'name': name.trim(), 'type': type}) as Map);

  Future<List<Map<String, dynamic>>> getResponsibleMembers() async =>
      (await _membershipRequest('GET', '/contracts/members') as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

  Future<List<Contract>> getContractTrash() async =>
      (await _membershipRequest('GET', '/contracts?trash=true') as List)
          .map((c) => Contract.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();

  Future<Contract> restoreContract(int id) async =>
      Contract.fromJson(Map<String, dynamic>.from(
          await _membershipRequest('POST', '/contracts/$id/restore') as Map));

  Future<String> getDefaultCurrency() async =>
      (await _membershipRequest('GET', '/contracts/default-currency')
          as Map)['currency'] as String;

  Future<int> applyTenantCurrency(int id,
          {bool replaceExisting = false}) async =>
      ((await _membershipRequest('POST', '/tenants/$id/apply-default-currency',
                  data: {'replaceExisting': replaceExisting})
              as Map)['changedContracts'] as num)
          .toInt();

  Future<Map<String, dynamic>> getTenantDetails(int id) async =>
      Map<String, dynamic>.from(
          await _membershipRequest('GET', '/tenants/$id') as Map);

  Future<void> updateTenantSettings(int id, String settings) async {
    await _membershipRequest('PUT', '/tenants/$id',
        data: {'settings': settings});
  }

  Future<void> renameTenant(int tenantId, String name) async {
    await _membershipRequest('PUT', '/tenants/$tenantId',
        data: {'name': name.trim()});
  }

  /// GET /contracts, optionally offset-paged (issue #21 / backend#43).
  ///
  /// When [page] &gt; 0 and [pageSize] &gt; 0 a single page is requested
  /// (`?page=&pageSize=`); otherwise the backend returns the full list
  /// (historic behaviour). [status] restricts the result to one
  /// dashboard bucket (`active`/`expiring`/`expired`/`minDate`, app#36)
  /// server-side, so a filtered view covers ALL of the tenant's matching
  /// contracts, not only the loaded slice. Returns the raw JSON rows so
  /// callers can page.
  Future<List<Contract>> getContracts({
    int page = 0,
    int pageSize = 0,
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (page > 0 && pageSize > 0) {
        query['page'] = page;
        query['pageSize'] = pageSize;
      }
      if (status != null) {
        query['status'] = status;
      }
      final response = await _dio.get('/contracts',
          queryParameters: query.isEmpty ? null : query);
      final list = response.data as List<dynamic>;
      return list
          .map((json) =>
              Contract.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// GET /contracts without paging or filtering — the tenant's FULL
  /// contract list (historic behaviour). Used for tenant-wide aggregates
  /// that must not shrink with the loaded page or an active quick filter
  /// (the dashboard cost summary, app#36).
  Future<List<Contract>> getContractList() => getContracts();

  Future<Contract> getContract(int id) async {
    try {
      final response = await _dio.get('/contracts/$id');
      return Contract.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// GET /contracts/stats — tenant-wide counters for the dashboard stat
  /// chips (app#33). The list endpoint above is paginated, so the chips
  /// cannot count from the loaded slice.
  Future<ContractStats> getContractStats() async {
    try {
      final response = await _dio
          .get('/contracts/stats', queryParameters: {'scope': 'tenant'});
      return ContractStats.fromJson(
          (response.data as Map).cast<String, dynamic>());
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
      final response =
          await _dio.put('/contracts/$id', data: contract.toJson());
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
      final response =
          await _dio.get('/documents/contract/$contractId/documents');
      final list = response.data as List<dynamic>;
      return list
          .map((json) =>
              Document.fromJson((json as Map).cast<String, dynamic>()))
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
          .map((json) =>
              Contractor.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Contractor> getContractor(int id) async {
    try {
      final response = await _dio.get('/contractors/$id');
      return Contractor.fromJson(
          (response.data as Map).cast<String, dynamic>());
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
      return Contractor.fromJson(
          (response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PUT /contractors/{id} — updates the editable fields (name, type,
  /// contact info). Active state is not changed here.
  Future<Contractor> updateContractor(Contractor contractor) async {
    try {
      final response = await _dio.put('/contractors/${contractor.id}',
          data: contractor.toUpdateJson());
      return Contractor.fromJson(
          (response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PATCH /contractors/{id}/deactivate — soft deactivates the contractor
  /// so it is kept for history but no longer selectable on new contracts.
  Future<Contractor> activateContractor(int id) async {
    try {
      final response = await _dio.patch('/contractors/$id/activate');
      return Contractor.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Contractor> deactivateContractor(int id) async {
    try {
      final response = await _dio.patch('/contractors/$id/deactivate');
      return Contractor.fromJson(
          (response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  // ---------------------------------------------------------------- addresses

  Future<List<Address>> getMyAddresses() => _addressList('/addresses/me');
  Future<List<Address>> getTenantAddresses() =>
      _addressList('/addresses/tenant');

  Future<List<Address>> _addressList(String path) async {
    try {
      final response = await _dio.get(path);
      return (response.data as List)
          .map(
              (json) => Address.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// GET /contractors/{id}/addresses — active addresses of a contractor
  /// (backend #41). Returns an empty list when the contractor has none.
  Future<List<Address>> getContractorAddresses(int contractorId) async {
    try {
      final response = await _dio.get('/contractors/$contractorId/addresses');
      final list = response.data as List<dynamic>;
      return list
          .map(
              (json) => Address.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// POST /addresses — creates an address in its declared entity scope.
  /// Account and tenant owners come from the authenticated identity.
  Future<Address> createAddress(Address address) async {
    try {
      final response =
          await _dio.post('/addresses', data: address.toCreateJson());
      return Address.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// PUT /addresses/{id} — updates an existing address in place.
  Future<Address> updateAddress(Address address) async {
    try {
      final response = await _dio.put('/addresses/${address.id}',
          data: address.toUpdateJson());
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
  ///
  /// [title] and [documentDate] are the user-editable metadata (app#5);
  /// omit them to keep the backend defaults.
  Future<Document> uploadDocument(
    int contractId, {
    required String fileName,
    required String fileType,
    required List<int> fileData,
    String? title,
    DateTime? documentDate,
  }) async {
    try {
      final response =
          await _dio.post('/documents/contract/$contractId/documents', data: {
        'fileName': fileName,
        'fileType': fileType,
        'fileData': base64Encode(fileData),
        'contractId': contractId,
        if ((title?.trim() ?? '').isNotEmpty) 'title': title!.trim(),
        if (documentDate != null) 'documentDate': _dateOnlyIso(documentDate),
      });
      return Document.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// Updates the user-editable metadata of a document — title and/or
  /// document date (app#5) — via `PATCH /api/documents/{id}/metadata`.
  /// Null fields are left untouched server-side; an empty title clears it.
  Future<Document> updateDocumentMetadata(
    int id, {
    String? title,
    DateTime? documentDate,
  }) async {
    try {
      final response = await _dio.patch('/documents/$id/metadata', data: {
        if (title != null) 'title': title,
        if (documentDate != null) 'documentDate': _dateOnlyIso(documentDate),
      });
      return Document.fromJson((response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _toApiException(e, fieldErrors: true);
    }
  }

  /// Date-only ISO format (yyyy-MM-dd) for document dates.
  static String _dateOnlyIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
      final response = await _dio.get<List<int>>('/documents/$id/download',
          options: Options(responseType: ResponseType.bytes));
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw Exception(S.current.downloadReturnedNoData);
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
              ? _extractFieldError(e) ?? S.current.invalidRequest
              : S.current.badRequest,
          statusCode: 400,
        );
      case 401:
        return ApiException(
            message: e.requestOptions.path == '/auth/login'
                ? S.current.invalidEmailOrPassword
                : S.current.sessionExpiredPleaseLoginAgain,
            statusCode: 401);
      case 403:
        return ApiException(
            message: S.current.youDoNotHavePermissionToDoThis, statusCode: 403);
      case 404:
        return ApiException(
            message: S.current.thisItemNoLongerExists, statusCode: 404);
      case 409:
        return ApiException(
            message: _extractFieldError(e) ?? S.current.conflict,
            statusCode: 409);
      case 429:
        return ApiException(
            message: S.current.tooManyRequestsPleaseTryAgainLater,
            statusCode: 429);
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError) {
          return ApiException(
              message: S.current.cannotReachTheQontractServerIsItRunning);
        }
        return ApiException(
            message: S.current.serverErrorPleaseTryAgain(
                (status ?? S.current.unknownStatus)));
    }
  }

  /// Pulls the first fluent-validation / model-state error message from a
  /// 400 response body.
  static String? _extractFieldError(DioException e) {
    // An older server may still return English. Never expose an untranslated
    // diagnostic in German; the generic localized message retains safe behavior.
    if (S.languageCode == 'de' &&
        e.response?.headers.value('content-language')?.split('-').first !=
            'de') {
      return S.current.invalidRequest;
    }
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
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
