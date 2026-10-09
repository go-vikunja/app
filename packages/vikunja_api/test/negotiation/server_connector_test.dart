import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

/// Routes of a server at [root] that answers like Vikunja on 2.4 and newer.
Map<String, FakeRoute> _vikunja27(String root) => {
  '$root/api/v2/info': fixture('info_v2_2.7.0.json'),
  '$root/api/v1/info': fixture('info_v1_2.7.0.json'),
};

/// Routes of a server at [root] that answers like Vikunja before 2.4.
Map<String, FakeRoute> _vikunja23(String root) => {
  '$root/api/v2/info': _v2NotFound,
  '$root/api/v1/info': fixture('info_v1_2.3.0.json'),
};

/// What servers before 2.4 answer for `/api/v2/info`.
final FakeRoute _v2NotFound = fixture('v2_info_404_2.3.0.json', status: 404);

Map<String, FakeRoute> _both(String root, FakeRoute route) => {
  '$root/api/v2/info': route,
  '$root/api/v1/info': route,
};

Future<ServerConnection> _connect(Dio dio, String input) =>
    DioServerConnector(dio).connect(input);

const _vikunjaWebApp =
    '<!doctype html><html><head><title>Vikunja</title> '
    "<script>window.API_URL = '/api/v1'</script></head></html>";

/// Routes of roots that all answer like Vikunja's web app does for paths it
/// does not know.
Map<String, FakeRoute> _webAppAt(List<String> roots) => {
  for (final root in roots) ..._both(root, html(_vikunjaWebApp)),
};

HandshakeException _certificateRejected() => const HandshakeException(
  'Handshake error in client (OS Error: '
  'CERTIFICATE_VERIFY_FAILED: self signed certificate)',
);

HandshakeException _plainHttpOnTlsPort() => const HandshakeException(
  'Handshake error in client (OS Error: WRONG_VERSION_NUMBER)',
);

Matcher _throwsFailure<T extends ServerConnectionFailure>({
  String? uri,
  Object? Function(T failure)? feature,
  Object? matcher,
}) {
  var failure = isA<T>();
  if (uri != null) {
    failure = failure.having((f) => f.uri.toString(), 'uri', uri);
  }
  if (feature != null) {
    failure = failure.having(feature, 'feature', matcher);
  }
  return throwsA(failure);
}

