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

    test("hides a link share's hash in the web's link and the API", () {
      final hash = 'aB3dE' * 8;

      expect(
        describeUriForLog(
          Uri.parse('https://example.com/vikunja/share/$hash/auth?view=3'),
        ),
        'https://example.com/vikunja/share/[redacted]/auth',
      );
      expect(
        describeUriForLog(
          Uri.parse('https://example.com/api/v1/shares/$hash/auth'),
        ),
        'https://example.com/api/v1/shares/[redacted]/auth',
      );
      expect(
        describeUriForLog(Uri.parse('/shares/short/auth')),
        '/shares/[redacted]/auth',
      );
    });

    test("keeps a share's numeric id and the share lists", () {
      expect(
        describeUriForLog(
          Uri.parse('https://example.com/api/v2/projects/4/shares/12'),
        ),
        'https://example.com/api/v2/projects/4/shares/12',
      );
      expect(
        describeUriForLog(
          Uri.parse('https://example.com/api/v2/projects/4/shares'),
        ),
        'https://example.com/api/v2/projects/4/shares',
      );
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

    test('redacts a JWT and a JSON value that an excerpt cuts off', () {
      final excerpt = FormatException(
        'Unexpected end of input',
        '{"access_token":"eyJhbGciOiJIUzI1NiJ9.${'eyJ0eXAiOjF9' * 8}.sig"}',
      ).toString();
      expect(excerpt, endsWith('...'));
      expect(
        redactSecrets(excerpt),
        'FormatException: Unexpected end of input\n'
        '{"access_token":"[redacted]"',
      );
      expect(
        redactSecrets('header eyJhbGciOiJIUzI1NiJ9.eyJ0eXAiOj only'),
        'header [redacted] only',
      );
      expect(
        redactSecrets('{"password":"hunter2\nnext line'),
        '{"password":"[redacted]"\nnext line',
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

    test("redacts a link share's hash in an auth answer", () {
      expect(
        redactSecrets('{"id":83,"hash":"abc","project_id":5}'),
        '{"id":83,"hash":"[redacted]","project_id":5}',
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
          'vikunja-io.vikunja.app://oauth/callback'
          '?code=Zm9vYmFy&state=c3RhdGU',
        ),
        'vikunja-io.vikunja.app://oauth/callback'
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

    test('redacts Cloudflare Access service-token headers, whose id is too '
        'short for the long-run rule', () {
      const id = '0123456789abcdef0123456789abcdef.access';
      for (final (text, expected) in [
        ('CF-Access-Client-Id: $id', 'CF-Access-Client-Id: [redacted]'),
        (
          'cf-access-client-secret=fedcba98 next',
          'cf-access-client-secret=[redacted] next',
        ),
        (
          '{"CF-Access-Client-Id": "$id", "x": 1}',
          '{"CF-Access-Client-Id": [redacted], "x": 1}',
        ),
        ('{cf-access-token: abc.def}', '{cf-access-token: [redacted]}'),
      ]) {
        expect(redactSecrets(text), expected);
      }
    });

    test('redacts e-mail addresses but keeps the host of a URL with user '
        'info', () {
      expect(
        redactSecrets('no account for marker.user+x@mail.example.com.'),
        'no account for [redacted].',
      );
      expect(
        redactSecrets('{"email":"a@b.example","id":1}'),
        '{"email":"[redacted]","id":1}',
      );
      expect(
        redactSecrets('POST /register?email=a%40b.example&x=1'),
        'POST /register?email=[redacted]&x=1',
      );
      expect(
        redactSecrets('Account(4, alice@vikunja.example.com)'),
        'Account(4, [redacted])',
      );
      expect(
        redactSecrets('failed for https://bob@example.com/api'),
        'failed for https://[redacted]@example.com/api',
      );
    });

    test('redacts invite tokens and share hashes in link fragments', () {
      const invite = 'Ab3.d_e~F';
      final hash = 'aB3dE' * 8;
      final texts = {
        'open https://example.com/register#invite-link=$invite now':
            'open https://example.com/register#invite-link=[redacted] now',
        'https://example.com/share/x#share-auth-token=$hash&view=2':
            'https://example.com/share/x#share-auth-token=[redacted]',
        'pasted invite-link=$invite': 'pasted invite-link=[redacted]',
        'share-auth-token=short': 'share-auth-token=[redacted]',
        'https://example.com/tasks/4#comment-12 and Task #4':
            'https://example.com/tasks/4#[redacted] and Task #4',
      };
      for (final MapEntry(key: text, value: expected) in texts.entries) {
        expect(redactSecrets(text), expected, reason: text);
      }
    });

    test('redacts the widget-link key and a payload key', () {
      expect(
        redactSecrets(
          'vikunja-io.vikunja.app://widget/open?account=a1&k=c2hvcnQ',
        ),
        'vikunja-io.vikunja.app://widget/open?account=a1&k=[redacted]',
      );
      expect(
        redactSecrets('{"account":"a1","task":3,"k":"c2hvcnQ"}'),
        '{"account":"a1","task":3,"k":"[redacted]"}',
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
