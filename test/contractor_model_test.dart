import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contractor.dart';

void main() {
  group('Contractor.fromJson', () {
    // Exact shape returned by the live API (backend #41 replaced the old
    // free-text ContactInfo with structured Email/Phone):
    // GET /api/contractors and GET /api/contractors/{id}
    final sampleJson = {
      'id': 1,
      'name': 'Muster GmbH',
      'type': 'Company',
      'email': 'contact@muster.de',
      'phone': '+49 30 123456',
      'tenantId': 1,
      'userId': null,
      'isActive': true,
      'createdAt': '2026-09-20T16:35:02.5602408Z',
      'modifiedAt': '2026-09-20T16:35:02.5602408Z',
      'createdBy': 'admin@qontract.com',
      'modifiedBy': 'admin@qontract.com',
    };

    test('parses a company contractor', () {
      final c = Contractor.fromJson(sampleJson);
      expect(c.id, 1);
      expect(c.name, 'Muster GmbH');
      expect(c.type, ContractorType.company);
      expect(c.email, 'contact@muster.de');
      expect(c.phone, '+49 30 123456');
      expect(c.isActive, isTrue);
      expect(c.typeLabel, 'Company');
    });

    test('parses a personal contractor with no tenant', () {
      final contractor = Contractor.fromJson({...sampleJson, 'tenantId': null});
      expect(contractor.tenantId, isNull);
      expect(contractor.copyWith(name: 'Renamed').tenantId, isNull);
    });

    test('parses an individual contractor', () {
      final json = {...sampleJson, 'type': 'Individual', 'name': 'Max Mustermann'};
      final c = Contractor.fromJson(json);
      expect(c.type, ContractorType.individual);
      expect(c.typeLabel, 'Individual');
    });

    test('defaults type to Individual when missing', () {
      final json = {...sampleJson}..remove('type');
      final c = Contractor.fromJson(json);
      expect(c.type, ContractorType.individual);
    });

    test('defaults isActive to true when missing', () {
      final json = {...sampleJson}..remove('isActive');
      final c = Contractor.fromJson(json);
      expect(c.isActive, isTrue);
    });

    test('handles null email and phone', () {
      final json = {...sampleJson, 'email': null, 'phone': null};
      final c = Contractor.fromJson(json);
      expect(c.email, isNull);
      expect(c.phone, isNull);
      expect(c.hasContact, isFalse);
      expect(c.contactLine, isEmpty);
    });

    test('blanks whitespace-only email to null', () {
      final c = Contractor.fromJson({...sampleJson, 'email': '   ', 'phone': ''});
      expect(c.email, isNull);
      expect(c.phone, isNull);
    });

    test('contactLine joins email and phone', () {
      final c = Contractor.fromJson(sampleJson);
      expect(c.contactLine, 'contact@muster.de · +49 30 123456');
      final onlyEmail = Contractor.fromJson({...sampleJson, 'phone': null});
      expect(onlyEmail.contactLine, 'contact@muster.de');
    });
  });

  group('ContractorType.fromString', () {
    test('parses case-insensitive strings', () {
      expect(ContractorType.fromString('Company'), ContractorType.company);
      expect(ContractorType.fromString('company'), ContractorType.company);
      expect(ContractorType.fromString('COMPANY'), ContractorType.company);
      expect(ContractorType.fromString('Individual'), ContractorType.individual);
      expect(ContractorType.fromString('individual'), ContractorType.individual);
    });

    test('defaults to individual for unknown values', () {
      expect(ContractorType.fromString('Unknown'), ContractorType.individual);
      expect(ContractorType.fromString(''), ContractorType.individual);
    });
  });

  group('Contractor payloads', () {
    test('toCreateJson sends only the editable fields (PascalCase type)', () {
      final source = Contractor(
        id: 1,
        name: 'Muster GmbH',
        type: ContractorType.company,
        email: 'contact@muster.de',
        phone: '+49 30 123456',
        tenantId: 7,
        userId: 3,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final json = source.toCreateJson();
      expect(json['name'], 'Muster GmbH');
      expect(json['type'], 'Company');
      expect(json['email'], 'contact@muster.de');
      expect(json['phone'], '+49 30 123456');
      // Server-owned fields must never be sent from the client.
      expect(json, isNot(contains('tenantId')));
      expect(json, isNot(contains('userId')));
      expect(json, isNot(contains('isActive')));
    });

    test('toUpdateJson sends only the editable fields', () {
      final source = Contractor(
        id: 1,
        name: 'Muster GmbH',
        type: ContractorType.company,
        email: 'contact@muster.de',
        phone: '+49 30 123456',
        tenantId: 7,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final json = source.toUpdateJson();
      expect(json['name'], 'Muster GmbH');
      expect(json['type'], 'Company');
      expect(json['email'], 'contact@muster.de');
      expect(json['phone'], '+49 30 123456');
      expect(json, isNot(contains('isActive')));
    });

    test('payloads round-trip through fromJson', () {
      for (final type in ContractorType.values) {
        final source = Contractor(
          id: 9,
          name: 'ACME',
          type: type,
          email: 'acme@example.com',
          phone: '+1 555 0100',
          tenantId: 7,
          isActive: true,
          createdAt: DateTime.utc(2026, 1, 1),
          modifiedAt: DateTime.utc(2026, 1, 1),
        );
        final payload = source.toCreateJson();
        final parsed = Contractor.fromJson({
          'id': 9,
          'tenantId': 7,
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'modifiedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          ...payload,
        });
        expect(parsed.type, type);
        expect(parsed.name, 'ACME');
        expect(parsed.email, 'acme@example.com');
        expect(parsed.phone, '+1 555 0100');
        expect(parsed.toCreateJson()['type'], type.apiValue);
      }
    });

    test('null email/phone serialize to null', () {
      final json = Contractor(
        id: 1,
        name: 'Solo',
        type: ContractorType.individual,
        email: null,
        phone: null,
        tenantId: 1,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      ).toCreateJson();
      expect(json['email'], isNull);
      expect(json['phone'], isNull);
      expect(json['type'], 'Individual');
    });
  });
}
