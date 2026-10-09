import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

void main() {
  group('describeUriForLog', () {
    test('drops query, fragment and user info', () {
      final uri = Uri.parse(
        'https://alice:secret@vikunja.example.com:8443/api/v1/info'
        '?token=abc#frag',
      );

      expect(
        describeUriForLog(uri),
        'https://vikunja.example.com:8443/api/v1/info',
      );
    });

    test('keeps default ports implicit', () {
      expect(
        describeUriForLog(Uri.parse('https://example.com/api/v2/info?x=1')),
        'https://example.com/api/v2/info',
      );
    });

    test('handles relative URIs', () {
      expect(describeUriForLog(Uri.parse('/info?token=x')), '/info');
      expect(describeUriForLog(Uri()), '<relative>');
    });
  });

  group('redactSecrets', () {
    test('redacts credential headers', () {
      expect(
        redactSecrets('Authorization: Bearer abcdefghijklmnopqrstuvwxyz'),
        'Authorization: [redacted]',
      );
      expect(
        redactSecrets('set-cookie: vikunja_refresh=abc; HttpOnly'),
        'set-cookie: [redacted]',
      );
      expect(redactSecrets('Cookie: a=b'), 'Cookie: [redacted]');
    });

    test('redacts bearer tokens in free text', () {
      expect(
        redactSecrets('sent bearer 0123456789abcdef0123 to server'),
        'sent bearer [redacted] to server',
      );
    });

    test('redacts JWTs and Vikunja API tokens', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJlLXNpZ25hdHVyZQ';
      expect(redactSecrets('token $jwt expired'), 'token [redacted] expired');
      expect(
        redactSecrets('using tk_0123456789abcdef now'),
        'using [redacted] now',
      );
    });

    test('redacts secrets in JSON bodies', () {
      expect(
        redactSecrets('{"username":"alice","password":"hunter2"}'),
        '{"username":"alice","password":"[redacted]"}',
      );
      expect(
        redactSecrets('{"refresh_token" : "abc", "totp_passcode":"123456"}'),
        '{"refresh_token":"[redacted]", "totp_passcode":"[redacted]"}',
      );
    });

    test('redacts secrets in query and form strings', () {
      expect(
        redactSecrets('GET /callback?code=xyz&state=s1&page=2'),
        'GET /callback?code=[redacted]&state=[redacted]&page=2',
      );
      expect(
        redactSecrets('grant_type=refresh_token&refresh_token=abc'),
        'grant_type=refresh_token&refresh_token=[redacted]',
      );
    });

    test('redacts user info in URLs', () {
      expect(
        redactSecrets('failed for https://bob:pw@example.com/api'),
        'failed for https://[redacted]@example.com/api',
      );
    });

    test('leaves ordinary messages untouched', () {
      const message =
          'GET https://vikunja.example.com/api/v1/info -> 200 12 ms '
          '(statusCode=200, basic auth disabled)';
      expect(redactSecrets(message), message);
    });
  });
}