void main() {
  group('detects API versions', () {
    test('2.4+ answers on both versions and the v2 body is used', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': json({
          'version': 'v2.7.0',
          'motd': 'from v2',
        }),
        'https://example.com/api/v1/info': json({
          'version': 'v2.7.0',
          'motd': 'from v1',
        }),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.rootUri, Uri.parse('https://example.com'));
      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
      expect(connection.preferredApiVersion, ApiVersion.v2);
      expect(connection.info.motd, 'from v2');
      expect(connection.capabilities.tier, SupportTier.full);
      expect(connection.isInsecure, isFalse);
    });

    test('the captured 2.7.0 server', () async {
      final dio = fakeDio(_vikunja27('https://example.com'));

      final connection = await _connect(dio, 'example.com');

      expect(connection.info.version, const ServerVersion(2, 7, 0));
      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
      expect(connection.capabilities.has(Capability.bulkCreateTasks), isTrue);
      expect(connection.info.concurrentWrites, isFalse);
    });

    test('before 2.4 only v1 answers', () async {
      final dio = fakeDio(_vikunja23('https://example.com'));

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1});
      expect(connection.preferredApiVersion, ApiVersion.v1);
      expect(connection.info.version, const ServerVersion(2, 3, 0));
      expect(connection.capabilities.tier, SupportTier.oauth);
    });

    test('a proxy that forwards only /api/v2 still connects', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': fixture('info_v2_2.7.0.json'),
        'https://example.com/api/v1/info': html('<h1>Nope</h1>', status: 404),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v2});
      expect(connection.capabilities.tier, SupportTier.full);
    });

    test('a server older than 2.3 connects with an unsupported tier', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': _v2NotFound,
        'https://example.com/api/v1/info': fixture('info_v1_1.0.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.info.version, const ServerVersion(1, 0, 0));
      expect(connection.capabilities.tier, SupportTier.unsupported);
      expect(connection.capabilities.isSupported, isFalse);
    });

    test('2.0 connects, but is unsupported', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': _v2NotFound,
        'https://example.com/api/v1/info': fixture('info_v1_2.0.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.info.version, const ServerVersion(2, 0, 0));
      expect(connection.capabilities.tier, SupportTier.unsupported);
      expect(connection.capabilities.isSupported, isFalse);
    });

    test('an /info that is not 200 does not count', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': json({
          'version': 'v2.7.0',
        }, status: 500),
        'https://example.com/api/v1/info': fixture('info_v1_2.7.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1});
    });

    test('probes both versions with Accept: application/json and without '
        'following redirects', () async {
      final dio = fakeDio(_vikunja27('https://example.com'));

      await _connect(dio, 'https://example.com');

      final requests = adapterOf(dio).requests;
      expect(adapterOf(dio).requestedUrls, {
        'https://example.com/api/v2/info',
        'https://example.com/api/v1/info',
      });
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.headers['Accept'], 'application/json');
        expect(request.followRedirects, isFalse);
        expect(request.connectTimeout, const Duration(seconds: 5));
        expect(request.receiveTimeout, const Duration(seconds: 5));
      }
    });

    test('probes both versions at the same time', () async {
      final v1Requested = Completer<void>();
      final dio = fakeDio({
        'https://example.com/api/v2/info': (request) async {
          await v1Requested.future;
          return await fixture('info_v2_2.7.0.json')(request);
        },
        'https://example.com/api/v1/info': (request) {
          v1Requested.complete();
          return fixture('info_v1_2.7.0.json')(request);
        },
      });

      final connection = await _connect(
        dio,
        'https://example.com',
      ).timeout(const Duration(seconds: 2));

      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
    });
  });

  group('a v2 probe without an HTTP response', () {
    FakeRoute failingTimes(int failures, FakeRoute then) {
      var calls = 0;
      return (request) => calls++ < failures ? refused(request) : then(request);
    }

    test('is retried once when v1 reports 2.4 or newer', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': failingTimes(
          1,
          fixture('info_v2_2.7.0.json'),
        ),
        'https://example.com/api/v1/info': fixture('info_v1_2.7.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
      expect(connection.capabilities.tier, SupportTier.full);
      expect(adapterOf(dio).requestedUrls, [
        'https://example.com/api/v2/info',
        'https://example.com/api/v1/info',
        'https://example.com/api/v2/info',
      ]);
    });

    test('fails the connection when the retry gets none either', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': failsWith(
          (request) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 5),
            requestOptions: request,
          ),
        ),
        'https://example.com/api/v1/info': fixture('info_v1_2.7.0.json'),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<ServerTimeout>(uri: 'https://example.com'),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(3));
    });

    test('means no v2 when the retry gets any HTTP answer', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': failingTimes(1, _v2NotFound),
        'https://example.com/api/v1/info': fixture('info_v1_2.7.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1});
    });

    test('is retried for a development build', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': failingTimes(
          1,
          json({'version': 'unstable'}),
        ),
        'https://example.com/api/v1/info': json({'version': 'unstable'}),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
    });

    test('is not retried when v1 reports a version before 2.4', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': failsWith(
          (request) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 5),
            requestOptions: request,
          ),
        ),
        'https://example.com/api/v1/info': fixture('info_v1_2.3.0.json'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.apiVersions, {ApiVersion.v1});
      expect(connection.capabilities.tier, SupportTier.oauth);
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });
  });

  group('sub-paths', () {
    test('keeps the sub-path and strips /api/vN', () async {
      final dio = fakeDio(_vikunja27('https://example.com/vikunja'));

      final connection = await _connect(
        dio,
        'https://example.com/vikunja/api/v1/',
      );

      expect(connection.rootUri, Uri.parse('https://example.com/vikunja'));
      expect(
        connection.apiBaseUri(ApiVersion.v2),
        Uri.parse('https://example.com/vikunja/api/v2'),
      );
    });

    test(
      'a 3456 fallback keeps the sub-path (checkAndSetApiUrl.test.ts)',
      () async {
        final dio = fakeDio(_vikunja23('https://new.example.com:3456/root'));

        final connection = await _connect(
          dio,
          'https://new.example.com/root/api/v1',
        );

        expect(
          connection.rootUri,
          Uri.parse('https://new.example.com:3456/root'),
        );
        expect(adapterOf(dio).requestedUrls, [
          'https://new.example.com/root/api/v2/info',
          'https://new.example.com/root/api/v1/info',
          'https://new.example.com:3456/root/api/v2/info',
          'https://new.example.com:3456/root/api/v1/info',
        ]);
      },
    );

    test('a pasted /info URL is probed at its root', () async {
      final dio = fakeDio(_vikunja27('https://example.com'));

      final connection = await _connect(dio, 'example.com/api/v1/info');

      expect(connection.rootUri, Uri.parse('https://example.com'));
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });
  });

  group('a web app route instead of the root', () {
    test('walks up to the root', () async {
      final dio = fakeDio({
        ..._webAppAt([
          'https://example.com/projects/1/1',
          'https://example.com/projects/1',
          'https://example.com/projects',
        ]),
        ..._vikunja27('https://example.com'),
      });

      final connection = await _connect(dio, 'example.com/projects/1/1');

      expect(connection.rootUri, Uri.parse('https://example.com'));
      expect(adapterOf(dio).requestedUrls, [
        for (final path in ['/projects/1/1', '/projects/1', '/projects', ''])
          for (final version in ['v2', 'v1'])
            'https://example.com$path/api/$version/info',
      ]);
    });

    test('walks up to a sub-path root', () async {
      final dio = fakeDio({
        ..._webAppAt(['https://example.com/vikunja/login']),
        ..._vikunja27('https://example.com/vikunja'),
      });

      final connection = await _connect(
        dio,
        'https://example.com/vikunja/login',
      );

      expect(connection.rootUri, Uri.parse('https://example.com/vikunja'));
    });

    test('stops after four levels', () async {
      final dio = fakeDio({
        ..._webAppAt([
          'https://example.com/a/b/c/d/e',
          'https://example.com/a/b/c/d',
          'https://example.com/a/b/c',
          'https://example.com/a/b',
          'https://example.com/a',
        ]),
        ..._vikunja27('https://example.com'),
      });

      await expectLater(
        _connect(dio, 'https://example.com/a/b/c/d/e'),
        _throwsFailure<NotAVikunjaServer>(
          uri: 'https://example.com/a/b/c/d/e',
          feature: (f) => f.statusCode,
          matcher: 200,
        ),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(10));
    });

    test('other HTML at a sub-path is not walked up', () async {
      final dio = fakeDio({
        ..._both(
          'https://example.com/vikunja',
          html('<!doctype html><title>Welcome to nginx!</title>'),
        ),
        ..._vikunja27('https://example.com'),
      });

      await expectLater(
        _connect(dio, 'https://example.com/vikunja'),
        _throwsFailure<NotAVikunjaServer>(uri: 'https://example.com/vikunja'),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });
  });

  group('scheme fallback', () {
    test('without a scheme https is tried first', () async {
      final dio = fakeDio({
        ..._vikunja27('https://example.com'),
        ..._vikunja27('http://example.com'),
      });

      final connection = await _connect(dio, 'example.com');

      expect(connection.rootUri.scheme, 'https');
      expect(connection.isInsecure, isFalse);
      expect(
        adapterOf(dio).requestedUrls.where((url) => url.startsWith('http:')),
        isEmpty,
      );
    });

    test('without a scheme http is used when https cannot connect', () async {
      final dio = fakeDio(_vikunja27('http://example.com'));

      final connection = await _connect(dio, 'example.com');

      expect(connection.rootUri, Uri.parse('http://example.com'));
      expect(connection.isInsecure, isTrue);
      expect(adapterOf(dio).requestedUrls, [
        'https://example.com/api/v2/info',
        'https://example.com/api/v1/info',
        'https://example.com:3456/api/v2/info',
        'https://example.com:3456/api/v1/info',
        'http://example.com/api/v2/info',
        'http://example.com/api/v1/info',
      ]);
    });

    test('without a scheme http follows a failed TLS handshake', () async {
      final dio = fakeDio({
        ..._both(
          'https://localhost:34527',
          throwing(const HandshakeException('WRONG_VERSION_NUMBER')),
        ),
        ..._vikunja27('http://localhost:34527'),
      });

      final connection = await _connect(dio, 'localhost:34527');

      expect(connection.rootUri, Uri.parse('http://localhost:34527'));
      expect(connection.isInsecure, isTrue);
    });

    test('an explicit https:// is never downgraded to http', () async {
      final dio = fakeDio(_vikunja27('http://example.com'));

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<ServerUnreachable>(uri: 'https://example.com'),
      );
      expect(
        adapterOf(dio).requestedUrls.where((url) => url.startsWith('http:')),
        isEmpty,
      );
    });

    test('no http fallback once https answered over HTTP', () async {
      final dio = fakeDio({
        ..._both('https://example.com', html('<h1>Router</h1>')),
        ..._vikunja27('http://example.com'),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<NotAVikunjaServer>(
          feature: (f) => f.statusCode,
          matcher: 200,
        ),
      );
      expect(
        adapterOf(dio).requestedUrls.where((url) => url.startsWith('http:')),
        isEmpty,
      );
    });

    test('http that redirects to https of the same path is upgraded', () async {
      final dio = fakeDio({
        'http://example.com/vikunja/api/v2/info': redirect(
          'https://example.com/vikunja/api/v2/info',
          status: 301,
        ),
        'http://example.com/vikunja/api/v1/info': redirect(
          'https://example.com/vikunja/api/v1/info',
          status: 301,
        ),
        ..._vikunja27('https://example.com/vikunja'),
      });

      final connection = await _connect(dio, 'http://example.com/vikunja');

      expect(connection.rootUri, Uri.parse('https://example.com/vikunja'));
      expect(connection.isInsecure, isFalse);
    });

    test('an upgrade keeps the port of the redirect target', () async {
      final dio = fakeDio({
        ..._both(
          'http://example.com:8080',
          redirect('https://example.com:8443/api/v2/info'),
        ),
        ..._vikunja27('https://example.com:8443'),
      });

      final connection = await _connect(dio, 'http://example.com:8080');

      expect(connection.rootUri, Uri.parse('https://example.com:8443'));
    });

    test('an upgrade to an https address that already failed is not retried '
        'and reports that failure', () async {
      final dio = fakeDio({
        ..._both('https://example.com', throwing(_plainHttpOnTlsPort())),
        ..._both(
          'http://example.com',
          redirect('https://example.com/api/v2/info', status: 301),
        ),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<TlsFailure>(uri: 'https://example.com'),
      );
      expect(adapterOf(dio).requestedUrls, [
        'https://example.com/api/v2/info',
        'https://example.com/api/v1/info',
        'https://example.com:3456/api/v2/info',
        'https://example.com:3456/api/v1/info',
        'http://example.com/api/v2/info',
        'http://example.com/api/v1/info',
      ]);
    });
  });

  group('a rejected certificate', () {
    test('stops before http even when http serves Vikunja', () async {
      final dio = fakeDio({
        ..._both('https://example.com', throwing(_certificateRejected())),
        ..._vikunja27('http://example.com:3456'),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<TlsFailure>(
          uri: 'https://example.com',
          feature: (f) => f.certificateRejected,
          matcher: isTrue,
        ),
      );
      expect(adapterOf(dio).requestedUrls, [
        'https://example.com/api/v2/info',
        'https://example.com/api/v1/info',
      ]);
    });

    test('is not hidden by another page on http', () async {
      final dio = fakeDio({
        ..._both('https://example.com', throwing(_certificateRejected())),
        ..._both('http://example.com', html('<h1>nginx</h1>', status: 404)),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<TlsFailure>(uri: 'https://example.com'),
      );
    });

    test('on a typed port is not hidden by plain http on that port', () async {
      final dio = fakeDio({
        ..._both('https://example.com:8443', throwing(_certificateRejected())),
        ..._both(
          'http://example.com:8443',
          html('The plain HTTP request was sent to HTTPS port', status: 400),
        ),
      });

      await expectLater(
        _connect(dio, 'example.com:8443'),
        _throwsFailure<TlsFailure>(uri: 'https://example.com:8443'),
      );
    });

    test('a TLS protocol mismatch still moves on to http', () async {
      final dio = fakeDio({
        ..._both('https://example.com:8080', throwing(_plainHttpOnTlsPort())),
        ..._both('http://example.com:8080', html('<h1>x</h1>', status: 404)),
      });

      await expectLater(
        _connect(dio, 'example.com:8080'),
        _throwsFailure<NotAVikunjaServer>(
          uri: 'http://example.com:8080',
          feature: (f) => f.statusCode,
          matcher: 404,
        ),
      );
    });
  });

  group('port 3456 fallback', () {
    test('every rejected candidate is probed once '
        '(checkAndSetApiUrl.test.ts)', () async {
      final dio = fakeDio({});

      await expectLater(
        _connect(dio, 'https://new.example.com'),
        _throwsFailure<ServerUnreachable>(uri: 'https://new.example.com'),
      );
      expect(adapterOf(dio).requestedUrls, [
        'https://new.example.com/api/v2/info',
        'https://new.example.com/api/v1/info',
        'https://new.example.com:3456/api/v2/info',
        'https://new.example.com:3456/api/v1/info',
      ]);
    });

    test('is not tried when a port was typed', () async {
      final dio = fakeDio({});

      await expectLater(
        _connect(dio, 'https://example.com:8443'),
        _throwsFailure<ServerUnreachable>(uri: 'https://example.com:8443'),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });

    test('is not tried when the default port answered over HTTP', () async {
      final dio = fakeDio({
        ..._both('https://example.com', html('<h1>404</h1>', status: 404)),
        ..._vikunja27('https://example.com:3456'),
      });

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<NotAVikunjaServer>(
          feature: (f) => f.statusCode,
          matcher: 404,
        ),
      );
    });

    test('is tried after a timeout', () async {
      final dio = fakeDio({
        ..._both(
          'https://example.com',
          failsWith(
            (request) => DioException.connectionTimeout(
              timeout: const Duration(seconds: 5),
              requestOptions: request,
            ),
          ),
        ),
        ..._vikunja27('https://example.com:3456'),
      });

      final connection = await _connect(dio, 'https://example.com');

      expect(connection.rootUri, Uri.parse('https://example.com:3456'));
    });

    test('an HTTP answer on 3456 beats a connection error on the default port '
        'and stops the http fallback', () async {
      final dio = fakeDio({
        ..._both('https://example.com:3456', _v2NotFound),
        ..._vikunja27('http://example.com'),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<NotAVikunjaServer>(uri: 'https://example.com:3456'),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(4));
    });
  });

  group('a redirect to the /info of another root', () {
    Map<String, FakeRoute> redirectsTo(String from, String to) => {
      for (final version in ['v2', 'v1'])
        '$from/api/$version/info': redirect(
          '$to/api/$version/info',
          status: 301,
        ),
    };

    for (final (description, input, from, to) in [
      (
        'apex to www',
        'example.com',
        'https://example.com',
        'https://www.example.com',
      ),
      (
        'a domain move',
        'https://old.example.com/vikunja',
        'https://old.example.com/vikunja',
        'https://new.example.org/todo',
      ),
      (
        'an IP address to a host name over http',
        'http://192.168.1.10',
        'http://192.168.1.10',
        'http://vikunja.home.lan',
      ),
      (
        'http to https on another host',
        'http://192.168.1.10',
        'http://192.168.1.10',
        'https://vikunja.example.com',
      ),
    ]) {
      test('is followed: $description', () async {
        final dio = fakeDio({...redirectsTo(from, to), ..._vikunja27(to)});

        final connection = await _connect(dio, input);

        expect(connection.rootUri, Uri.parse(to));
        expect(adapterOf(dio).requestedUrls, hasLength(4));
      });
    }

    for (final location in ['https://example.com/', 'https://example.com']) {
      test(
        'http to https of the same host without a path: $location',
        () async {
          final dio = fakeDio({
            ..._both('http://example.com', redirect(location, status: 301)),
            ..._vikunja27('https://example.com'),
          });

          final connection = await _connect(dio, 'http://example.com');

          expect(connection.rootUri, Uri.parse('https://example.com'));
        },
      );
    }

    test('http to https keeps the sub-path', () async {
      final dio = fakeDio({
        ..._both(
          'http://example.com/vikunja',
          redirect('https://example.com/vikunja/', status: 301),
        ),
        ..._vikunja27('https://example.com/vikunja'),
      });

      final connection = await _connect(dio, 'http://example.com/vikunja');

      expect(connection.rootUri, Uri.parse('https://example.com/vikunja'));
    });

    test('reports the failure of the target', () async {
      final dio = fakeDio(
        redirectsTo('https://example.com', 'https://www.example.com'),
      );

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<ServerUnreachable>(uri: 'https://www.example.com'),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(4));
    });

    test('keeps a login-like target that fails as a login proxy', () async {
      final dio = fakeDio(
        redirectsTo('https://example.com', 'https://example.com/sso'),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(
          feature: (f) => f.redirectTarget,
          matcher: Uri.parse('https://example.com/sso/api/v2/info'),
        ),
      );
    });

    test('only one is followed', () async {
      final dio = fakeDio({
        ...redirectsTo('http://example.com', 'https://example.com'),
        ...redirectsTo('https://example.com', 'https://www.example.com'),
        ..._vikunja27('https://www.example.com'),
      });

      await expectLater(
        _connect(dio, 'http://example.com'),
        _throwsFailure<BehindLoginProxy>(uri: 'https://example.com'),
      );
      expect(
        adapterOf(dio).requestedUrls.where((url) => url.contains('www.')),
        isEmpty,
      );
    });

    test('is not followed when the probes disagree', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': redirect(
          'https://a.example.com/api/v2/info',
        ),
        'https://example.com/api/v1/info': redirect(
          'https://b.example.com/api/v1/info',
        ),
      });

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });

    test('is not followed from https to http', () async {
      final dio = fakeDio({
        ...redirectsTo('https://example.com', 'http://www.example.com'),
        ..._vikunja27('http://www.example.com'),
      });

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });
  });

  group('behind a login proxy', () {
    test('a redirect to another host', () async {
      final dio = fakeDio(
        _both(
          'https://vikunja.example.com',
          redirect('https://auth.example.com/?rd=https%3A%2F%2Fvikunja'),
        ),
      );

      await expectLater(
        _connect(dio, 'vikunja.example.com'),
        _throwsFailure<BehindLoginProxy>(
          uri: 'https://vikunja.example.com',
          feature: (f) => f.redirectTarget,
          matcher: Uri.parse(
            'https://auth.example.com/?rd=https%3A%2F%2Fvikunja',
          ),
        ),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });

    test('a relative redirect to a login path on the same host', () async {
      final dio = fakeDio(
        _both('https://example.com', redirect('/oauth2/start?rd=%2Fapi')),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(
          feature: (f) => f.redirectTarget,
          matcher: Uri.parse('https://example.com/oauth2/start?rd=%2Fapi'),
        ),
      );
    });

    test('a redirect from http to a login page over https', () async {
      final dio = fakeDio(
        _both('http://example.com', redirect('https://example.com/login')),
      );

      await expectLater(
        _connect(dio, 'http://example.com'),
        _throwsFailure<BehindLoginProxy>(
          uri: 'http://example.com',
          feature: (f) => f.redirectTarget,
          matcher: Uri.parse('https://example.com/login'),
        ),
      );
    });

    test('HTTP Basic auth', () async {
      final dio = fakeDio(
        _both(
          'https://example.com',
          status(
            401,
            headers: {
              'www-authenticate': ['Basic realm="Restricted"'],
            },
          ),
        ),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(
          feature: (f) => f.redirectTarget,
          matcher: isNull,
        ),
      );
    });

    for (final (description, route) in [
      ('a 401 without a challenge (oauth2-proxy)', json({}, status: 401)),
      (
        'a 401 HTML page with a Location but no challenge (Authelia)',
        (RequestOptions request) => ResponseBody.fromString(
          '<a href="https://auth.example.com/">401 Unauthorized</a>',
          401,
          headers: {
            Headers.contentTypeHeader: ['text/html; charset=utf-8'],
            'location': ['https://auth.example.com/?rd=https%3A%2F%2Fx'],
          },
        ),
      ),
      ('a 407', status(407)),
    ]) {
      test(description, () async {
        final dio = fakeDio(_both('https://example.com', route));

        await expectLater(
          _connect(dio, 'https://example.com'),
          _throwsFailure<BehindLoginProxy>(
            feature: (f) => f.redirectTarget,
            matcher: isNull,
          ),
        );
      });
    }

    test('an HTML login form', () async {
      final dio = fakeDio(
        _both(
          'https://example.com',
          html(
            '<html><form method="post"><input name="user"> '
            '<input type="password" name="pw"></form></html>',
          ),
        ),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(),
      );
    });

    test('wins over a network error of the other probe', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': redirect('https://sso.example.org/'),
      });

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<BehindLoginProxy>(),
      );
    });
  });

  group('not a Vikunja server', () {
    for (final (description, route, statusCode) in [
      ('an HTML page', html('<!doctype html><title>Hi</title>'), 200),
      ('an HTML 404', html('<h1>Not found</h1>', status: 404), 404),
      ('JSON of another app', json({'name': 'gitea'}), 200),
      ('a version that is not a string', json({'version': 27}), 200),
      ('a JSON array', json(['v2.7.0']), 200),
      ('an empty body', status(200), 200),
      ('a 403 without a challenge', html('<h1>Blocked</h1>', status: 403), 403),
      ('a redirect without Location', status(302), 302),
      ('a redirect within the host', redirect('/api/v2/info/'), 302),
    ]) {
      test(description, () async {
        final dio = fakeDio(_both('https://example.com', route));

        await expectLater(
          _connect(dio, 'https://example.com'),
          _throwsFailure<NotAVikunjaServer>(
            uri: 'https://example.com',
            feature: (f) => f.statusCode,
            matcher: statusCode,
          ),
        );
      });
    }

    test('reports the status of the v1 probe', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': html('', status: 404),
        'https://example.com/api/v1/info': html('', status: 410),
      });

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<NotAVikunjaServer>(
          feature: (f) => f.statusCode,
          matcher: 410,
        ),
      );
    });

    test('an https server redirecting to http is not followed', () async {
      final dio = fakeDio(
        _both(
          'https://example.com',
          redirect('http://example.com/api/v1/info'),
        ),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<NotAVikunjaServer>(),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });

    test(
      'a status rejected by an interceptor of the caller is still read',
      () async {
        final dio = fakeDio(_both('https://example.com', html('', status: 404)))
          ..interceptors.add(
            InterceptorsWrapper(
              onResponse: (response, handler) => handler.reject(
                DioException.badResponse(
                  statusCode: response.statusCode!,
                  requestOptions: response.requestOptions,
                  response: response,
                ),
              ),
            ),
          );

        await expectLater(
          _connect(dio, 'https://example.com'),
          _throwsFailure<NotAVikunjaServer>(
            feature: (f) => f.statusCode,
            matcher: 404,
          ),
        );
      },
    );
  });

  group('server unavailable', () {
    for (final (description, v2, v1, statusCode) in [
      (
        'a proxy whose Vikunja is down',
        html('<h1>502 Bad Gateway</h1>', status: 502),
        html('<h1>502 Bad Gateway</h1>', status: 502),
        502,
      ),
      ('only v1 unavailable', _v2NotFound, status(503), 503),
      ('only v2 unavailable', status(503), html('', status: 404), 503),
      ('a JSON 500', json({'message': 'x'}, status: 500), status(500), 500),
    ]) {
      test(description, () async {
        final dio = fakeDio({
          'https://example.com/api/v2/info': v2,
          'https://example.com/api/v1/info': v1,
        });

        await expectLater(
          _connect(dio, 'https://example.com'),
          _throwsFailure<ServerUnavailable>(
            uri: 'https://example.com',
            feature: (f) => f.statusCode,
            matcher: statusCode,
          ),
        );
      });
    }

    test('rate limited, with Retry-After', () async {
      final dio = fakeDio(
        _both(
          'https://example.com',
          status(
            429,
            headers: {
              'retry-after': ['30'],
            },
          ),
        ),
      );

      await expectLater(
        _connect(dio, 'https://example.com'),
        _throwsFailure<ServerUnavailable>(
          feature: (f) => (f.statusCode, f.retryAfter),
          matcher: (429, const Duration(seconds: 30)),
        ),
      );
    });

    test('stops the port and scheme fallback', () async {
      final dio = fakeDio({
        ..._both('https://example.com', status(502)),
        ..._vikunja27('http://example.com'),
      });

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<ServerUnavailable>(),
      );
      expect(adapterOf(dio).requestedUrls, hasLength(2));
    });
  });

  group('connection failures', () {
    Future<void> expectFailure(
      FakeRoute route,
      Matcher matcher, {
      String input = 'https://example.com:8443',
    }) async {
      final root = normalizeServerAddress(input).root.toString();
      final dio = fakeDio(_both(root, route));
      await expectLater(_connect(dio, input), matcher);
    }

    test('connection refused', () async {
      await expectFailure(
        refused,
        _throwsFailure<ServerUnreachable>(
          uri: 'https://example.com:8443',
          feature: (f) => f.cause,
          matcher: isA<SocketException>(),
        ),
      );
    });

    test('a failed host lookup of a host named like TLS', () async {
      await expectFailure(
        failsWith(
          (request) => DioException.connectionError(
            requestOptions: request,
            reason: "Failed host lookup: 'ssl.example.com'",
            error: const SocketException(
              "Failed host lookup: 'ssl.example.com'",
            ),
          ),
        ),
        _throwsFailure<ServerUnreachable>(),
        input: 'https://ssl.example.com:8443',
      );
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test('$type', () async {
        await expectFailure(
          failsWith(
            (request) => DioException(requestOptions: request, type: type),
          ),
          _throwsFailure<ServerTimeout>(uri: 'https://example.com:8443'),
        );
      });
    }

    Matcher throwsTls({required bool certificateRejected, Object? cause}) =>
        throwsA(
          isA<TlsFailure>()
              .having(
                (f) => f.certificateRejected,
                'certificateRejected',
                certificateRejected,
              )
              .having((f) => f.cause, 'cause', cause ?? anything),
        );

    test('a certificate rejected by validateCertificate', () async {
      await expectFailure(
        failsWith(
          (request) => DioException.badCertificate(requestOptions: request),
        ),
        throwsTls(certificateRejected: true),
      );
    });

    test('dart:io HandshakeException (wrapped by Dio as unknown)', () async {
      await expectFailure(
        throwing(const HandshakeException('CERTIFICATE_VERIFY_FAILED')),
        throwsTls(certificateRejected: true, cause: isA<HandshakeException>()),
      );
    });

    test('dart:io HandshakeException of a plain http port', () async {
      await expectFailure(
        throwing(_plainHttpOnTlsPort()),
        throwsTls(certificateRejected: false),
      );
    });

    test('dart:io CertificateException', () async {
      await expectFailure(
        throwing(const CertificateException('expired')),
        throwsTls(certificateRejected: true),
      );
    });

    for (final (adapter, message, certificateRejected) in [
      (
        'cronet_http',
        'NetworkClientException: Exception in CronetUrlRequest: '
            'net::ERR_CERT_AUTHORITY_INVALID, ErrorCode=11, '
            'InternalErrorCode=-202, Retryable=false, '
            'uri=https://example.com:8443/api/v2/info, errorCode=11, '
            'cronetInternalErrorCode=-202, immediatelyRetryable=false',
        true,
      ),
      (
        'cronet_http with only the internal code',
        'NetworkClientException: failed, uri=https://example.com:8443/, '
            'errorCode=11, cronetInternalErrorCode=-200, '
            'immediatelyRetryable=false',
        true,
      ),
      (
        'cronet_http SSL',
        'NetworkClientException: net::ERR_SSL_PROTOCOL_ERROR',
        false,
      ),
      (
        'cupertino_http',
        'NSErrorClientException: The certificate for this server is invalid. '
            '[domain=NSURLErrorDomain, code=-1202], '
            'uri=https://example.com:8443/api/v2/info',
        true,
      ),
      (
        'cupertino_http by code',
        'NSErrorClientException: Something went wrong. '
            '[domain=NSURLErrorDomain, code=-1206]',
        true,
      ),
      (
        'cupertino_http secure connection',
        'NSErrorClientException: An SSL error has occurred and a secure '
            'connection to the server cannot be made. '
            '[domain=NSURLErrorDomain, code=-1200]',
        false,
      ),
    ]) {
      test('TLS failure from $adapter', () async {
        await expectFailure(
          throwing(_NativeClientException(message)),
          throwsTls(certificateRejected: certificateRejected),
        );
      });
    }

    for (final (adapter, message) in [
      (
        'cronet_http',
        'NetworkClientException: net::ERR_CONNECTION_REFUSED, '
            'uri=https://ssl-tls-certificate.example.com/, errorCode=7, '
            'cronetInternalErrorCode=-102, immediatelyRetryable=false',
      ),
      (
        'cupertino_http',
        'NSErrorClientException: A server with the specified hostname could '
            'not be found. [domain=NSURLErrorDomain, code=-1003]',
      ),
    ]) {
      test('unreachable from $adapter', () async {
        await expectFailure(
          throwing(_NativeClientException(message)),
          _throwsFailure<ServerUnreachable>(),
        );
      });
    }

    test('timeout from cupertino_http', () async {
      await expectFailure(
        throwing(
          _NativeClientException(
            'NSErrorClientException: The request timed out. '
            '[domain=NSURLErrorDomain, code=-1001]',
          ),
        ),
        _throwsFailure<ServerTimeout>(),
      );
    });

    test(
      'TLS wording on a plain http connection is not a TLS failure',
      () async {
        await expectFailure(
          throwing(_NativeClientException('SSL routines: wrong version')),
          _throwsFailure<ServerUnreachable>(),
          input: 'http://example.com:8080',
        );
      },
    );

    test(
      'a timeout of one probe beats a non-Vikunja answer of the other',
      () async {
        final dio = fakeDio({
          'https://example.com:8443/api/v2/info': _v2NotFound,
          'https://example.com:8443/api/v1/info': failsWith(
            (request) => DioException.receiveTimeout(
              timeout: const Duration(seconds: 10),
              requestOptions: request,
            ),
          ),
        });

        await expectLater(
          _connect(dio, 'https://example.com:8443'),
          _throwsFailure<ServerTimeout>(),
        );
      },
    );

    test(
      'a TLS protocol mismatch on https beats unreachable on http',
      () async {
        final dio = fakeDio(
          _both('https://example.com', throwing(_plainHttpOnTlsPort())),
        );

        await expectLater(
          _connect(dio, 'example.com'),
          _throwsFailure<TlsFailure>(uri: 'https://example.com'),
        );
        expect(adapterOf(dio).requestedUrls, hasLength(8));
      },
    );

    test('a timeout beats unreachable', () async {
      final dio = fakeDio(
        _both(
          'http://example.com',
          failsWith(
            (request) => DioException.connectionTimeout(
              timeout: const Duration(seconds: 5),
              requestOptions: request,
            ),
          ),
        ),
      );

      await expectLater(
        _connect(dio, 'example.com'),
        _throwsFailure<ServerTimeout>(uri: 'http://example.com'),
      );
    });

    test('invalid input fails before any request', () async {
      final dio = fakeDio({});

      await expectLater(
        _connect(dio, 'ftp://example.com'),
        _throwsFailure<InvalidServerAddress>(),
      );
      expect(adapterOf(dio).requests, isEmpty);
    });
  });

  group('candidates overlap', () {
    const probeTimeout = Duration(milliseconds: 400);
    const stagger = Duration(milliseconds: 50);
    Future<ServerConnection> connect(Dio dio, String input) =>
        DioServerConnector(
          dio,
          probeTimeout: probeTimeout,
          candidateStagger: stagger,
        ).connect(input);

    test('a later candidate starts before an earlier one times out', () async {
      final dio = fakeDio({
        ..._both('https://example.com', timesOut),
        ..._both('https://example.com:3456', timesOut),
        ..._both('http://example.com', timesOut),
        ..._vikunja27('http://example.com:3456'),
      });
      final stopwatch = Stopwatch()..start();

      final connection = await connect(dio, 'example.com');

      expect(connection.rootUri, Uri.parse('http://example.com:3456'));
      // Strictly one after another would take three probe timeouts.
      expect(stopwatch.elapsed, lessThan(probeTimeout * 2));
      for (final request in adapterOf(dio).requests) {
        expect(request.connectTimeout, probeTimeout);
        expect(request.receiveTimeout, probeTimeout);
      }
    });

    test('an earlier candidate that answers later still wins', () async {
      final dio = fakeDio({
        'https://example.com/api/v2/info': delayed(stagger * 4, _v2NotFound),
        'https://example.com/api/v1/info': delayed(
          stagger * 4,
          fixture('info_v1_2.3.0.json'),
        ),
        ..._vikunja27('https://example.com:3456'),
        ..._both('http://example.com', hangs),
      });

      final connection = await connect(dio, 'example.com');

      expect(connection.rootUri, Uri.parse('https://example.com'));
      expect(connection.info.version, const ServerVersion(2, 3, 0));
      final abandoned = adapterOf(dio).requests
          .where((request) => request.uri.isScheme('http'))
          .toList();
      expect(abandoned, isNotEmpty);
      for (final request in abandoned) {
        expect(request.cancelToken!.isCancelled, isTrue);
      }
    });
  });

  group('cancellation', () {
    test('rethrows the DioException of a cancelled probe', () async {
      final started = Completer<void>();
      final dio = fakeDio(
        _both('https://example.com', (request) async {
          if (!started.isCompleted) started.complete();
          await Completer<void>().future;
          throw StateError('unreachable');
        }),
      );
      final cancelToken = CancelToken();

      final connecting = DioServerConnector(dio)
          .connect('https://example.com', cancelToken: cancelToken);
      await started.future;
      cancelToken.cancel('user left');

      await expectLater(
        connecting,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });

    test('a token cancelled up front sends nothing', () async {
      final dio = fakeDio(_vikunja27('https://example.com'));
      final cancelToken = CancelToken()..cancel();

      await expectLater(
        DioServerConnector(dio)
            .connect('https://example.com', cancelToken: cancelToken),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(adapterOf(dio).requests, isEmpty);
    });

    test('cancelling between candidates stops the fallback', () async {
      final cancelToken = CancelToken();
      final dio = fakeDio({
        ..._both('https://example.com', (request) {
          cancelToken.cancel();
          return refused(request);
        }),
        ..._vikunja27('https://example.com:3456'),
      });

      await expectLater(
        DioServerConnector(dio)
            .connect('https://example.com', cancelToken: cancelToken),
        throwsA(isA<DioException>()),
      );
      expect(
        adapterOf(dio).requestedUrls.where((url) => url.contains(':3456')),
        isEmpty,
      );
    });
  });
}

/// Stands in for package:http's ClientException subclasses of the native
/// adapters, which Dio wraps as [DioExceptionType.unknown].
final class _NativeClientException(final String message) implements Exception {
  @override
  String toString() => message;
}
