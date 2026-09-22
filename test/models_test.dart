import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/document.dart';
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
      expect(c.contractNumber, isNull); // older payloads have no number
      expect(c.createdAt.isUtc, isTrue);
    });

    test('parses contractNumber when present and round-trips it', () {
      final c = Contract.fromJson({...sampleJson, 'contractNumber': 'CNT-2026-0042'});
      expect(c.contractNumber, 'CNT-2026-0042');
      expect(c.toJson(), containsPair('contractNumber', 'CNT-2026-0042'));

      // Emptying the field in the form must send null (clears the number).
      final c2 = Contract.fromJson({...sampleJson, 'contractNumber': null});
      expect(c2.contractNumber, isNull);
      expect(c2.toJson(), containsPair('contractNumber', null));
    });

    test('ignores the removed free-text counterparty field if still present',
        () {
      final c = Contract.fromJson({...sampleJson, 'counterparty': 'Muster GmbH'});
      expect(c.title, 'Live Smoke Contract');
      expect(c.toJson().containsKey('counterparty'), isFalse);
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

  group('Document.fromJson', () {
    // Exact shape returned by the live API: GET /api/documents/{id}
    // (no FilePath — the server keeps storage paths internal).
    final sampleJson = {
      'id': 3,
      'fileName': 'lease.pdf',
      'fileType': 'application/pdf',
      'fileSize': 2048,
      'contractId': 2,
      'uploadedAt': '2026-09-21T10:00:00.0000000Z',
      'createdAt': '2026-09-21T10:00:00.0000000Z',
      'updatedAt': '2026-09-21T10:00:00.0000000Z',
      'version': 1,
      'createdBy': 'admin@qontract.com',
      'modifiedBy': 'admin@qontract.com',
    };

    test('parses the real backend payload', () {
      final d = Document.fromJson(sampleJson);
      expect(d.id, 3);
      expect(d.fileName, 'lease.pdf');
      expect(d.fileType, 'application/pdf');
      expect(d.fileSize, 2048);
      expect(d.contractId, 2);
      expect(d.version, 1);
      expect(d.isPdf, isTrue);
      expect(d.isImage, isFalse);
      expect(d.extension, 'pdf');
    });

    test('formats file sizes', () {
      final d = Document.fromJson(sampleJson);
      expect(d.fileSizeFormatted, '2.0 KB');
      final big = Document.fromJson({...sampleJson, 'fileSize': 5 * 1024 * 1024});
      expect(big.fileSizeFormatted, '5.0 MB');
    });

    test('detects images and falls back on missing extension', () {
      final img = Document.fromJson({...sampleJson, 'fileName': 'photo.png', 'fileType': 'image/png'});
      expect(img.isImage, isTrue);
      expect(img.isPdf, isFalse);
      expect(img.extension, 'png');
      final noExt = Document.fromJson({...sampleJson, 'fileName': 'archive'});
      expect(noExt.extension, '');
    });
  });
}
