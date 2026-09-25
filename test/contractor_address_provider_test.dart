import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/address.dart';
import 'package:qontract_app/providers/contractor_address_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Records calls and serves canned data instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._initial) : super(baseUrl: 'http://localhost');

  final List<Address> _initial;
  final List<String> calls = [];
  int _nextId = 100;

  @override
  Future<List<Address>> getContractorAddresses(int contractorId) async {
    calls.add('list:$contractorId');
    return _initial.where((a) => a.contractorId == contractorId).toList();
  }

  @override
  Future<Address> createAddress(Address a) async {
    calls.add('create');
    return a.copyWith(id: _nextId++);
  }

  @override
  Future<Address> updateAddress(Address a) async {
    calls.add('update:${a.id}');
    return a;
  }

  @override
  Future<Address> deactivateAddress(int id) async {
    calls.add('deactivate:$id');
    return Address(id: id, isActive: false);
  }
}

Address _a(int id, int contractorId, {String street = 'Main St'}) => Address(
      id: id,
      street: street,
      city: 'Berlin',
      contractorId: contractorId,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('ContractorAddressProvider.loadAddresses', () {
    test('loads and orders most-recent first', () async {
      final api = _FakeApiService([_a(1, 5), _a(2, 5, street: 'New St')]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);

      expect(api.calls, contains('list:5'));
      expect(provider.contractorId, 5);
      expect(provider.addresses.map((a) => a.id).toList(), [2, 1]);
      expect(provider.primary, isNotNull);
      expect(provider.primary!.street, 'New St');
    });

    test('second load for the same contractor is a no-op', () async {
      final api = _FakeApiService([_a(1, 5)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);
      await provider.loadAddresses(5);

      expect(api.calls.where((c) => c == 'list:5'), hasLength(1));
    });

    test('force reload refetches', () async {
      final api = _FakeApiService([_a(1, 5)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);
      await provider.loadAddresses(5, force: true);

      expect(api.calls.where((c) => c == 'list:5'), hasLength(2));
    });

    test('switching contractors reloads', () async {
      final api = _FakeApiService([_a(1, 5), _a(9, 7)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);
      await provider.loadAddresses(7);

      expect(provider.contractorId, 7);
      expect(provider.addresses.single.id, 9);
    });
  });

  group('ContractorAddressProvider mutations', () {
    test('createAddress inserts at the front with the contractor id', () async {
      final api = _FakeApiService([_a(1, 5)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);

      final created =
          await provider.createAddress(const Address(street: 'New St'));
      expect(created, isNotNull);
      expect(created!.id, 100);
      expect(created.contractorId, 5); // stamped from the loaded contractor
      expect(provider.addresses.first.id, 100);
      expect(api.calls, contains('create'));
    });

    test('updateAddress replaces the matching address in place', () async {
      final api = _FakeApiService([_a(1, 5)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);

      final ok = await provider.updateAddress(
          _a(1, 5, street: 'Renamed').copyWith(street: 'Renamed'));
      expect(ok, isTrue);
      expect(provider.addresses.single.street, 'Renamed');
      expect(api.calls, contains('update:1'));
    });

    test('removeAddress soft-deletes and removes it from the list', () async {
      final api = _FakeApiService([_a(1, 5), _a(2, 5, street: 'B')]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);

      final ok = await provider.removeAddress(_a(1, 5));
      expect(ok, isTrue);
      expect(provider.addresses, hasLength(1));
      expect(provider.addresses.single.id, 2);
      expect(api.calls, contains('deactivate:1'));
    });
  });

  group('error handling', () {
    test('createAddress sets errorMessage and returns null on ApiException',
        () async {
      final api = _ThrowingCreate();
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5, force: true);
      final created = await provider.createAddress(const Address(street: 'X'));
      expect(created, isNull);
      expect(provider.errorMessage, isNotNull);
    });

    test('loadAddresses surfaces load errors and clears the list', () async {
      final api = _ThrowingList();
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);
      expect(provider.addresses, isEmpty);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('clear', () {
    test('clear resets state', () async {
      final api = _FakeApiService([_a(1, 5)]);
      final provider = ContractorAddressProvider(api: api);
      await provider.loadAddresses(5);
      provider.clear();
      expect(provider.contractorId, isNull);
      expect(provider.addresses, isEmpty);
    });
  });
}

class _ThrowingCreate extends ApiService {
  _ThrowingCreate() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Address>> getContractorAddresses(int contractorId) async => [];
  @override
  Future<Address> createAddress(Address a) async {
    throw ApiException(message: 'boom', statusCode: 500);
  }
}

class _ThrowingList extends ApiService {
  _ThrowingList() : super(baseUrl: 'http://localhost');
  @override
  Future<List<Address>> getContractorAddresses(int contractorId) async {
    throw ApiException(message: 'server down', statusCode: 500);
  }
}
