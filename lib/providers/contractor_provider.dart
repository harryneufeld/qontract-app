import 'session_notifier.dart';

import '../models/contractor.dart';
import '../services/api_service.dart';

/// Contractor list state backed by the backend API.
class ContractorProvider extends SessionNotifier {
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

  /// Creates a new contractor and inserts it into the list so other screens
  /// (e.g. the contract form dropdown) can use it immediately.
  Future<Contractor?> createContractor(Contractor contractor) async {
    try {
      final created = await _api.createContractor(contractor);
      _contractors.insert(0, created);
      _errorMessage = null;
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Updates the editable fields of an existing contractor.
  Future<bool> updateContractor(Contractor contractor) async {
    try {
      final updated = await _api.updateContractor(contractor);
      _replaceContractor(updated);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Soft-deactivates a contractor. Kept in the list (dimmed) so existing
  /// contracts that reference it stay resolvable.
  Future<bool> deactivateContractor(Contractor contractor) async {
    return _setActive(contractor, false);
  }

  Future<bool> activateContractor(Contractor contractor) async {
    return _setActive(contractor, true);
  }

  Future<bool> _setActive(Contractor contractor, bool active) async {
    try {
      final updated = active
          ? await _api.activateContractor(contractor.id)
          : await _api.deactivateContractor(contractor.id);
      _replaceContractor(updated);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void _replaceContractor(Contractor updated) {
    final index = _contractors.indexWhere((c) => c.id == updated.id);
    if (index == -1) {
      _contractors.add(updated);
    } else {
      _contractors[index] = updated;
    }
    if (_selectedContractor?.id == updated.id) _selectedContractor = updated;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
