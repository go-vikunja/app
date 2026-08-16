import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
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

  group('isCertificateRequiredError', () {
    test('matches the real captured BoringSSL certificate-required alert', () {
      const message =
          'ClientException: ClientException: javax.net.ssl.SSLProtocolException: '
          'Read error: ssl=0xb400006fba28db58: Failure in SSL library, usually a '
          'protocol error\nerror:1000045c:SSL routines:OPENSSL_internal:'
          'TLSV1_ALERT_CERTIFICATE_REQUIRED (external/boringssl/src/ssl/'
          'tls_record.cc:486 0xb40000701a292cb0:0x00000003), '
          'uri=https://172.16.1.1:8443/api/v1/info#';

      expect(isCertificateRequiredError(message), isTrue);
    });

    test('does not match a generic SSL handshake failure', () {
      const message =
          'ClientException: javax.net.ssl.SSLHandshakeException: '
          'Handshake failed';

      expect(isCertificateRequiredError(message), isFalse);
    });

    test('matches a rejected client certificate alert', () {
      const message =
          'ClientException: javax.net.ssl.SSLProtocolException: '
          'SSLV3_ALERT_BAD_CERTIFICATE';

      expect(isCertificateRequiredError(message), isTrue);
    });

    test('matches a client certificate signed by an unknown CA', () {
      const message =
          'ClientException: javax.net.ssl.SSLProtocolException: '
          'TLSV1_ALERT_UNKNOWN_CA';

      expect(isCertificateRequiredError(message), isTrue);
    });

    test('does not match an untrusted-CA failure', () {
      const message =
          'ClientException: javax.net.ssl.SSLHandshakeException: '
          'java.security.cert.CertPathValidatorException: '
          'Trust anchor for certification path not found.';

      expect(isCertificateRequiredError(message), isFalse);
    });

    test('does not match an unrelated exception', () {
      const message = 'SocketException: Connection refused';

      expect(isCertificateRequiredError(message), isFalse);
    });
  });

  group('serverInfoRequiresClientCertificate', () {
    test('true for a BoringSSL certificate-required TLS exception', () {
      final info = ExceptionResponse<Object?>(
        Exception('TLSV1_ALERT_CERTIFICATE_REQUIRED'),
        StackTrace.empty,
      );
      expect(serverInfoRequiresClientCertificate(info), isTrue);
    });

    // The optional-cert edge (Envoy `optionalClientCertificate: true`) does not
    // fail the handshake; ext_authz denies the certless /api/v1/info with an
    // HTTP status, which arrives as an ErrorResponse, not an exception.
    test('true for an ext_authz 403 on the info probe', () {
      final info = ErrorResponse<Object?>(403, const {}, const {
        'error': 'Unauthorized',
      });
      expect(serverInfoRequiresClientCertificate(info), isTrue);
    });

    test('true for an ext_authz 401 on the info probe', () {
      final info = ErrorResponse<Object?>(401, const {}, const {
        'error': 'Unauthorized',
      });
      expect(serverInfoRequiresClientCertificate(info), isTrue);
    });

    test('false for an unrelated server error (503)', () {
      final info = ErrorResponse<Object?>(503, const {}, const {
        'message': 'unavailable',
      });
      expect(serverInfoRequiresClientCertificate(info), isFalse);
    });

    test('false for a generic, non-certificate TLS exception', () {
      final info = ExceptionResponse<Object?>(
        Exception('SSLHandshakeException: Handshake failed'),
        StackTrace.empty,
      );
      expect(serverInfoRequiresClientCertificate(info), isFalse);
    });

    test('false for a successful response', () {
      expect(
        serverInfoRequiresClientCertificate(VoidResponse<Object?>()),
        isFalse,
      );
    });
  });
}
