import 'package:test/test.dart';
import 'package:vikunja_app/core/network/client.dart';

void main() {
  group('Client configuration tests', () {
    late Client client;

    setUp(() {
      client = Client(null);
    });

    group('Constructor and configuration', () {
      test('Default constructor should create client with empty values', () {
        expect(client.token, '');
        expect(client.base, '');
        expect(client.authenticated, false);
      });

      test('Constructor with parameters should set values', () {
        final client = Client(
          null,
          token: 'test-token',
          base: 'https://api.example.com',
          authenticated: true,
        );

        expect(client.token, 'test-token');
        expect(client.base, 'https://api.example.com/api/v1');
        expect(client.authenticated, true);
      });
    });

    group('Base URL configuration', () {
      test('Configure with base URL should add /api/v1 suffix', () {
        client.configure(base: 'https://api.example.com');
        expect(client.base, 'https://api.example.com/api/v1');
      });

      test('Configure with base URL ending in /api/v1 should not duplicate',
          () {
        client.configure(base: 'https://api.example.com/api/v1');
        expect(client.base, 'https://api.example.com/api/v1');
      });

      test('Configure should remove trailing slash from base URL', () {
        client.configure(base: 'https://api.example.com/');
        expect(client.base, 'https://api.example.com/api/v1');
      });

      test('Configure should remove spaces from base URL', () {
        client.configure(base: ' https://api.example.com ');
        expect(client.base, 'https://api.example.com/api/v1');
      });

      test('Configure with base ending in /api/v1/ should handle correctly',
          () {
        client.configure(base: 'https://api.example.com/api/v1/');
        expect(client.base, 'https://api.example.com/api/v1');
      });
    });

    group('Token configuration', () {
      test('Configure with token should set token', () {
        client.configure(token: 'new-token');
        expect(client.token, 'new-token');
      });

      test('Configure with null token should not change existing token', () {
        client.configure(token: 'initial-token');
        client.configure(token: null);
        expect(client.token, 'initial-token');
      });
    });

    group('Authentication configuration', () {
      test('Configure with authenticated should set authentication status', () {
        client.configure(authenticated: true);
        expect(client.authenticated, true);
      });

      test(
          'Configure with null authenticated should not change existing status',
          () {
        client.configure(authenticated: true);
        client.configure(authenticated: null);
        expect(client.authenticated, true);
      });

      test('Reset should set authenticated to false', () {
        client.configure(authenticated: true);
        client.reset();
        expect(client.authenticated, false);
      });
    });

    group('Headers generation', () {
      test('Headers should include correct content type and user agent', () {
        final headers = client.headers;
        expect(headers['Content-Type'], 'application/json');
        expect(headers['User-Agent'], 'Vikunja Mobile App');
      });

      test('Headers should include Bearer token when token is set', () {
        client.configure(token: 'test-token');
        final headers = client.headers;
        expect(headers['Authorization'], 'Bearer test-token');
      });

      test('Headers should have empty Authorization when no token is set', () {
        final headers = client.headers;
        expect(headers['Authorization'], '');
      });
    });

    group('Certificate configuration', () {
      test('reloadIgnoreCerts with true should set ignoreCertificates to true',
          () {
        client.reloadIgnoreCerts(true);
        expect(client.ignoreCertificates, true);
      });

      test(
          'reloadIgnoreCerts with false should set ignoreCertificates to false',
          () {
        client.reloadIgnoreCerts(false);
        expect(client.ignoreCertificates, false);
      });

      test('reloadIgnoreCerts with null should set ignoreCertificates to false',
          () {
        client.reloadIgnoreCerts(null);
        expect(client.ignoreCertificates, false);
      });
    });
  });
}
