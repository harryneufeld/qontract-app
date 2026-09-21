import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contractor.dart';

void main() {
  group('Contractor.fromJson', () {
    // Exact shape returned by the live API:
    // GET /api/contractors and GET /api/contractors/{id}
    final sampleJson = {
      'id': 1,
      'name': 'Muster GmbH',
      'type': 'Company',
      'contactInfo': 'contact@muster.de',
      'tenantId': 1,
      'userId': null,
      'isActive': true,
      'createdAt': '2026-09-20T16:35:02.5602408Z',
      'updatedAt': '2026-09-20T16:35:02.5602408Z',
      'createdBy': 'admin@qontract.com',
      'modifiedBy': 'admin@qontract.com',
    };

    test('parses a company contractor', () {
      final c = Contractor.fromJson(sampleJson);
      expect(c.id, 1);
      expect(c.name, 'Muster GmbH');
      expect(c.type, ContractorType.company);
      expect(c.contactInfo, 'contact@muster.de');
      expect(c.isActive, isTrue);
      expect(c.typeLabel, 'Company');
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

    test('handles null contactInfo', () {
      final json = {...sampleJson, 'contactInfo': null};
      final c = Contractor.fromJson(json);
      expect(c.contactInfo, isNull);
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
}
