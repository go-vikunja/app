import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/network.dart';

void main() {
  group('normalizeServerURL', () {
    test('adds https:// when no protocol specified', () {
      expect(normalizeServerURL('example.com'), 'https://example.com');
    });

    test('preserves http://', () {
      expect(normalizeServerURL('http://example.com'), 'http://example.com');
    });

    test('preserves https://', () {
      expect(normalizeServerURL('https://example.com'), 'https://example.com');
    });

    test('strips trailing slash', () {
      expect(normalizeServerURL('https://example.com/'), 'https://example.com');
    });

    test('strips /api/v1 suffix', () {
      expect(
        normalizeServerURL('https://example.com/api/v1'),
        'https://example.com',
      );
    });

    test('strips /api/v1 suffix with trailing slash', () {
      expect(
        normalizeServerURL('https://example.com/api/v1/'),
        'https://example.com',
      );
    });

    test('handles bare domain with /api/v1', () {
      expect(normalizeServerURL('example.com/api/v1'), 'https://example.com');
    });

    test('preserves port number', () {
      expect(
        normalizeServerURL('https://example.com:3456'),
        'https://example.com:3456',
      );
    });

    test('strips /api/v1 with port number', () {
      expect(
        normalizeServerURL('https://example.com:3456/api/v1'),
        'https://example.com:3456',
      );
    });

    test('preserves subpath', () {
      expect(
        normalizeServerURL('https://example.com/vikunja'),
        'https://example.com/vikunja',
      );
    });

    test('strips /api/v1 after subpath', () {
      expect(
        normalizeServerURL('https://example.com/vikunja/api/v1'),
        'https://example.com/vikunja',
      );
    });

    test('returns empty string for empty input', () {
      expect(normalizeServerURL(''), '');
    });

    test('trims whitespace', () {
      expect(normalizeServerURL('  example.com  '), 'https://example.com');
    });

    test('handles IP address', () {
      expect(
        normalizeServerURL('192.168.1.1:8080'),
        'https://192.168.1.1:8080',
      );
    });

    test('does not strip /api/v1 if it is part of a longer path', () {
      expect(
        normalizeServerURL('https://example.com/api/v1beta'),
        'https://example.com/api/v1beta',
      );
    });
  });
}
