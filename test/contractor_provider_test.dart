import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// Records calls and serves canned data instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._initial) : super(baseUrl: 'http://localhost');

  final List<Contractor> _initial;
  final List<String> calls = [];
  Contractor? lastCreated;

  @override
  Future<List<Contractor>> getContractors() async {
    calls.add('get');
    return _initial;
  }

  @override
  Future<Contractor> createContractor(Contractor c) async {
    calls.add('create');
    lastCreated = c;
    return c.copyWith(id: 100);
  }

  @override
  Future<Contractor> updateContractor(Contractor c) async {
    calls.add('update');
    return c;
  }

  @override
  Future<Contractor> deactivateContractor(int id) async {
    calls.add('deactivate:$id');
    final idx = _initial.indexWhere((c) => c.id == id);
    return idx == -1 ? _inactive(id) : _initial[idx].copyWith(isActive: false);
  }
}

Contractor _c(int id, {bool active = true, String name = 'Contractor'}) => Contractor(
      id: id,
      name: name,
      type: ContractorType.individual,
      tenantId: 1,
      isActive: active,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

Contractor _inactive(int id) => _c(id, active: false);

void main() {
  group('ContractorProvider.createContractor', () {
    test('inserts the created contractor at the front', () async {
      final api = _FakeApiService([]);
      final provider = ContractorProvider(api: api);
      await provider.fetchContractors();

      final created = await provider.createContractor(_c(0, name: 'New'));

      expect(created, isNotNull);
      expect(provider.contractors, hasLength(1));
      expect(provider.contractors.single.id, 100);
      expect(api.calls, contains('create'));
    });
  });

  group('ContractorProvider.updateContractor', () {
    test('replaces the matching contractor in the list', () async {
      final api = _FakeApiService([_c(1)]);
      final provider = ContractorProvider(api: api);
      await provider.fetchContractors();

      final edited = _c(1, name: 'Renamed');
      final ok = await provider.updateContractor(edited);

      expect(ok, isTrue);
      expect(provider.contractors.single.name, 'Renamed');
      expect(api.calls, contains('update'));
    });
  });

  group('ContractorProvider.deactivateContractor', () {
    test('marks the contractor inactive but keeps it in the list', () async {
      final api = _FakeApiService([_c(1), _c(2)]);
      final provider = ContractorProvider(api: api);
      await provider.fetchContractors();

      final ok = await provider.deactivateContractor(_c(1));

      expect(ok, isTrue);
      expect(provider.contractors, hasLength(2)); // not removed
      expect(provider.contractors.where((c) => c.id == 1).single.isActive,
          isFalse);
      expect(provider.contractors.where((c) => c.id == 2).single.isActive,
          isTrue);
      expect(api.calls, contains('deactivate:1'));
    });
  });

  group('error handling', () {
    test('create sets errorMessage and returns null on ApiException', () async {
      final api = _ThrowingApi();
      final provider = ContractorProvider(api: api);
      final created = await provider.createContractor(_c(0));
      expect(created, isNull);
      expect(provider.errorMessage, isNotNull);
    });
  });
}

class _ThrowingApi extends ApiService {
  _ThrowingApi() : super(baseUrl: 'http://localhost');

  @override
  Future<Contractor> createContractor(Contractor c) async {
    throw ApiException(message: 'boom', statusCode: 500);
  }
}
