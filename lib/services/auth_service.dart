import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/contract.dart';
import './api_service.dart';
import './storage_service.dart';

class AuthService with ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;

  Future<void> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final user = await _api.login(email, password);
      _currentUser = user;
      await _storage.saveUser(user);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
      _currentUser = null;
      await _storage.clearUser();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> checkSession() async {
    final savedUser = await _storage.getUser();
    if (savedUser != null) {
      _currentUser = savedUser;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

class ContractService with ChangeNotifier {
  final ApiService _api = ApiService();
  List<Contract> _contracts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Contract> get contracts => _contracts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchContracts() async {
    _setLoading(true);
    try {
      _contracts = await _api.getContracts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Contract> createContract(Contract contract) async {
    try {
      final newContract = await _api.createContract(contract);
      _contracts.add(newContract);
      _errorMessage = null;
      notifyListeners();
      return newContract;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> updateContract(String id, Contract contract) async {
    try {
      await _api.updateContract(id, contract);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> deleteContract(String id) async {
    try {
      await _api.deleteContract(id);
      _contracts.removeWhere((c) => c.id == id);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  List<Contract> searchContracts(String query) {
    final lowerQuery = query.toLowerCase();
    return _contracts.where((c) =>
        c.title.toLowerCase().contains(lowerQuery) ||
        c.description.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  List<Contract> getExpiringContracts() {
    return _contracts.where((c) => c.isExpiringSoon && !c.isExpired).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
