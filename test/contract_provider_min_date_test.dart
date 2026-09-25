import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Serves a fixed contract list instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._contracts) : super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts.sublist(start, (start + pageSize).clamp(0, _contracts.length));
  }
  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

}

Contract _contract({
  required int id,
  String status = ContractStatus.active,
  String? minimumContractDate,
}) {
  return Contract(
    id: id,
    title: 'Contract $id',
    status: status,
    minimumContractDate: minimumContractDate,
    createdAt: DateTime(2026, 1, 1),
    modifiedAt: DateTime(2026, 1, 1),
  );
}

String _dateInDays(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);

void main() {
  Future<ContractProvider> _providerWith(List<Contract> contracts) async {
    final provider = ContractProvider(api: _FakeApiService(contracts));
    await provider.fetchContracts();
    return provider;
  }

  group('ContractProvider.getMinDateApproachingContracts', () {
    test('returns active contracts whose min date is within 90 days', () async {
      final provider = await _providerWith([
        _contract(id: 1, minimumContractDate: _dateInDays(30)),
        _contract(id: 2, minimumContractDate: _dateInDays(90)),
        _contract(id: 3, minimumContractDate: _dateInDays(91)), // outside
        _contract(id: 4), // no date -> ignored
      ]);

      final result = provider.getMinDateApproachingContracts();
      expect(result.map((c) => c.id), [1, 2]);
    });

    test('includes contracts whose min date already passed', () async {
      final provider = await _providerWith([
        _contract(id: 1, minimumContractDate: _dateInDays(-5)),
        _contract(id: 2, minimumContractDate: _dateInDays(100)),
      ]);

      final result = provider.getMinDateApproachingContracts();
      expect(result.map((c) => c.id), [1]);
    });

    test('ignores non-active contracts', () async {
      final provider = await _providerWith([
        _contract(id: 1, status: ContractStatus.draft, minimumContractDate: _dateInDays(10)),
        _contract(id: 2, status: ContractStatus.terminated, minimumContractDate: _dateInDays(10)),
        _contract(id: 3, status: ContractStatus.expired, minimumContractDate: _dateInDays(10)),
        _contract(id: 4, minimumContractDate: _dateInDays(10)),
      ]);

      final result = provider.getMinDateApproachingContracts();
      expect(result.map((c) => c.id), [4]);
    });

    test('sorts by earliest minimum contract date first', () async {
      final provider = await _providerWith([
        _contract(id: 1, minimumContractDate: _dateInDays(80)),
        _contract(id: 2, minimumContractDate: _dateInDays(10)),
        _contract(id: 3, minimumContractDate: _dateInDays(50)),
      ]);

      final result = provider.getMinDateApproachingContracts();
      expect(result.map((c) => c.id), [2, 3, 1]);
    });

    test('is empty when nothing is approaching', () async {
      final provider = await _providerWith([
        _contract(id: 1, minimumContractDate: _dateInDays(120)),
        _contract(id: 2),
      ]);

      expect(provider.getMinDateApproachingContracts(), isEmpty);
    });

    test('respects a custom window', () async {
      final provider = await _providerWith([
        _contract(id: 1, minimumContractDate: _dateInDays(30)),
      ]);

      expect(
          provider.getMinDateApproachingContracts(days: 60), isNotEmpty);
      expect(
          provider.getMinDateApproachingContracts(days: 5), isEmpty);
    });
  });
}
