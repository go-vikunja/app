import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/core/network/sentry_network_filter.dart';

void main() {
  group('isIgnoredNetworkError', () {
    test('null throwable is not ignored', () {
      expect(isIgnoredNetworkError(null), isFalse);
    });

    group('ok_http ClientExceptions wrapping OkHttp/Java IOExceptions', () {
      // These are the real shapes package:ok_http produces: a ClientException
      // whose message is the underlying Java exception's toString().
      final ignored = {
        'DNS failure':
            'java.net.UnknownHostException: Unable to resolve host '
            '"vikunja.example.com": No address associated with hostname',
        'connection refused':
            'java.net.ConnectException: Failed to connect to /10.0.0.1:8443',
        'network unreachable':
            'java.net.ConnectException: failed to connect to /10.0.0.1 '
            '(port 8443): connect failed: ENETUNREACH (Network is unreachable)',
        'no route to host': 'java.net.NoRouteToHostException: No route to host',
        'socket timeout': 'java.net.SocketTimeoutException: timeout',
        'call timeout': 'java.io.InterruptedIOException: timeout',
        'connection reset': 'java.net.SocketException: Connection reset',
      };
      for (final entry in ignored.entries) {
        test('ignores ${entry.key}', () {
          final e = http.ClientException(
            entry.value,
            Uri.parse('https://vikunja.example.com/api/v1/info'),
          );
          expect(isIgnoredNetworkError(e), isTrue);
        });
      }
    });

    test('ignores dart:io SocketException (IOClient fallback / offline)', () {
      expect(
        isIgnoredNetworkError(const SocketException('Connection failed')),
        isTrue,
      );
    });

    test('ignores TimeoutException (client-side .timeout guard)', () {
      expect(
        isIgnoredNetworkError(TimeoutException('request timed out')),
        isTrue,
      );
    });

    group('does NOT ignore actionable errors', () {
      test('TLS/certificate errors still reach Sentry', () {
        // The mTLS feature depends on these surfacing; the original Cronet
        // filter left cert/TLS errors alone too.
        final e = http.ClientException(
          'javax.net.ssl.SSLHandshakeException: '
          'java.security.cert.CertPathValidatorException: Trust anchor for '
          'certification path not found.',
          Uri.parse('https://vikunja.example.com'),
        );
        expect(isIgnoredNetworkError(e), isFalse);
      });

      test('a generic ClientException is not ignored', () {
        final e = http.ClientException(
          'Invalid response',
          Uri.parse('https://vikunja.example.com'),
        );
        expect(isIgnoredNetworkError(e), isFalse);
      });

      test('a FormatException is not ignored', () {
        expect(
          isIgnoredNetworkError(const FormatException('bad json')),
          isFalse,
        );
      });

      test('an arbitrary error is not ignored', () {
        expect(isIgnoredNetworkError(StateError('boom')), isFalse);
      });

      test('message fragments do not hide non-network errors', () {
        expect(
          isIgnoredNetworkError(StateError('Connection closed unexpectedly')),
          isFalse,
        );
      });
    });
  });
}
