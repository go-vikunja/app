import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

final String _hash = 'a1' * 20;

void main() {
  group('linkShareUrl', () {
    test('the web route under the base, with the view when given', () {
      final base = Uri.parse('https://tasks.example.com/');

      expect(
        linkShareUrl(base: base, hash: _hash).toString(),
        'https://tasks.example.com/share/$_hash/auth',
      );
      expect(
        linkShareUrl(base: base, hash: _hash, viewId: 42).toString(),
        'https://tasks.example.com/share/$_hash/auth?view=42',
      );
    });

    test('a base with a path prefix keeps it, with or without a slash', () {
      for (final base in [
        'https://example.com/vikunja',
        'https://example.com/vikunja/',
      ]) {
        expect(
          linkShareUrl(base: Uri.parse(base), hash: _hash).toString(),
          'https://example.com/vikunja/share/$_hash/auth',
        );
      }
    });

    test("the base's own query and fragment are dropped, its port kept", () {
      expect(
        linkShareUrl(
          base: Uri.parse('http://localhost:34527/app?x=1#top'),
          hash: _hash,
          viewId: 3,
        ).toString(),
        'http://localhost:34527/app/share/$_hash/auth?view=3',
      );
    });

    test('a hash is escaped like a path segment', () {
      expect(
        linkShareUrl(base: Uri.parse('https://e.com/'), hash: 'a/b c').path,
        '/share/a%2Fb%20c/auth',
      );
    });
  });

  group('webFrontendBase', () {
    final https = Uri.parse('https://tasks.example.com');
    final http = Uri.parse('http://192.168.1.5:3456');

    test('the frontend the server names, as a directory', () {
      expect(
        webFrontendBase(
          serverRoot: https,
          frontendUrl: Uri.parse('https://web.example.com/app'),
        ).toString(),
        'https://web.example.com/app/',
      );
      expect(
        webFrontendBase(
          serverRoot: http,
          frontendUrl: Uri.parse('http://192.168.1.5:8080/'),
        ).toString(),
        'http://192.168.1.5:8080/',
      );
    });

    test('the server root without a usable frontend', () {
      expect(webFrontendBase(serverRoot: https).toString(), '$https/');
      expect(
        webFrontendBase(
          serverRoot: https,
          frontendUrl: Uri.parse('vikunja://x'),
        ).toString(),
        '$https/',
      );
      expect(
        webFrontendBase(
          serverRoot: http,
          frontendUrl: Uri.parse('/relative'),
        ).toString(),
        '$http/',
      );
    });

    test('never an http frontend for an https server', () {
      expect(
        webFrontendBase(
          serverRoot: https,
          frontendUrl: Uri.parse('http://tasks.example.com/'),
        ).toString(),
        '$https/',
      );
    });
  });
}
