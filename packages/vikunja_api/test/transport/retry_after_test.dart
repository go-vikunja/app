import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/transport/retry_after.dart';

Headers _headers(Map<String, String> values) => Headers.fromMap({
  for (final MapEntry(:key, :value) in values.entries) key: [value],
});

final _deviceNow = DateTime.utc(2030);

Duration? _retryAfter(Map<String, String> headers) =>
    retryAfterOf(_headers(headers), now: () => _deviceNow);

void main() {
  test('Retry-After in seconds', () {
    expect(_retryAfter({'retry-after': '60'}), const Duration(seconds: 60));
    expect(_retryAfter({'Retry-After': ' 0 '}), Duration.zero);
  });

  test('a negative Retry-After is ignored', () {
    expect(_retryAfter({'retry-after': '-5'}), isNull);
  });

  test('a Retry-After date counts from the Date header', () {
    expect(
      _retryAfter({
        'retry-after': 'Fri, 09 Oct 2026 08:12:36 GMT',
        'date': 'Fri, 09 Oct 2026 08:11:36 GMT',
      }),
      const Duration(minutes: 1),
    );
  });

  test('a Retry-After date without a Date header counts from now', () {
    expect(
      _retryAfter({'retry-after': 'Tue, 01 Jan 2030 00:00:30 GMT'}),
      const Duration(seconds: 30),
    );
  });

  test('a past Retry-After date means now', () {
    expect(
      _retryAfter({'retry-after': 'Fri, 09 Oct 2026 08:11:36 GMT'}),
      Duration.zero,
    );
  });

  test('X-RateLimit-Reset of 2.3.0 counts from the Date header', () {
    expect(
      _retryAfter({
        'x-ratelimit-reset': '1791533555',
        'date': 'Fri, 09 Oct 2026 08:11:36 GMT',
      }),
      const Duration(seconds: 60),
    );
  });

  test('Retry-After wins over X-RateLimit-Reset', () {
    expect(
      _retryAfter({'retry-after': '5', 'x-ratelimit-reset': '1791533555'}),
      const Duration(seconds: 5),
    );
  });

  test('an unreadable Retry-After falls back to X-RateLimit-Reset', () {
    expect(
      _retryAfter({
        'retry-after': 'soon',
        'x-ratelimit-reset': '1791533555',
        'date': 'Fri, 09 Oct 2026 08:11:36 GMT',
      }),
      const Duration(seconds: 60),
    );
  });

  test('nothing usable is null', () {
    expect(_retryAfter({}), isNull);
    expect(_retryAfter({'retry-after': 'soon'}), isNull);
    expect(_retryAfter({'x-ratelimit-reset': 'later'}), isNull);
  });
}
