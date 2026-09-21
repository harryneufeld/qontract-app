import 'package:flutter/foundation.dart';

import '../models/contractor.dart';
import '../services/api_service.dart';

/// Contractor list state backed by the backend API.
class ContractorProvider with ChangeNotifier {
  final ApiService _api;

  List<Contractor> _contractors = [];
  bool _isLoading = false;
  String? _errorMessage;
  Contractor? _selectedContractor;

  ContractorProvider({ApiService? api}) : _api = api ?? ApiService();

  List<Contractor> get contractors => _contractors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Contractor? get selectedContractor => _selectedContractor;

  void setSelectedContractor(Contractor? contractor) {
    _selectedContractor = contractor;
    notifyListeners();
  }

  Future<void> fetchContractors() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _contractors = await _api.getContractors();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshContractors() async {
    if (_isLoading) return;
    await fetchContractors();
  }

  Future<Contractor?> getContractorDetail(int id) async {
    try {
      return await _api.getContractor(id);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
