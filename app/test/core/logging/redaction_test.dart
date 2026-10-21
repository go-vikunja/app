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

    test('redacts the OAuth callback URL', () {
      expect(
        redactSecrets(
          'vikunja-dev.coderoftime.vikunja://oauth/callback'
          '?code=Zm9vYmFy&state=c3RhdGU',
        ),
        'vikunja-dev.coderoftime.vikunja://oauth/callback'
        '?code=[redacted]&state=[redacted]',
      );
    });

    test('redacts token fields however they are printed', () {
      expect(
        redactSecrets('{access_token: abc.def, refresh_token: 0a1b2c}'),
        '{access_token: [redacted], refresh_token: [redacted]}',
      );
      expect(
        redactSecrets('{"state":"xyz","code_verifier":"v"}'),
        '{"state":"[redacted]","code_verifier":"[redacted]"}',
      );
      expect(
        redactSecrets('access_token=abc&token_type=bearer'),
        'access_token=[redacted]&token_type=bearer',
      );
    });

    test('redacts TOTP secrets and setup links', () {
      const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
      const link =
          'otpauth://totp/Vikunja:alice?algorithm=SHA1&digits=6'
          '&issuer=Vikunja&period=30&secret=$secret';
      final redacted = [
        redactSecrets('{"secret":"$secret","enabled":false,"url":"$link"}'),
        redactSecrets('{secret: $secret, enabled: false}'),
        redactSecrets('opening $link failed'),
        redactSecrets('enroll?secret=$secret&x=1'),
      ];

      expect(
        redacted[0],
        '{"secret":"[redacted]","enabled":false,"url":"[redacted]"}',
      );
      expect(redacted[1], '{secret: [redacted], enabled: false}');
      expect(redacted[2], 'opening [redacted] failed');
      expect(redacted[3], 'enroll?secret=[redacted]&x=1');
      for (final text in redacted) {
        expect(text, isNot(contains(secret)));
        expect(text, isNot(contains('alice')));
      }
    });

    test('redacts new API and CalDAV tokens in create answers', () {
      final apiToken = 'tk_${'0a' * 20}';
      final caldavToken = 'aB3' * 21 + 'x';
      expect(
        redactSecrets('{"id":4,"title":"CI","token":"$apiToken"}'),
        '{"id":4,"title":"CI","token":"[redacted]"}',
      );
      expect(
        redactSecrets('created $caldavToken for CalDAV'),
        'created [redacted] for CalDAV',
      );
    });

    test('redacts short bearer tokens too', () {
      expect(redactSecrets('Bearer abcd1234'), 'Bearer [redacted]');
    });

    test('redacts long opaque tokens such as refresh tokens', () {
      final refreshToken = 'a1' * 128;
      final code = 'Q' * 64;
      expect(
        redactSecrets('rotated $refreshToken after $code'),
        'rotated [redacted] after [redacted]',
      );
    });

    test('keeps Vikunja error codes readable', () {
      expect(
        redactSecrets('{code: 11, message: invalid token}'),
        '{code: 11, message: invalid token}',
      );
      expect(
        redactSecrets('SessionEnded(code: 16002)'),
        'SessionEnded(code: 16002)',
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
