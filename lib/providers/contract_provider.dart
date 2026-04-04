import 'package:flutter/material.dart';
import '../models/contract.dart';
import '../services/contract_service.dart';

class ContractProvider with ChangeNotifier {
  final ContractService _contractService;

  ContractProvider(this._contractService);

  List<Contract> _contracts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Contract? _selectedContract;

  List<Contract> get contracts => _contracts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Contract? get selectedContract => _selectedContract;

  Future<void> fetchContracts() async {
    _setLoading(true);
    try {
      _contracts = await _contractService.fetchContracts();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchContract(String id) async {
    try {
      _selectedContract = await _contractService.getContract(id);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> createContract(Contract contract) async {
    try {
      final newContract = await _contractService.createContract(contract);
      _contracts.add(newContract);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateContract(String id, Contract contract) async {
    try {
      await _contractService.updateContract(id, contract);
      final index = _contracts.indexWhere((c) => c.id == id);
      if (index != -1) {
        _contracts[index] = contract;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteContract(String id) async {
    try {
      await _contractService.deleteContract(id);
      _contracts.removeWhere((c) => c.id == id);
      if (_selectedContract?.id == id) {
        _selectedContract = null;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
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
