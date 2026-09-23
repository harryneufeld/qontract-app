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
  final DateTime Function() _now;

  ContractProvider({ApiService? api, DateTime Function()? now})
      : _api = api ?? ApiService(),
        _now = now ?? DateTime.now;

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
  ///
  /// [contractorNames] (contractor id -> name) is matched as well, so
  /// searching by counterparty (contractor) name keeps working now that
  /// the free-text `counterparty` field is gone.
  List<Contract> searchContracts(
    String query, {
    Map<int, String>? contractorNames,
  }) {
    final q = query.toLowerCase();
    return _contracts
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            (c.description ?? '').toLowerCase().contains(q) ||
            ((contractorNames?[c.contractorId ?? 0]) ?? '')
                .toLowerCase()
                .contains(q))
        .toList();
  }

  /// In-memory filter (client-side) for the dashboard quick-filter chips
  /// (issue #20): the four status-based lists, composable with the search
  /// field. `null`/`'all'` means "show everything".
  List<Contract> filterByStatus(String status) {
    switch (status) {
      case 'active':
        return contracts
            .where((c) => c.status == ContractStatus.active)
            .toList();
      case 'expiring':
        return getExpiringContracts();
      case 'expired':
        return getExpiredContracts();
      case 'minDate':
        return getMinDateApproachingContracts();
      default:
        return contracts;
    }
  }

  /// In-memory filter (client-side) for the dashboard quick-filter chips
  /// (issue #20): contracts linked to [contractorId].
  List<Contract> filterByContractor(int contractorId) =>
      _contracts.where((c) => c.contractorId == contractorId).toList();

  /// In-memory filter (client-side) for the dashboard quick-filter chips
  /// (issue #20): active contracts ending within the next [days] days.
  List<Contract> filterByEndingWithinDays(int days) {
    final start = _now();
    final end = start.add(Duration(days: days));
    return _contracts
        .where((c) {
          if (c.status != ContractStatus.active) return false;
          final d = _parseDate(c.endDate);
          if (d == null) return false;
          final day = DateTime(d.year, d.month, d.day);
          final from = DateTime(start.year, start.month, start.day);
          final to = DateTime(end.year, end.month, end.day);
          return !day.isBefore(from) && !day.isAfter(to);
        })
        .toList();
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  List<Contract> getExpiringContracts() =>
      _contracts.where((c) => c.isExpiringSoon && !c.isExpired).toList();

  /// Contracts that have expired — their end date has already passed, or
  /// they are explicitly marked with the `Expired` status. Mirrors the
  /// date-driven "Expiring" filter above (a contract can be expired even
  /// while still carrying a non-`Expired` status, e.g. still `Active`).
  List<Contract> getExpiredContracts() => _contracts
      .where((c) => c.isExpired || c.status == ContractStatus.expired)
      .toList();

  int get expiredCount => getExpiredContracts().length;

  /// Contracts whose minimum contract date (the earliest date the
  /// contract can end) falls within the next [days] days — or has
  /// already passed. Contracts without a minimum date are ignored, as
  /// are non-active contracts (nothing to plan for drafts, expired or
  /// terminated ones). Sorted with the most urgent (earliest minimum
  /// date) first.
  List<Contract> getMinDateApproachingContracts({int days = 90}) {
    return _contracts
        .where((c) =>
            c.status == ContractStatus.active &&
            c.reachesMinimumContractDateIn(days: days))
        .toList()
      ..sort((a, b) => a.minimumContractDateTime!
          .compareTo(b.minimumContractDateTime!));
  }

  int get activeCount =>
      _contracts.where((c) => c.status == ContractStatus.active).length;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
