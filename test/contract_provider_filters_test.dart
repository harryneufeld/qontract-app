import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/services/api_service.dart';

/// The model's date predicates use DateTime.now(), so test fixtures build
/// their dates relative to the real "today" to stay stable.
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _FakeApiService extends ApiService {
  _FakeApiService(this._initial) : super(baseUrl: 'http://localhost');

  final List<Contract> _initial;

  @override
  Future<List<Contract>> getContracts({int page = 0, int pageSize = 0}) async {
    if (page == 0 || pageSize == 0) return _initial;
    final start = (page - 1) * pageSize;
    if (start >= _initial.length) return [];
    return _initial.sublist(start, (start + pageSize).clamp(0, _initial.length));
  }
  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

}

Contract _contract(
  int id,
  String title, {
  String status = 'Active',
  String? endDate,
  String? minimumContractDate,
  int? contractorId,
}) {
  return Contract(
    id: id,
    title: title,
    status: status,
    endDate: endDate,
    minimumContractDate: minimumContractDate,
    contractorId: contractorId,
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final now = DateTime.now();
  String plus(int days) => _iso(now.add(Duration(days: days)));

  // id: (status, end, minDate, contractor)
  final contracts = [
    _contract(1, 'A', endDate: plus(16), contractorId: 10),
    _contract(2, 'B', endDate: plus(47), contractorId: 10),
    _contract(3, 'C', endDate: plus(-15), contractorId: 20),
    _contract(4, 'D', status: 'Expired', endDate: plus(-100), contractorId: 20),
    _contract(5, 'E', status: 'Draft', endDate: plus(16), contractorId: 20),
    _contract(6, 'F', contractorId: 30),
    _contract(7, 'G', endDate: plus(200), minimumContractDate: plus(30), contractorId: 30),
  ];

  late ContractProvider provider;

  setUp(() async {
    provider = ContractProvider(api: _FakeApiService(contracts));
    await provider.fetchContracts();
  });

  group('filterByStatus (issue #20)', () {
    test('default returns everything', () {
      expect(provider.filterByStatus('all'), hasLength(7));
    });

    test('active by status field', () {
      expect(provider.filterByStatus('active').map((c) => c.id).toSet(),
          {1, 2, 3, 6, 7});
    });

    test('expiring = ending within 30 days and not expired', () {
      expect(provider.filterByStatus('expiring').map((c) => c.id).toSet(),
          {1, 5});
    });

    test('expired = date in the past or status Expired', () {
      expect(provider.filterByStatus('expired').map((c) => c.id).toSet(),
          {3, 4});
    });

    test('minDate = active contracts reaching minimum date within 90 days', () {
      expect(provider.filterByStatus('minDate').map((c) => c.id).toSet(), {7});
    });
  });

  group('filterByContractor (issue #20)', () {
    test('matches by contractorId', () {
      expect(provider.filterByContractor(10).map((c) => c.id).toSet(), {1, 2});
      expect(provider.filterByContractor(20).map((c) => c.id).toSet(),
          {3, 4, 5});
      expect(provider.filterByContractor(99), isEmpty);
    });
  });

  group('filterByEndingWithinDays (issue #20)', () {
    test('30 days: only active contracts ending in the window', () {
      expect(provider.filterByEndingWithinDays(30).map((c) => c.id).toSet(), {1});
    });

    test('90 days adds the 47-day contract', () {
      expect(provider.filterByEndingWithinDays(90).map((c) => c.id).toSet(),
          {1, 2});
    });

    test('365 days adds the 200-day contract', () {
      expect(provider.filterByEndingWithinDays(365).map((c) => c.id).toSet(),
          {1, 2, 7});
    });
  });
}
