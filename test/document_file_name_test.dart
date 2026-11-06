import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/providers/document_provider.dart';

// Issue #75: the server-supplied file name must never choose the local path.
void main() {
  String safe(String name) => DocumentProvider.safeLocalFileName(name, 42);

  test('keeps ordinary file names', () {
    expect(safe('Rechnung 2026.pdf'), 'Rechnung 2026.pdf');
    expect(safe('vertrag.final.docx'), 'vertrag.final.docx');
  });

  test('drops directory traversal', () {
    expect(safe('../../x.pdf'), 'x.pdf');
    expect(safe(r'..\..\x.pdf'), 'x.pdf');
    expect(safe('a/../../b.txt'), 'b.txt');
  });

  test('drops absolute paths', () {
    expect(safe('/etc/passwd'), 'passwd');
    expect(safe(r'C:\Windows\system32\evil.dll'), 'evil.dll');
  });

  test('falls back for empty or dot-only names', () {
    for (final name in ['', '   ', '.', '..', '../', '/', r'..\', '...']) {
      expect(safe(name), 'document-42', reason: 'name "$name"');
    }
  });

  test('replaces reserved and control characters', () {
    expect(safe('a:b*c?.pdf'), 'a_b_c_.pdf');
    expect(safe('x\u0000y.pdf'), 'x_y.pdf');
  });

  test('strips leading and trailing dots and spaces', () {
    expect(safe(' .hidden.pdf. '), 'hidden.pdf');
  });

  test('caps long names but keeps the extension', () {
    final result = safe('${'a' * 300}.pdf');
    expect(result.length, 120);
    expect(result, endsWith('.pdf'));
  });
}
