import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Scripted [ApiService] for the mutation methods (list is pre-seeded).
class _FakeApi extends ApiService {
  _FakeApi(this._initial) : super(baseUrl: 'http://localhost');

  final List<Contract> _initial;
  final List<Contract> created = [];
  final List<int> deletedIds = [];

  Object? Function()? createImpl; // null -> success
  Object? Function()? updateImpl; // null -> success
  Object? Function()? deleteImpl; // null -> success
  int? lastCreatedContractorId;
  Contract? lastUpdatedContract;

  List<Contract> get seed => _initial;

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0}) async {
    if (page == 0 || pageSize == 0) return List.of(_initial);
    final start = (page - 1) * pageSize;
    if (start >= _initial.length) return [];
    return _initial.sublist(start, (start + pageSize).clamp(0, _initial.length));
  }

  @override
  Future<Contract> createContract(Contract contract) async {
    lastCreatedContractorId = contract.contractorId;
    final impl = createImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    final stored = Contract(
      id: 100 + created.length,
      title: contract.title,
      description: contract.description,
      status: contract.status,
      startDate: contract.startDate,
      endDate: contract.endDate,
      currency: contract.currency,
      value: contract.value,
      contractorId: contract.contractorId,
      contractNumber: contract.contractNumber,
      minimumContractDate: contract.minimumContractDate,
      createdAt: DateTime.utc(2026, 6, 1),
      modifiedAt: DateTime.utc(2026, 6, 1),
    );
    created.add(stored);
    return stored;
  }

  @override
  Future<Contract> updateContract(int id, Contract contract) async {
    lastUpdatedContract = contract;
    final impl = updateImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    // Echo back what the client sent, stamped with the target id (the
    // server owns id/audit fields).
    return Contract(
      id: id,
      title: contract.title,
      description: contract.description,
      status: contract.status,
      startDate: contract.startDate,
      endDate: contract.endDate,
      currency: contract.currency,
      value: contract.value,
      contractorId: contract.contractorId,
      contractNumber: contract.contractNumber,
      minimumContractDate: contract.minimumContractDate,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 6, 1),
    );
  }

  @override
  Future<void> deleteContract(int id) async {
    final impl = deleteImpl;
    if (impl != null) {
      final r = impl();
      if (r != null) throw r;
    }
    deletedIds.add(id);
  }
}

Contract _contract(int id, String title,
        {String status = 'Active',
        String? description,
        int? contractorId,
        String? value}) =>
    Contract(
      id: id,
      title: title,
      description: description,
      status: status,
      contractorId: contractorId,
      value: value,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  final seed = [
    _contract(1, 'Lease A', description: 'warehouse', contractorId: 10),
    _contract(2, 'Service B', description: 'cleaning', contractorId: 20),
  ];

  late _FakeApi api;
  late ContractProvider provider;

  setUp(() async {
    api = _FakeApi(seed);
    provider = ContractProvider(api: api);
    await provider.fetchContracts();
  });

  group('createContract', () {
    test('inserts the server response at the top of the list', () async {
      final created = await provider.createContract(
          _contract(0, 'New deal', status: 'Draft', contractorId: 30));

      expect(created, isNotNull);
      expect(created!.id, 100);
      expect(api.lastCreatedContractorId, 30);
      expect(provider.contracts.first.id, 100);
      expect(provider.contracts, hasLength(3));
      expect(provider.errorMessage, isNull);
    });

    test('API error: returns null and surfaces the message', () async {
      api.createImpl = () =>
          ApiException(message: 'Contract title is required.', statusCode: 400);

      final created = await provider.createContract(_contract(0, 'New deal'));

      expect(created, isNull);
      expect(provider.contracts, hasLength(2));
      expect(provider.errorMessage, 'Contract title is required.');
    });
  });

  group('updateContract', () {
    test('replaces the contract in place', () async {
      final target = provider.contracts.first;
      final ok = await provider.updateContract(Contract(
        id: target.id,
        title: 'Lease A (renewed)',
        status: target.status,
        contractorId: target.contractorId,
        createdAt: target.createdAt,
        modifiedAt: target.modifiedAt,
      ));

      expect(ok, isTrue);
      expect(api.lastUpdatedContract, isNotNull);
      final updated =
          provider.contracts.firstWhere((c) => c.id == target.id);
      expect(updated.title, 'Lease A (renewed)');
      expect(provider.contracts, hasLength(2));
      expect(provider.errorMessage, isNull);
    });

    test('keeps the selected contract in sync with the update', () async {
      final target = provider.contracts.first;
      provider.setSelectedContract(target);

      await provider.updateContract(Contract(
        id: target.id,
        title: 'Lease A (v2)',
        status: target.status,
        contractorId: target.contractorId,
        createdAt: target.createdAt,
        modifiedAt: target.modifiedAt,
      ));

      expect(provider.selectedContract, isNotNull);
      expect(provider.selectedContract!.title, 'Lease A (v2)');
    });

    test('API error: keeps the old copy and surfaces the message', () async {
      api.updateImpl =
          () => ApiException(message: 'This item no longer exists.',
              statusCode: 404);
      final target = provider.contracts.first;

      final ok = await provider.updateContract(Contract(
        id: target.id,
        title: 'Ghost',
        status: target.status,
        contractorId: target.contractorId,
        createdAt: target.createdAt,
        modifiedAt: target.modifiedAt,
      ));

      expect(ok, isFalse);
      expect(provider.contracts.firstWhere((c) => c.id == target.id).title,
          'Lease A');
      expect(provider.errorMessage, 'This item no longer exists.');
    });
  });

  group('deleteContract (soft delete)', () {
    test('removes the contract from the list', () async {
      final ok = await provider.deleteContract(1);

      expect(ok, isTrue);
      expect(api.deletedIds, [1]);
      expect(provider.contracts.map((c) => c.id), [2]);
      expect(provider.errorMessage, isNull);
    });

    test('clears the selection when the selected contract is deleted',
        () async {
      final target = provider.contracts.first;
      provider.setSelectedContract(target);
      expect(provider.selectedContract, isNotNull);

      await provider.deleteContract(target.id);

      expect(provider.selectedContract, isNull);
    });

    test('API error: keeps the contract and surfaces the message', () async {
      api.deleteImpl =
          () => ApiException(message: 'Server error (500). Please try again.',
              statusCode: 500);

      final ok = await provider.deleteContract(1);

      expect(ok, isFalse);
      expect(provider.contracts, hasLength(2));
      expect(provider.errorMessage, 'Server error (500). Please try again.');
    });
  });

  group('searchContracts (in-memory search)', () {
    test('matches on title (case-insensitive)', () {
      expect(provider.searchContracts('lease').map((c) => c.id), [1]);
      expect(provider.searchContracts('SERVICE').map((c) => c.id), [2]);
    });

    test('matches on description', () {
      expect(provider.searchContracts('warehouse').map((c) => c.id), [1]);
      expect(provider.searchContracts('cleaning').map((c) => c.id), [2]);
    });

    test('matches on the contractor (counterparty) name', () {
      final names = {10: 'Acme Rentals', 20: 'Bright Clean'};
      expect(provider.searchContracts('acme',
              contractorNames: names).map((c) => c.id),
          [1]);
      expect(provider.searchContracts('bright',
              contractorNames: names).map((c) => c.id),
          [2]);
      // Without the name map the same query matches nothing.
      expect(provider.searchContracts('acme'), isEmpty);
    });

    test('no match returns an empty list', () {
      expect(provider.searchContracts('zzz-nope'), isEmpty);
    });
  });
}
