import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/negotiation/info_probe.dart';
import 'package:vikunja_api/src/negotiation/probe_classifier.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final Uri _root = Uri.parse('https://example.com');

InfoAnswer _answer(
  ApiVersion version,
  int statusCode, {
  String body = '',
  Map<String, List<String>> headers = const {},
}) => InfoAnswer(
  requestUri: _root.replace(path: '/api/${version.pathSegment}/info'),
  statusCode: statusCode,
  headers: Headers.fromMap(headers),
  body: body,
);

final InfoAnswer _notFound = _answer(ApiVersion.v1, 404);

Matcher _failsWith<T extends ServerConnectionFailure>() =>
    isA<CandidateFailed>().having(
      (outcome) => outcome.failure,
      'failure',
      isA<T>(),
    );

void main() {
  // The answers come before any trust in the server, and the classifier runs
  // on the UI isolate. The test's own timeout cannot stop synchronous work,
  // so the time is checked after it.
  group('a hostile answer is classified quickly', () {
    void timedTest(String description, void Function() body) {
      test(description, () {
        final watch = Stopwatch()..start();
        body();
        expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
      });
    }

    timedTest('a redirect target with a long run of slashes', () {
      final slashes = '/' * 64000;
      InfoAnswer redirect(String location) => _answer(
        ApiVersion.v2,
        301,
        headers: {
          'location': [location],
        },
      );

      expect(
        classifyProbes(
          _root,
          v2: redirect('https://example.com${slashes}x'),
          v1: _notFound,
        ),
        _failsWith<NotAVikunjaServer>(),
      );
      expect(
        classifyProbes(
          _root,
          v2: redirect('https://www.example.com/api/v2/info$slashes'),
          v1: _notFound,
        ),
        isA<RedirectsTo>().having(
          (outcome) => outcome.root,
          'root',
          Uri.parse('https://www.example.com'),
        ),
      );
    });

    timedTest("an HTML body of '<input' up to the probe's limit", () {
      InfoAnswer page(String body) => _answer(
        ApiVersion.v2,
        200,
        body: body,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
      final inputs = '<input' * (maxProbeBodyBytes ~/ '<input'.length);

      expect(
        classifyProbes(_root, v2: page(inputs), v1: _notFound),
        _failsWith<NotAVikunjaServer>(),
      );
      expect(
        classifyProbes(
          _root,
          v2: page('$inputs<input type="password">'),
          v1: _notFound,
        ),
        _failsWith<BehindLoginProxy>(),
      );
    });
  });
}
