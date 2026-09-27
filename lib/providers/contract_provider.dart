import 'package:flutter/foundation.dart';

import '../models/contract.dart';
import '../models/contract_stats.dart';
import '../services/api_service.dart';

/// Contract list state backed by the backend API.
///
/// Loading is offset-paged (issue #21): the dashboard opens by fetching a
/// bounded first page and appends further pages as the user scrolls. The
/// in-memory [contracts] list is the *loaded* slice (pages fetched so far),
/// which the dashboard's stat chips and search/filter use.
class ContractProvider with ChangeNotifier {
  /// Rows per page. Bounded initial load keeps large datasets snappy.
  static const int pageSize = 20;

  final ApiService _api;

  List<Contract> _contracts = [];
  bool _isLoading = false; // first-page load (full-screen spinner)
  bool _isRefreshing = false;
  bool _isLoadingMore = false; // appending a further page
  bool _hasMore = true; // whether another page is expected
  int _page = 0; // highest page fetched so far
  String? _errorMessage;
  Contract? _selectedContract;
  /// Tenant-wide counters from GET /contracts/stats (app#33), or null when
  /// the backend predates the endpoint / the fetch failed. The dashboard
  /// then falls back to counting the loaded slice.
  ContractStats? _stats;
  /// Dashboard status bucket applied to the server-side list fetch
  /// (app#36): 'all' or one of active/expiring/expired/minDate. When
  /// anything but 'all', every list request carries `?status=` so the
  /// loaded slice already covers ALL of the tenant's matching contracts.
  String _statusFilterParam = _statusFilterAll;
  /// Tenant-wide (unfiltered, unpaginated) contract set for tenant-wide
  /// aggregates such as the cost summary (app#36): the summary must not
  /// shrink with the loaded page or an active quick filter. Null until
  /// the first successful full fetch.
  List<Contract>? _allContracts;
  final DateTime Function() _now;

  static const String _statusFilterAll = 'all';

  ContractProvider({ApiService? api, DateTime Function()? now})
      : _api = api ?? ApiService(),
        _now = now ?? DateTime.now;

  List<Contract> get contracts => _contracts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  Contract? get selectedContract => _selectedContract;
  ContractStats? get stats => _stats;
  /// The dashboard status bucket currently applied to list fetches
  /// (app#36); `'all'` means unfiltered.
  String get statusFilter => _statusFilterParam;
  /// Tenant-wide contract set for aggregates like the cost summary
  /// (app#36). Falls back to the loaded slice until the full list has
  /// been fetched (or when the fetch fails).
  List<Contract> get costContracts => _allContracts ?? _contracts;

  void setSelectedContract(Contract? contract) {
    _selectedContract = contract;
    notifyListeners();
  }

  /// First load: replace the list with page 1. Backward compatible — an
  /// API that ignores paging returns one page that fills [hasMore]=false.
  Future<void> fetchContracts() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      var page = 1;
      var items = await _api.getContracts(
          page: page, pageSize: pageSize, status: _queryStatus);
      _page = page;
      _contracts = List.of(items);
      _hasMore = items.length >= pageSize;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
    fetchStats();
    fetchAllContracts();
  }

  /// Load the next page and append it (infinite scroll). A short page
  /// (fewer than [pageSize] rows) signals the end of the list.
  Future<void> loadMore() async {
    if (_isLoading || _isRefreshing || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final items = await _api.getContracts(
          page: next, pageSize: pageSize, status: _queryStatus);
      _page = next;
      _contracts.addAll(items);
      _hasMore = items.length >= pageSize;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh without a full-screen spinner (pull-to-refresh).
  Future<void> refreshContracts() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      var items = await _api.getContracts(
          page: 1, pageSize: pageSize, status: _queryStatus);
      _page = 1;
      _contracts = List.of(items);
      _hasMore = items.length >= pageSize;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
    fetchStats();
    fetchAllContracts();
  }

  /// The `?status=` value for list requests (app#36); null when the
  /// dashboard shows the unfiltered list.
  String? get _queryStatus =>
      _statusFilterParam == _statusFilterAll ? null : _statusFilterParam;

  /// Applies a dashboard status bucket as a SERVER-SIDE list filter
  /// (app#36) and reloads from page 1, so the view covers ALL of the
  /// tenant's contracts in that bucket — not only what was loaded
  /// before. No-op when the same bucket is already applied.
  Future<void> applyStatusFilter(String status) async {
    if (_statusFilterParam == status) return;
    _statusFilterParam = status;
    await fetchContracts();
  }

  /// Loads the tenant's FULL (unfiltered, unpaginated) contract list for
  /// tenant-wide aggregates such as the cost summary (app#36). Never
  /// throws: on failure [costContracts] keeps its previous value (the
  /// loaded slice) as fallback.
  Future<void> fetchAllContracts() async {
    try {
      _allContracts = List.of(await _api.getContractList());
    } on ApiException {
      // Keep the previous value (null on first failure) so the dashboard
      // falls back to the loaded slice.
    }
    notifyListeners();
  }

  /// Fetches the tenant-wide dashboard counters (app#33). Never throws:
  /// on failure (e.g. a backend without the endpoint) [stats] stays null
  /// and the dashboard falls back to counting the loaded slice.
  Future<void> fetchStats() async {
    try {
      _stats = await _api.getContractStats();
    } on ApiException {
      _stats = null;
    }
    notifyListeners();
  }

  Future<Contract?> createContract(Contract contract) async {
    try {
      final created = await _api.createContract(contract);
      _contracts.insert(0, created);
      _allContracts?.insert(0, created);
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
        final allIndex = _allContracts?.indexWhere((c) => c.id == updated.id);
        if (allIndex != null && allIndex != -1 && _allContracts != null) {
          _allContracts![allIndex] = updated;
        }
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
      _allContracts?.removeWhere((c) => c.id == id);
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
