import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/services/api_service.dart';

class _DelayedApi extends ApiService {
  final requests = <(String?, int, Completer<List<Contract>>)>[];
  _DelayedApi() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Contract>> getContracts(
      {int page = 0, int pageSize = 0, String? status}) {
    final pending = Completer<List<Contract>>();
    requests.add((status, page, pending));
    return pending.future;
  }

  @override
  Future<List<Contract>> getContractList() async => [];
  @override
  Future<ContractStats> getContractStats() async => const ContractStats(
      total: 0, active: 0, expired: 0, expiring: 0, minDateApproaching: 0);
}

Contract _contract(int id, String status) => Contract(
    id: id,
    title: 'Contract $id',
    status: status,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026));

void main() {
  test('a late status response cannot replace the latest selection', () async {
    final api = _DelayedApi();
    final provider = ContractProvider(api: api);
    final active = provider.applyStatusFilter('active');
    final expired = provider.applyStatusFilter('expired');
    api.requests[1].$3.complete([_contract(2, 'Expired')]);
    await expired;
    api.requests[0].$3.complete([_contract(1, 'Active')]);
    await active;
    expect(provider.statusFilter, 'expired');
    expect(provider.contracts.single.id, 2);
    expect(provider.isLoading, false);
  });

  test('an old next page cannot append to a newly filtered list', () async {
    final api = _DelayedApi();
    final provider = ContractProvider(api: api);
    final initial = provider.fetchContracts();
    api.requests[0].$3
        .complete(List.generate(20, (i) => _contract(i, 'Active')));
    await initial;
    final nextPage = provider.loadMore();
    final expired = provider.applyStatusFilter('expired');
    api.requests[2].$3.complete([_contract(99, 'Expired')]);
    await expired;
    api.requests[1].$3.complete([_contract(21, 'Active')]);
    await nextPage;
    expect(provider.contracts.map((c) => c.id), [99]);
    expect(provider.isLoadingMore, false);
  });

  test('a late refresh cannot replace a status selected during refresh',
      () async {
    final api = _DelayedApi();
    final provider = ContractProvider(api: api);
    final refresh = provider.refreshContracts();
    final active = provider.applyStatusFilter('active');
    api.requests[1].$3.complete([_contract(2, 'Active')]);
    await active;
    api.requests[0].$3.complete([_contract(1, 'Draft')]);
    await refresh;
    expect(provider.contracts.single.id, 2);
    expect(provider.isRefreshing, false);
  });
}
