import 'session_notifier.dart';

import '../models/address.dart';
import '../services/api_service.dart';

/// Contractor-address state backed by the backend address API (#24).
///
/// The app only ever edits one contractor's addresses at a time, so this
/// provider tracks a single "loaded" contractor and reloads when the caller
/// switches to a different one. All mutations are tenant-scoped on the
/// server side.
class ContractorAddressProvider extends SessionNotifier {
  final ApiService _api;

  int? _contractorId;
  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _errorMessage;

  ContractorAddressProvider({ApiService? api}) : _api = api ?? ApiService();

  /// The contractor whose addresses are currently loaded (null = none yet).
  int? get contractorId => _contractorId;

  /// The contractor's active addresses, most recent first.
  List<Address> get addresses => _addresses;

  /// The single address used as "the" postal address (the most recent one),
  /// or null when the contractor has none.
  Address? get primary => _addresses.isNotEmpty ? _addresses.first : null;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool _owns(int? id) => _contractorId == id;

  /// Loads (or reloads) the active addresses for [contractorId]. A no-op only
  /// when that contractor is already loaded and idle (call with [force] to
  /// refetch). Switching to a different contractor always reloads.
  Future<void> loadAddresses(int contractorId, {bool force = false}) async {
    if (!force && _contractorId == contractorId && !_isLoading) {
      return; // already loaded and idle for this contractor
    }
    _contractorId = contractorId;
    _setLoading(true);
    _errorMessage = null;
    try {
      final list = await _api.getContractorAddresses(contractorId);
      if (!_owns(contractorId)) return; // a newer load superseded this one
      // Most recent first (backend returns id-ascending).
      _addresses = list..sort((a, b) => b.id.compareTo(a.id));
      notifyListeners();
    } on ApiException catch (e) {
      if (!_owns(contractorId)) return;
      _errorMessage = e.message;
      _addresses = [];
      notifyListeners();
    } finally {
      if (_owns(contractorId)) {
        _setLoading(false);
      }
    }
  }

  /// Clears the loaded addresses (e.g. when leaving the contractor view).
  void clear() {
    if (_contractorId == null && _addresses.isEmpty && _errorMessage == null) {
      return;
    }
    _contractorId = null;
    _addresses = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Creates a new address for the currently loaded contractor. Returns the
  /// created address (with server id), or null on failure.
  Future<Address?> createAddress(Address address) async {
    final id = _contractorId;
    if (id == null) return null;
    _errorMessage = null;
    try {
      final created =
          await _api.createAddress(address.copyWith(contractorId: id));
      _addresses.insert(0, created);
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing address in place. Returns true on success.
  Future<bool> updateAddress(Address address) async {
    try {
      final updated = await _api.updateAddress(address);
      final idx = _addresses.indexWhere((a) => a.id == updated.id);
      if (idx != -1) _addresses[idx] = updated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Soft-deletes an address, removing it from the list. Returns true on
  /// success.
  Future<bool> removeAddress(Address address) async {
    try {
      await _api.deactivateAddress(address.id);
      _addresses.removeWhere((a) => a.id == address.id);
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
