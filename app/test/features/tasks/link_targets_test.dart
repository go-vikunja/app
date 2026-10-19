import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

import '../../helpers/server_connections.dart';

void main() {
  final server = AccountLinkBases(
    serverRoot: Uri.parse('https://tasks.example.org/vikunja'),
  );
  final withFrontend = AccountLinkBases(
    serverRoot: Uri.parse('https://api.example.org'),
    frontendUrl: Uri.parse('https://app.example.org/web/'),
  );

  Uri uri(String text) => Uri.parse(text);

  group('a task of the account opens in the app', () {
    for (final (href, bases, id) in [
      ('https://tasks.example.org/vikunja/tasks/12', server, 12),
      ('HTTPS://TASKS.example.org:443/vikunja/tasks/12', server, 12),
      ('https://tasks.example.org/vikunja/tasks/12#comment-3', server, 12),
      ('/vikunja/tasks/7', server, 7),
      ('tasks/7', server, 7),
      ('https://app.example.org/web/tasks/9', withFrontend, 9),
      ('https://api.example.org/tasks/9', withFrontend, 9),
      (' https://tasks.example.org/vikunja/tasks/4\n', server, 4),
    ]) {
      test(href, () {
        expect(linkTargetOf(href, bases), TaskLinkTarget(id));
      });
    }
  });

  group('a web page opens in the browser', () {
    for (final (href, bases, expected) in [
      ('https://example.com/docs', server, 'https://example.com/docs'),
      ('http://example.com', server, 'http://example.com'),
      (
        'https://tasks.example.org/vikunja/tasks/12/edit',
        server,
        'https://tasks.example.org/vikunja/tasks/12/edit',
      ),
      (
        'https://evil.example.org/vikunja/tasks/12',
        server,
        'https://evil.example.org/vikunja/tasks/12',
      ),
      // Relative and schemeless links are resolved where the web shows
      // them: the frontend, else the server.
      ('/projects/3', server, 'https://tasks.example.org/projects/3'),
      ('projects/3', withFrontend, 'https://app.example.org/web/projects/3'),
      (
        'www.example.com',
        server,
        'https://tasks.example.org/vikunja/www.example.com',
      ),
      ('//cdn.example.com/a', server, 'https://cdn.example.com/a'),
    ]) {
      test(href, () {
        expect(linkTargetOf(href, bases), ExternalLinkTarget(uri(expected)));
      });
    }
  });

  group('the other allowed schemes go to the system', () {
    for (final href in [
      'mailto:anna@example.com',
      'tel:+4930123456',
      'sms:+4930123456',
      'xmpp:anna@example.com',
      'obsidian://open?vault=notes',
      'ftp://files.example.com/a.txt',
    ]) {
      test(href, () {
        expect(linkTargetOf(href, server), ExternalLinkTarget(uri(href)));
      });
    }
  });

  group('anything else is never opened', () {
    for (final href in [
      '',
      '   ',
      'javascript:alert(1)',
      'JaVaScRiPt:alert(1)',
      'java\tscript:alert(1)',
      'data:text/html,<b>x</b>',
      'vbscript:msgbox',
      'file:///etc/passwd',
      'intent://scan#Intent;scheme=zxing;end',
      'slack://open',
    ]) {
      test(href, () {
        expect(linkTargetOf(href, server), isNull);
      });
    }
  });

  test('the bases of a connection take only an http(s) frontend', () {
    final connection = fullServer270();
    expect(
      AccountLinkBases.of(connection),
      AccountLinkBases(serverRoot: connection.rootUri),
    );
    expect(server.relativeBase, uri('https://tasks.example.org/vikunja/'));
    expect(withFrontend.relativeBase, uri('https://app.example.org/web/'));
    expect(withFrontend.taskLinkBases, [
      uri('https://api.example.org'),
      uri('https://app.example.org/web/'),
    ]);
  });
}
