import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Serves a fixed contract list instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._contracts) : super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;

  @override
  Future<List<Contract>> getContracts() async => _contracts;
}

Contract _contract({
  required int id,
  String status = ContractStatus.active,
  String? endDate,
}) {
  return Contract(
    id: id,
    title: 'Contract $id',
    status: status,
    endDate: endDate,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
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

  group('ContractProvider.getExpiredContracts', () {
    test('returns contracts whose end date has passed', () async {
      final provider = await _providerWith([
        _contract(id: 1, endDate: _dateInDays(-10)), // past -> expired
        _contract(id: 2, endDate: _dateInDays(10)), // future -> not expired
        _contract(id: 3), // no date -> not expired
      ]);

      expect(provider.getExpiredContracts().map((c) => c.id), [1]);
    });

    test('includes contracts marked Expired regardless of end date', () async {
      final provider = await _providerWith([
        _contract(id: 1, status: ContractStatus.expired,
            endDate: _dateInDays(10)), // future date, status expired
        _contract(id: 2, status: ContractStatus.expired), // no date
        _contract(id: 3, endDate: _dateInDays(-10)), // date passed, active
      ]);

      expect(
          provider.getExpiredContracts().map((c) => c.id), unorderedEquals([1, 2, 3]));
    });

    test('excludes contracts that are not expired', () async {
      final provider = await _providerWith([
        _contract(id: 1, endDate: _dateInDays(10)), // active, future
        _contract(id: 2, status: ContractStatus.terminated,
            endDate: _dateInDays(10)), // terminated, future
        _contract(id: 3, status: ContractStatus.draft), // no date
      ]);

      expect(provider.getExpiredContracts(), isEmpty);
    });

    test('is empty when there are no contracts', () async {
      final provider = await _providerWith([]);

      expect(provider.getExpiredContracts(), isEmpty);
    });
  });

  group('ContractProvider.expiredCount', () {
    test('matches the number of expired contracts', () async {
      final provider = await _providerWith([
        _contract(id: 1, endDate: _dateInDays(-10)),
        _contract(id: 2, status: ContractStatus.expired),
        _contract(id: 3, endDate: _dateInDays(10)),
      ]);

      expect(provider.expiredCount, 2);
    });

    test('is zero when nothing is expired', () async {
      final provider = await _providerWith([
        _contract(id: 1, endDate: _dateInDays(10)),
        _contract(id: 2),
      ]);

      expect(provider.expiredCount, 0);
    });
  });
}
