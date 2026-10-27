import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/negotiation/transport_failure.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final Uri _root = Uri.parse('https://vikunja.example:8443');
const _origin = 'https://vikunja.example:8443';

DioException _thrown(
  Object? error, {
  DioExceptionType type = DioExceptionType.connectionError,
  String? message,
  Uri? uri,
}) => DioException(
  requestOptions: RequestOptions(path: '${uri ?? _root}/api/v1/info'),
  type: type,
  error: error,
  message: message,
);

final class _NativeClientException(final String message) implements Exception {
  @override
  String toString() => message;
}

Matcher _tls({required bool certificateRejected, required bool client}) =>
    isA<TlsFailure>()
        .having(
          (f) => f.certificateRejected,
          'certificateRejected',
          certificateRejected,
        )
        .having(
          (f) => f.clientCertificateRefused,
          'clientCertificateRefused',
          client,
        );

void main() {
  group("the app transport's own exceptions", () {
    for (final (error, problem) in [
      (
        const CleartextBlockedException('http://vikunja.example:80'),
        ConnectionSettingsProblem.cleartextBlocked,
      ),
      (
        const ConnectionProfileLockedException(_origin),
        ConnectionSettingsProblem.locked,
      ),
      (
        const ConnectionProfileIncompleteException(_origin),
        ConnectionSettingsProblem.incomplete,
      ),
      (
        const ConnectionProfilesDamagedException(),
        ConnectionSettingsProblem.damaged,
      ),
    ]) {
      test('${error.runtimeType} stops at the connection settings', () {
        for (final type in [
          DioExceptionType.connectionError,
          DioExceptionType.unknown,
        ]) {
          final failure = transportFailure(_root, _thrown(error, type: type));

          expect(
            failure,
            isA<ConnectionSettingsFailure>()
                .having((f) => f.problem, 'problem', problem)
                .having((f) => f.uri, 'uri', _root),
          );
          expect(isConnectionLevel(failure), isFalse);
        }
      });
    }

    test('a confirmed client certificate refusal is a TLS failure about the '
        'client certificate', () {
      const error = ClientCertificateRefusedException(_origin);
      final failure = transportFailure(_root, _thrown(error));

      expect(failure, _tls(certificateRejected: false, client: true));
      expect((failure as TlsFailure).cause, same(error));
      expect(isConnectionLevel(failure), isFalse);
    });

    test('are told apart by type, never by text', () {
      expect(
        transportFailure(
          _root,
          _thrown(
            const CleartextBlockedException('http://vikunja.example:80'),
            message: 'TLSV13_ALERT_CERTIFICATE_REQUIRED connection timed out',
          ),
        ),
        isA<ConnectionSettingsFailure>(),
      );
      expect(
        transportFailure(
          _root,
          _thrown(
            _NativeClientException(
              'CleartextBlockedException(https://vikunja.example:8443)',
            ),
          ),
        ),
        isA<ServerUnreachable>(),
      );
    });

    test('map to their network problems', () {
      expect(
        [
          const CleartextBlockedException('http://vikunja.example:80'),
          const ConnectionProfileLockedException(_origin),
          const ConnectionProfileIncompleteException(_origin),
          const ConnectionProfilesDamagedException(),
          const ClientCertificateRefusedException(_origin),
        ].map((error) => networkProblemOf(_thrown(error))),
        [
          NetworkProblem.cleartextBlocked,
          NetworkProblem.profileLocked,
          NetworkProblem.profileIncomplete,
          NetworkProblem.profileDamaged,
          NetworkProblem.clientCertificate,
        ],
      );
    });

    test('map to the same problems outside a DioException', () {
      expect(
        connectionSettingsProblemOf(
          const ConnectionProfileLockedException(_origin),
        ),
        NetworkProblem.profileLocked,
      );
      expect(
        connectionSettingsProblemOf(
          const ClientCertificateRefusedException(_origin),
        ),
        NetworkProblem.clientCertificate,
      );
      expect(
        connectionSettingsProblemOf(const SocketException('refused')),
        isNull,
      );
    });

    test('beat every other failure of a candidate', () {
      final settings = ConnectionSettingsFailure(
        _root,
        problem: ConnectionSettingsProblem.incomplete,
      );

      expect(
        mostInformative([
          BehindLoginProxy(_root),
          settings,
          NotAVikunjaServer(_root, statusCode: 403),
          TlsFailure(_root, certificateRejected: true),
        ]),
        same(settings),
      );
    });
  });

  group('a client certificate', () {
    // dart:io recorded against the Docker mTLS server (Caddy, TLS 1.3): the
    // alert arrives on the first read after the handshake. The TLS 1.2
    // alerts and the native adapters' texts are synthetic: BoringSSL's names
    // and Chromium's and Foundation's codes.
    for (final (source, error, type) in <(String, Object, DioExceptionType)>[
      (
        'dart:io, no certificate (recorded)',
        HttpException(
          '\n\tTLSV1_ALERT_CERTIFICATE_REQUIRED(tls_record.cc:489) '
          'error 268436572',
          uri: Uri.parse('$_origin/api/v1/info'),
        ),
        DioExceptionType.unknown,
      ),
      (
        'dart:io, a certificate from another CA (recorded)',
        HttpException(
          '\n\tTLSV1_ALERT_UNKNOWN_CA(tls_record.cc:489) error 268436504',
          uri: Uri.parse('$_origin/api/v1/info'),
        ),
        DioExceptionType.unknown,
      ),
      (
        'dart:io, bad_certificate alert',
        const HandshakeException(
          'Handshake error in client (OS Error: \n'
          '\tSSLV3_ALERT_BAD_CERTIFICATE(tls_record.cc:592))',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, unknown_ca alert',
        const TlsException(
          'OS Error: \n\tTLSV1_ALERT_UNKNOWN_CA(tls_record.cc:592)',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, certificate_unknown alert',
        const HandshakeException('OS Error: SSLV3_ALERT_CERTIFICATE_UNKNOWN'),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, unsupported_certificate alert',
        const HandshakeException(
          'OS Error: SSLV3_ALERT_UNSUPPORTED_CERTIFICATE',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, certificate_expired alert',
        const HandshakeException('OS Error: SSLV3_ALERT_CERTIFICATE_EXPIRED'),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, certificate_revoked alert',
        const HandshakeException('OS Error: SSLV3_ALERT_CERTIFICATE_REVOKED'),
        DioExceptionType.connectionError,
      ),
      (
        'dart:io, access_denied alert',
        const HandshakeException('OS Error: TLSV1_ALERT_ACCESS_DENIED'),
        DioExceptionType.connectionError,
      ),
      (
        'cronet_http, -110',
        _NativeClientException(
          'NetworkClientException: Exception in CronetUrlRequest: '
          'net::ERR_SSL_CLIENT_AUTH_CERT_NEEDED, ErrorCode=11, '
          'InternalErrorCode=-110, Retryable=false, '
          'uri=https://vikunja.example:8443/api/v2/info, errorCode=11, '
          'cronetInternalErrorCode=-110, immediatelyRetryable=false',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'cronet_http, -117',
        _NativeClientException(
          'NetworkClientException: Exception in CronetUrlRequest: '
          'net::ERR_BAD_SSL_CLIENT_AUTH_CERT, ErrorCode=11, '
          'InternalErrorCode=-117, Retryable=false, '
          'uri=https://vikunja.example:8443/api/v2/info, errorCode=11, '
          'cronetInternalErrorCode=-117, immediatelyRetryable=false',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'cronet_http, only the internal code',
        _NativeClientException(
          'NetworkClientException: failed, errorCode=11, '
          'cronetInternalErrorCode=-117, immediatelyRetryable=false',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'cupertino_http, -1205',
        _NativeClientException(
          'NSErrorClientException: The server did not accept the certificate. '
          '[domain=NSURLErrorDomain, code=-1205]',
        ),
        DioExceptionType.connectionError,
      ),
      (
        'cupertino_http, -1206',
        _NativeClientException(
          'NSErrorClientException: The server requires a client certificate. '
          '[domain=NSURLErrorDomain, code=-1206]',
        ),
        DioExceptionType.connectionError,
      ),
    ]) {
      test('refused, from $source', () {
        final failure = transportFailure(_root, _thrown(error, type: type));

        expect(failure, _tls(certificateRejected: false, client: true));
        expect(isConnectionLevel(failure), isFalse);
        expect(
          networkProblemOf(_thrown(error, type: type)),
          NetworkProblem.clientCertificate,
        );
      });
    }

    test('markers are shared with the app transport', () {
      expect(
        mentionsClientCertificateRefusal(
          'TlsException: \n'
          '\tTLSV1_ALERT_CERTIFICATE_REQUIRED(tls_record.cc:489) '
          'error 268436572',
        ),
        isTrue,
      );
      expect(
        mentionsClientCertificateRefusal(
          'HandshakeException: CERTIFICATE_VERIFY_FAILED: self signed',
        ),
        isFalse,
      );
      expect(
        mentionsClientCertificateRefusal('SSLV3_ALERT_HANDSHAKE_FAILURE'),
        isFalse,
      );
    });

    test('only counts the alert names BoringSSL gives received alerts', () {
      for (final text in [
        'remote error: tls: certificate required',
        'certificate_required',
        'TLSV13_ALERT_CERTIFICATE_REQUIRED',
        'TLSV1_ALERT_UNKNOWN_CA_EXTRA',
        'SSLV3_ALERT_UNKNOWN_CA',
      ]) {
        expect(mentionsClientCertificateRefusal(text), isFalse, reason: text);
      }
    });

    test('is not what a handshake failure alert is about', () {
      final failure = transportFailure(
        _root,
        _thrown(
          const HandshakeException(
            'Handshake error in client (OS Error: \n'
            '\tSSLV3_ALERT_HANDSHAKE_FAILURE(tls_record.cc:592))',
          ),
        ),
      );

      expect(failure, _tls(certificateRejected: false, client: false));
      expect(isConnectionLevel(failure), isTrue);
    });

    test('marker in a host name is ignored', () {
      final root = Uri.parse('https://alert_certificate_required.example');

      expect(
        transportFailure(
          root,
          _thrown(
            const SocketException(
              "Failed host lookup: 'alert_certificate_required.example'",
            ),
            uri: root,
          ),
        ),
        isA<ServerUnreachable>(),
      );
    });
  });

  group("the server's certificate", () {
    for (final code in [-1201, -1202, -1203, -1204]) {
      test('NSURLErrorDomain $code is a rejected server certificate', () {
        final failure = transportFailure(
          _root,
          _thrown(
            _NativeClientException(
              'NSErrorClientException: x [domain=NSURLErrorDomain, '
              'code=$code]',
            ),
          ),
        );

        expect(failure, _tls(certificateRejected: true, client: false));
      });
    }

    test('rejected by dart:io, such as a pin mismatch, is not about the '
        'client certificate', () {
      final failure = transportFailure(
        _root,
        _thrown(
          const HandshakeException(
            'Handshake error in client (OS Error: \n'
            '\tCERTIFICATE_VERIFY_FAILED: self signed certificate '
            '(handshake.cc:393))',
          ),
        ),
      );

      expect(failure, _tls(certificateRejected: true, client: false));
      expect(isConnectionLevel(failure), isFalse);
    });
  });

  test('a plain http connection never fails on a client certificate', () {
    final root = Uri.parse('http://vikunja.example:8080');

    expect(
      transportFailure(
        root,
        _thrown(
          _NativeClientException('net::ERR_SSL_CLIENT_AUTH_CERT_NEEDED'),
          uri: root,
        ),
      ),
      isA<ServerUnreachable>(),
    );
  });
}
