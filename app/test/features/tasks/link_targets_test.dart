import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
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

  group("a task's web address", () {
    final httpFrontend = AccountLinkBases(
      serverRoot: Uri.parse('https://tasks.example.org/vikunja'),
      frontendUrl: Uri.parse('http://tasks.example.org:8080/'),
    );

    test('is on the server root without a frontend, at a comment with its '
        'fragment', () {
      expect(
        server.taskLink(4),
        uri('https://tasks.example.org/vikunja/tasks/4'),
      );
      expect(
        server.taskLink(4, commentId: 1),
        uri('https://tasks.example.org/vikunja/tasks/4#comment-1'),
      );
    });

    test('is on an https frontend', () {
      expect(
        withFrontend.taskLink(9),
        uri('https://app.example.org/web/tasks/9'),
      );
      expect(
        withFrontend.taskLink(9, commentId: 3),
        uri('https://app.example.org/web/tasks/9#comment-3'),
      );
    });

    test('is on the server root when the frontend is http and the server '
        'https', () {
      expect(
        httpFrontend.taskLink(4),
        uri('https://tasks.example.org/vikunja/tasks/4'),
      );
    });

    test('leads back to its task', () {
      for (final bases in [server, withFrontend, httpFrontend]) {
        for (final link in [
          bases.taskLink(42),
          bases.taskLink(42, commentId: 7),
        ]) {
          expect(
            parseTaskIdFromUrl(link.toString(), bases: bases.taskLinkBases),
            42,
            reason: '$link',
          );
          expect(bases.pastedTaskLinkId(link.toString()), 42, reason: '$link');
        }
      }
    });
  });

  group('a pasted link names a task', () {
    for (final (text, bases, id) in [
      ('https://tasks.example.org/vikunja/tasks/12', server, 12),
      ('  https://tasks.example.org/vikunja/tasks/12\n', server, 12),
      (
        'https://tasks.example.org/vikunja/tasks/12?view=3#comment-5',
        server,
        12,
      ),
      ('https://app.example.org/web/tasks/9', withFrontend, 9),
      ('https://api.example.org/tasks/9#comment-1', withFrontend, 9),
    ]) {
      test(text, () {
        expect(bases.pastedTaskLinkId(text), id);
      });
    }
  });

  group('a pasted text names no task', () {
    // Without a path prefix, the web's parser takes these relative texts
    // as task links of the server.
    final noPrefix = AccountLinkBases(
      serverRoot: Uri.parse('https://vikunja.example.com'),
    );
    for (final (text, bases) in [
      ('/tasks/12', noPrefix),
      ('tasks/12', noPrefix),
      ('/vikunja/tasks/12', server),
      ('vikunja.example.com/tasks/12', noPrefix),
      ('https://evil.example.org/vikunja/tasks/12', server),
      ('https://tasks.example.org/vikunja/tasks/12/edit', server),
      ('/tasks/12/edit', noPrefix),
      ('https://tasks.example.org/vikunja/projects/3', server),
      ('Quarterly report', server),
      ('#12', server),
      ('', server),
    ]) {
      test(text.isEmpty ? '(empty)' : text, () {
        expect(bases.pastedTaskLinkId(text), isNull);
      });
    }
  });
}
