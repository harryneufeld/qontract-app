import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/address.dart';

void main() {
  group('Address.fromJson', () {
    // Exact shape returned by the live API: GET /contractors/{id}/addresses
    final sampleJson = {
      'id': 11,
      'entityType': 'Contractor',
      'street': 'Musterstraße 5',
      'city': 'Berlin',
      'zip': '10115',
      'country': 'Germany',
      'createdAt': '2026-09-20T16:35:02.5602408Z',
      'modifiedAt': '2026-09-20T16:35:02.5602408Z',
      'isActive': true,
    };

    test('parses a full address', () {
      final a = Address.fromJson(sampleJson);
      expect(a.id, 11);
      expect(a.street, 'Musterstraße 5');
      expect(a.city, 'Berlin');
      expect(a.zip, '10115');
      expect(a.country, 'Germany');
      expect(a.isActive, isTrue);
      expect(a.createdAt, isNotNull);
    });

    test('tolerates missing optional fields and nulls', () {
      final json = {
        'id': 1,
        'entityType': 'Contractor',
        'street': 'Main St',
        'city': null,
        'zip': null,
        'country': null,
        'isActive': true,
      };
      final a = Address.fromJson(json);
      expect(a.street, 'Main St');
      expect(a.city, isNull);
      expect(a.createdAt, isNull);
      expect(a.hasContent, isTrue);
    });

    test('defaults isActive to true when missing', () {
      final json = {'id': 1, 'street': 'x'};
      expect(Address.fromJson(json).isActive, isTrue);
    });
  });

  group('Address display', () {
    test('joins street, zip+city and country', () {
      final a = Address(street: 'Musterstraße 5', zip: '10115', city: 'Berlin', country: 'Germany');
      expect(a.display, 'Musterstraße 5, 10115 Berlin, Germany');
    });

    test('omits blank parts', () {
      final a = Address(street: 'Main St', city: 'Springfield');
      expect(a.display, 'Main St, Springfield');
    });

    test('country only', () {
      expect(Address(country: 'Germany').display, 'Germany');
    });

    test('blank address renders as empty string', () {
      expect(const Address().display, isEmpty);
      expect(Address(street: '   ', city: '').display, isEmpty);
    });
  });

  group('Address payloads', () {
    test('toCreateJson stamps the Contractor entity type and contractorId', () {
      final a = Address(street: 'Main St', city: 'Springfield', contractorId: 42);
      final json = a.toCreateJson();
      expect(json['entityType'], 'Contractor');
      expect(json['contractorId'], 42);
      expect(json['street'], 'Main St');
      expect(json['city'], 'Springfield');
      expect(json['zip'], isNull);
      expect(json, isNot(contains('id')));
    });

    test('blanks trim to null', () {
      final a = Address(street: 'Main St', city: '  ', zip: '', country: null);
      final json = a.toCreateJson();
      expect(json['street'], 'Main St');
      expect(json['city'], isNull);
      expect(json['zip'], isNull);
      expect(json['country'], isNull);
    });

    test('hasContent reflects any non-blank field', () {
      expect(const Address().hasContent, isFalse);
      expect(Address(zip: '10115').hasContent, isTrue);
      expect(Address(street: '   ').hasContent, isFalse);
    });

    test('toUpdateJson equals toCreateJson', () {
      final a = Address(id: 7, street: 'Main St', contractorId: 3);
      expect(a.toUpdateJson(), a.toCreateJson());
    });
  });
}
