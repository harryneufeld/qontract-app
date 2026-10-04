import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';

void main() {
  final json = {
    'id': 1,
    'title': 'Private contract',
    'status': 'Active',
    'createdAt': '2026-01-01T00:00:00Z',
    'modifiedAt': '2026-01-01T00:00:00Z',
  };

  test('ownership response identifies personal contracts', () {
    final personal =
        Contract.fromJson({...json, 'tenantId': null, 'ownerUserId': 5});
    expect(personal.isPersonal, true);
    expect(personal.ownerUserId, 5);
    final shared =
        Contract.fromJson({...json, 'tenantId': 2, 'ownerUserId': null});
    expect(shared.isPersonal, false);
  });

  test('missing historical ownership does not imply private ownership', () {
    expect(Contract.fromJson(json).isPersonal, false);
  });
}
