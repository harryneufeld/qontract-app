import 'package:flutter/foundation.dart';

import '../models/contract.dart';
import '../services/api_service.dart';

/// Contract list state backed by the backend API.
class ContractProvider with ChangeNotifier {
  final ApiService _api;

  List<Contract> _contracts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  Contract? _selectedContract;

  ContractProvider({ApiService? api}) : _api = api ?? ApiService();

  List<Contract> get contracts => _contracts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  Contract? get selectedContract => _selectedContract;

  void setSelectedContract(Contract? contract) {
    _selectedContract = contract;
    notifyListeners();
  }

  Future<void> fetchContracts() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _contracts = await _api.getContracts();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh without a full-screen spinner (pull-to-refresh).
  Future<void> refreshContracts() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      _contracts = await _api.getContracts();
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<Contract?> createContract(Contract contract) async {
    try {
      final created = await _api.createContract(contract);
      _contracts.insert(0, created);
      _errorMessage = null;
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateContract(Contract contract) async {
    try {
      final updated = await _api.updateContract(contract.id, contract);
      final index = _contracts.indexWhere((c) => c.id == updated.id);
      if (index != -1) {
        _contracts[index] = updated;
      }
      if (_selectedContract?.id == updated.id) {
        _selectedContract = updated;
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContract(int id) async {
    try {
      await _api.deleteContract(id);
      _contracts.removeWhere((c) => c.id == id);
      if (_selectedContract?.id == id) {
        _selectedContract = null;
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// In-memory filter (client-side) for the search field.
  List<Contract> searchContracts(String query) {
    final q = query.toLowerCase();
    return _contracts
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            (c.counterparty ?? '').toLowerCase().contains(q) ||
            (c.description ?? '').toLowerCase().contains(q))
        .toList();
  }

  List<Contract> getExpiringContracts() =>
      _contracts.where((c) => c.isExpiringSoon && !c.isExpired).toList();

  int get activeCount =>
      _contracts.where((c) => c.status == ContractStatus.active).length;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
