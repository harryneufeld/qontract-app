import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/contract.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:65533/api';
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data;
      await _saveToken(data['token']);
      return User.fromJson(data['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      await _clearToken();
    } on DioException catch (e) {
      // Ignore logout errors
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Contract>> getContracts() async {
    try {
      final response = await _dio.get('/contracts');
      return (response.data as List)
          .map((json) => Contract.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contract> getContract(String id) async {
    try {
      final response = await _dio.get('/contracts/$id');
      return Contract.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contract> createContract(Contract contract) async {
    try {
      final response = await _dio.post('/contracts', data: contract.toJson());
      return Contract.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateContract(String id, Contract contract) async {
    try {
      await _dio.put('/contracts/$id', data: contract.toJson());
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteContract(String id) async {
    try {
      await _dio.delete('/contracts/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    switch (e.response?.statusCode) {
      case 400:
        return Exception('Bad request: ${e.response?.data}');
      case 401:
        return Exception('Unauthorized. Please login again.');
      case 403:
        return Exception('Forbidden: You do not have permission.');
      case 404:
        return Exception('Resource not found.');
      case 500:
        return Exception('Server error. Please try again later.');
      default:
        return Exception('An error occurred: ${e.message}');
    }
  }
}
