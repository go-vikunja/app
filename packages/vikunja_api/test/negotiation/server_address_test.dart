import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('normalizeServerAddress', () {
    group('vectors from frontend/src/helpers/apiUrl.test.ts', () {
      for (final (input, root) in [
        ('https://x', 'https://x'),
        ('https://x/', 'https://x'),
        ('https://x/prefix', 'https://x/prefix'),
        ('https://x/prefix/', 'https://x/prefix'),
        ('https://x/api/v1', 'https://x'),
        ('https://x/api/v2', 'https://x'),
        ('https://x/prefix/api/v1/', 'https://x/prefix'),
      ]) {
        test('$input -> $root', () {
          expect(normalizeServerAddress(input).root.toString(), root);
        });
      }

      for (final relative in ['', '/', '/prefix/api/v2']) {
        test('rejects the same-origin form "$relative" a native app lacks', () {
          expect(
            () => normalizeServerAddress(relative),
            throwsA(isA<InvalidServerAddress>()),
          );
        });
      }
    });

    group('vectors from frontend/src/helpers/checkAndSetApiUrl.test.ts', () {
      for (final (input, root) in [
        ('https://new.example.com', 'https://new.example.com'),
        ('https://new.example.com/root/api/v1', 'https://new.example.com/root'),
        (
          'https://new.example.com/root/api/v2/',
          'https://new.example.com/root',
        ),
        ('https://new.example.com/root/', 'https://new.example.com/root'),
        ('https://old.example.com/api/v1', 'https://old.example.com'),
        ('https://old.example.com/', 'https://old.example.com'),
      ]) {
        test('$input -> $root', () {
          expect(normalizeServerAddress(input).root.toString(), root);
        });
      }
    });

    group('accepts', () {
      for (final (input, root, explicitScheme, explicitPort) in [
        ('example.com', 'https://example.com', false, false),
        ('example.com:3456', 'https://example.com:3456', false, true),
        ('example.com/api/v1/', 'https://example.com', false, false),
        ('example.com/vikunja', 'https://example.com/vikunja', false, false),
        ('http://example.com', 'http://example.com', true, false),
        (
          'HTTPS://Vikunja.Example.COM/Sub',
          'https://vikunja.example.com/Sub',
          true,
          false,
        ),
        ('  https://example.com  ', 'https://example.com', true, false),
        ('https://example.com/a?b=c#d', 'https://example.com/a', true, false),
        ('https://example.com/api/v1/?x=1', 'https://example.com', true, false),
        (
          'https://example.com/api/v1/api/v2',
          'https://example.com/api/v1',
          true,
          false,
        ),
        (
          'https://example.com/my%20vikunja',
          'https://example.com/my%20vikunja',
          true,
          false,
        ),
        ('192.168.1.10:3456', 'https://192.168.1.10:3456', false, true),
        ('http://192.168.1.10:3456/', 'http://192.168.1.10:3456', true, true),
        ('localhost:34527', 'https://localhost:34527', false, true),
        ('https://[::1]:3456', 'https://[::1]:3456', true, true),
        ('[::1]', 'https://[::1]', false, false),
        (
          '[2001:DB8::1]:8080/vikunja',
          'https://[2001:db8::1]:8080/vikunja',
          false,
          true,
        ),
        ('https://example.com:443', 'https://example.com', true, true),
        ('http://example.com:80/api/v2', 'http://example.com', true, true),
        ('https.example.com', 'https://https.example.com', false, false),
        ('httpserver/x', 'https://httpserver/x', false, false),
      ]) {
        test(input, () {
          final address = normalizeServerAddress(input);
          expect(address.root.toString(), root);
          expect(address.hasExplicitScheme, explicitScheme);
          expect(address.hasExplicitPort, explicitPort);
        });
      }

      test('keeps the explicit port number for an http fallback', () {
        final address = normalizeServerAddress('example.com:443');
        expect(address.root.port, 443);
        expect(address.hasExplicitPort, isTrue);
      });

      test('produces a root without query, fragment or trailing slash', () {
        final root = normalizeServerAddress('https://x.org/a/?q#f').root;
        expect(root.hasQuery, isFalse);
        expect(root.hasFragment, isFalse);
        expect(root.path, '/a');
      });
    });

    group('cuts the path at the last /api/v1 or /api/v2', () {
      for (final (input, root) in [
        ('https://example.com/api/v1/info', 'https://example.com'),
        ('https://example.com/api/v2/info/', 'https://example.com'),
        ('https://example.com/API/V1', 'https://example.com'),
        (
          'https://example.com/vikunja/api/v2/tasks/3',
          'https://example.com/vikunja',
        ),
        ('https://example.com/api/v10', 'https://example.com/api/v10'),
        ('https://example.com/apis/v1', 'https://example.com/apis/v1'),
        ('https://example.com/login', 'https://example.com/login'),
      ]) {
        test('$input -> $root', () {
          expect(normalizeServerAddress(input).root.toString(), root);
        });
      }
    });

    group('international host names become punycode', () {
      for (final (input, root) in [
        ('bücher.example', 'https://xn--bcher-kva.example'),
        ('https://BÜCHER.example', 'https://xn--bcher-kva.example'),
        ('https://münchen.de', 'https://xn--mnchen-3ya.de'),
        (
          'vikunja.münchen.de:3456/todo',
          'https://vikunja.xn--mnchen-3ya.de:3456/todo',
        ),
        ('http://日本語.jp', 'http://xn--wgv71a119e.jp'),
      ]) {
        test('$input -> $root', () {
          expect(normalizeServerAddress(input).root.toString(), root);
        });
      }

      for (final input in ['bücher..example', 'https://${'a' * 70}ü.example']) {
        test('rejects "$input"', () {
          expect(
            () => normalizeServerAddress(input),
            throwsA(isA<InvalidServerAddress>()),
          );
        });
      }
    });

    test('a host alone becomes punycode the same way, an ASCII one stays '
        'as it is', () {
      expect(
        punycodeHost('Aufgaben.MÜLLER.example'),
        'aufgaben.xn--mller-kva.example',
      );
      expect(punycodeHost('Tasks.Example.org.'), 'Tasks.Example.org.');
      expect(punycodeHost('bücher..example'), isNull);
      expect(punycodeHost('${'a' * 70}ü.example'), isNull);
    });

    group('drops invisible characters from copy and paste', () {
      for (final input in [
        'https://example.com\u200B',
        'https://example.com\u00AD',
        '\u200Bhttps://example.com',
        ' \u2060https://exam\u00ADple.com/\u200D ',
      ]) {
        test(input.runes.map((r) => r.toRadixString(16)).join(' '), () {
          expect(
            normalizeServerAddress(input).root.toString(),
            'https://example.com',
          );
        });
      }
    });

    group('rejects', () {
      for (final input in [
        '',
        '   ',
        'https://exa mple.com',
        'example.com/my vikunja',
        'user:pass@example.com',
        'https://user:pass@example.com',
        'https://user@example.com',
        'https://@example.com',
        'mailto:me@example.com',
        'ftp://example.com',
        'file:///etc/passwd',
        'ws://example.com',
        'javascript:alert(1)',
        'http:example.com',
        'https:/example.com',
        'https//example.com',
        'HTTP//example.com',
        'https/example.com',
        'https://',
        'https:///vikunja',
        'https://:3456',
        'https://example.com:99999',
        'https://example.com:0',
        'https://example.com:abc',
        'example.com:',
        '::1',
        '/vikunja',
        '//example.com',
      ]) {
        test('"$input"', () {
          expect(
            () => normalizeServerAddress(input),
            throwsA(
              isA<InvalidServerAddress>()
                  .having((f) => f.input, 'input', input)
                  .having((f) => f.uri, 'uri', isNull),
            ),
          );
        });
      }
    });
  });
}
