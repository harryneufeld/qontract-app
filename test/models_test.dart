import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/user.dart';

void main() {
  group('Contract.fromJson', () {
    // Exact shape returned by the live API (verified with curl):
    // GET /api/contracts/{id}
    final sampleJson = {
      'id': 2,
      'title': 'Live Smoke Contract',
      'description': 'smoke',
      'status': 'Active',
      'startDate': null,
      'endDate': '2027-03-01',
      'counterparty': 'Muster GmbH',
      'currency': 'EUR',
      'value': '1500',
      'contractorId': null,
      'createdAt': '2026-09-20T16:35:02.5602408Z',
      'updatedAt': '2026-09-20T16:35:02.5602408Z',
      'createdBy': 'admin@qontract.com',
      'modifiedBy': 'admin@qontract.com',
    };

    test('parses the real backend payload', () {
      final c = Contract.fromJson(sampleJson);
      expect(c.id, 2);
      expect(c.title, 'Live Smoke Contract');
      expect(c.status, ContractStatus.active);
      expect(c.value, '1500');
      expect(c.contractorId, isNull);
      expect(c.createdAt.isUtc, isTrue);
    });

    test('formattedValue prefixes currency when present', () {
      final c = Contract.fromJson(sampleJson);
      expect(c.formattedValue, 'EUR 1500');
    });

    test('formattedValue handles missing value/currency', () {
      final c = Contract.fromJson({...sampleJson, 'value': null, 'currency': null});
      expect(c.formattedValue, '—');
    });

    test('isExpiringSoon / isExpired use endDate', () {
      final soon = DateTime.now().add(const Duration(days: 10));
      final c = Contract.fromJson(
          {...sampleJson, 'endDate': soon.toIso8601String().substring(0, 10)});
      expect(c.isExpiringSoon, isTrue);
      expect(c.isExpired, isFalse);

      final past = DateTime.now().subtract(const Duration(days: 1));
      final c2 = Contract.fromJson(
          {...sampleJson, 'endDate': past.toIso8601String().substring(0, 10)});
      expect(c2.isExpired, isTrue);

      final c3 = Contract.fromJson({...sampleJson, 'endDate': null});
      expect(c3.isExpired, isFalse);
      expect(c3.isExpiringSoon, isFalse);
    });

    test('toJson omits server-managed fields for create/update', () {
      final c = Contract.fromJson(sampleJson);
      final json = c.toJson();
      expect(json, containsPair('title', 'Live Smoke Contract'));
      expect(json, containsPair('status', 'Active'));
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
      expect(json.containsKey('contractorId'), isTrue);
    });
  });

  group('User.fromJson', () {
    // Exact shape returned by the live API: GET /auth/me
    final sampleJson = {
      'id': 1,
      'name': 'Admin User',
      'email': 'admin@qontract.com',
      'role': 'TenantAdmin',
      'tenantId': 1,
      'createdAt': '2026-09-20T16:19:26.1327553',
    };

    test('parses the real backend payload', () {
      final u = User.fromJson(sampleJson);
      expect(u.id, 1);
      expect(u.role, 'TenantAdmin');
      expect(u.tenantId, 1);
    });

    test('round-trips through toJson', () {
      final u = User.fromJson(sampleJson);
      final u2 = User.fromJson(u.toJson());
      expect(u2.email, u.email);
      expect(u2.tenantId, u.tenantId);
    });
  });
}
