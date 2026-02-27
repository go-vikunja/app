import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/client.dart';

void main() {
  group('Client configuration tests', () {
    late Client client;

    setUp(() {
      client = Client(base: 'https://api.example.com');
    });

    group('Constructor and configuration', () {
      test('Default constructor should create client with empty values', () {
        final client = Client(base: 'https://api.example.com');

        expect(client.token, '');
        expect(client.authenticated, false);
        expect(client.refreshCookie, isNull);
      });

      test('Constructor with parameters should set values', () {
        final client = Client(
          token: 'test-token',
          base: 'https://api.example.com',
        );

        expect(client.token, 'test-token');
        expect(client.base, 'https://api.example.com/api/v1');
        expect(client.authenticated, true);
      });

      test('Constructor with refreshCookie should store it', () {
        final client = Client(
          token: 'test-token',
          base: 'https://api.example.com',
          refreshCookie: 'my-refresh-cookie',
        );

        expect(client.refreshCookie, 'my-refresh-cookie');
      });
    });

    group('Headers generation', () {
      test('Headers should include correct content type and user agent', () {
        final headers = client.getHeaders();
        expect(headers['Content-Type'], 'application/json');
        expect(headers['User-Agent'], 'Vikunja Mobile App');
      });

      test('Headers should have empty Authorization when no token is set', () {
        final headers = client.getHeaders();
        expect(headers['Authorization'], '');
      });
    });

    group('Certificate configuration', () {
      test(
        'reloadIgnoreCerts with true should set ignoreCertificates to true',
        () {
          client.setIgnoreCerts(true);
          expect(client.ignoreCertificates, true);
        },
      );

      test(
        'reloadIgnoreCerts with false should set ignoreCertificates to false',
        () {
          client.setIgnoreCerts(false);
          expect(client.ignoreCertificates, false);
        },
      );
    });

    group('Token refresh', () {
      test(
        'tryRefreshToken should return false when no refresh cookie is set',
        () async {
          final client = Client(base: 'https://api.example.com', token: 'old');
          final result = await client.tryRefreshToken();
          expect(result, false);
        },
      );

      test(
        'tryRefreshToken should return false with empty refresh cookie',
        () async {
          final client = Client(
            base: 'https://api.example.com',
            token: 'old',
            refreshCookie: '',
          );
          final result = await client.tryRefreshToken();
          expect(result, false);
        },
      );

      test('refreshCookie setter should update the value', () {
        final client = Client(base: 'https://api.example.com');
        expect(client.refreshCookie, isNull);
        client.refreshCookie = 'new-cookie';
        expect(client.refreshCookie, 'new-cookie');
      });
    });
  });
}
