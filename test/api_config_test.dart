import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/config/api_config.dart';
import 'package:qontract_app/services/api_service.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('returns default when nothing is configured', () {
      // Explicit empty string forces falling through to env/default.
      expect(
        resolveApiBaseUrl(explicit: '   '),
        _expectedDefault(),
      );
    });

    test('explicit value wins and gets /api appended', () {
      expect(
        resolveApiBaseUrl(explicit: 'https://api.example.com'),
        'https://api.example.com/api',
      );
    });

    test('explicit value keeps existing /api suffix', () {
      expect(
        resolveApiBaseUrl(explicit: 'https://api.example.com/api'),
        'https://api.example.com/api',
      );
    });

    test('trailing slashes are stripped before suffixing', () {
      expect(
        resolveApiBaseUrl(explicit: 'https://api.example.com/api/'),
        'https://api.example.com/api',
      );
      expect(
        resolveApiBaseUrl(explicit: 'http://10.0.2.2:65533///'),
        'http://10.0.2.2:65533/api',
      );
    });

    test('whitespace is trimmed', () {
      expect(
        resolveApiBaseUrl(explicit: '  https://api.example.com  '),
        'https://api.example.com/api',
      );
    });
  });

  group('ApiService baseUrl', () {
    test('defaults to the dev backend', () {
      expect(ApiService().baseUrl, _expectedDefault());
    });

    test('accepts an explicit base url', () {
      expect(
        ApiService(baseUrl: 'https://api.example.com').baseUrl,
        'https://api.example.com/api',
      );
    });
  });
}

String _expectedDefault() => kDefaultApiBaseUrl;
