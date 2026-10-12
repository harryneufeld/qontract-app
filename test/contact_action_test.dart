import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/widgets/contact_action.dart';

void main() {
  test('email subject preserves spaces and special contract number characters',
      () {
    final uri = contactUri(' hello@example.com ',
        email: true, subject: 'CNT / A+B & 42');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'hello@example.com');
    expect(uri.queryParameters['subject'], 'CNT / A+B & 42');
    expect(uri.toString(), contains('CNT%20%2F%20A%2BB%20%26%2042'));
    expect(contactUri('hello@example.com', email: true).hasQuery, false);
  });
  test('phone action uses a telephone URI', () {
    final uri = contactUri(' +49 123 456 ', email: false);
    expect(uri.scheme, 'tel');
    expect(uri.path, '+49123456');
    expect(uri.hasQuery, false);
  });
}
