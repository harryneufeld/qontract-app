import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/contract.dart';

class ContractService {
  static const String baseUrl = 'http://localhost:8080/api';
  late final Dio _dio;

  ContractService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  Future<List<Contract>> fetchContracts() async {
    try {
      final response = await _dio.get('/contracts');
      return (response.data as List)
          .map((json) => Contract.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Contract> getContract(String id) async {
    try {
      final response = await _dio.get('/contracts/$id');
      return Contract.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Contract> createContract(Contract contract) async {
    try {
      final response = await _dio.post('/contracts', data: contract.toJson());
      return Contract.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateContract(String id, Contract contract) async {
    try {
      await _dio.put('/contracts/$id', data: contract.toJson());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteContract(String id) async {
    try {
      await _dio.delete('/contracts/$id');
    } catch (e) {
      rethrow;
    }
  }
}
