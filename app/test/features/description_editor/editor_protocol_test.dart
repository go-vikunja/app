import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

Map<String, Object?> payloadOf(String script) {
  const prefix = 'window.rurana.receive(';
  expect(script, startsWith(prefix));
  expect(script, endsWith(')'));
  return jsonDecode(script.substring(prefix.length, script.length - 1))
      as Map<String, Object?>;
}

void main() {
  const token = 'secret-token';
  const theme = EditorTheme(
    dark: true,
    colors: {'text': '#ffffff', 'background': '#000000'},
    fontScale: 2,
  );

  group('messages to the page', () {
    test('init carries the token, the document, theme, texts, language and '
        'links', () {
      final payload = payloadOf(
        EditorMessages.init(
          const EditorInit(
            html: '<p>Hi "there" </p>',
            theme: theme,
            placeholder: 'Beschreibung schreiben …',
            label: 'Beschreibung',
            imageLabel: 'Bild (beim Bearbeiten nicht sichtbar)',
            locale: 'de',
            links: EditorLinks(
              taskLinkBases: ['https://tasks.example.org/'],
              apiRoot: 'https://tasks.example.org',
            ),
          ),
          token: token,
        ),
      );

      expect(payload, {
        'type': 'init',
        'token': token,
        'html': '<p>Hi "there" </p>',
        'readOnly': false,
        'theme': {
          'dark': true,
          'colors': {'text': '#ffffff', 'background': '#000000'},
          'fontScale': 2.0,
        },
        'l10n': {
          'placeholder': 'Beschreibung schreiben …',
          'label': 'Beschreibung',
          'image': 'Bild (beim Bearbeiten nicht sichtbar)',
          'locale': 'de',
        },
        'links': {
          'taskLinkBases': ['https://tasks.example.org/'],
          'apiRoot': 'https://tasks.example.org',
        },
      });
    });

    test('commands carry their name and arguments', () {
      expect(
        payloadOf(
          EditorMessages.command(EditorCommand.heading(2), token: token),
        ),
        {
          'type': 'command',
          'token': token,
          'name': 'heading',
          'args': {'level': 2},
        },
      );
      expect(
        payloadOf(
          EditorMessages.command(
            EditorCommand.insertTable(rows: 3, cols: 4),
            token: token,
          ),
        )['args'],
        {'rows': 3, 'cols': 4},
      );
      expect(
        payloadOf(
          EditorMessages.command(
            EditorCommand.setLink('https://example.org'),
            token: token,
          ),
        )['args'],
        {'href': 'https://example.org'},
      );
      expect(
        payloadOf(
          EditorMessages.command(
            const EditorCommand(EditorCommandName.bold),
            token: token,
          ),
        ),
        {
          'type': 'command',
          'token': token,
          'name': 'bold',
          'args': <String, Object?>{},
        },
      );
    });

    test('a mention stores the username as its id', () {
      expect(
        payloadOf(
          EditorMessages.insertMention(
            const EditorMention(username: 'jdoe', label: 'Jane Doe'),
            token: token,
          ),
        ),
        {
          'type': 'insertMention',
          'token': token,
          'id': 'jdoe',
          'username': 'jdoe',
          'label': 'Jane Doe',
        },
      );
    });

    test('setReadOnly', () {
      expect(
        payloadOf(EditorMessages.setReadOnly(readOnly: true, token: token)),
        {'type': 'setReadOnly', 'token': token, 'readOnly': true},
      );
    });

    test('getHtml, setTheme and focus', () {
      expect(payloadOf(EditorMessages.getHtml(7, token: token)), {
        'type': 'getHtml',
        'token': token,
        'requestId': 7,
      });
      expect(
        payloadOf(EditorMessages.setTheme(theme, token: token))['theme'],
        theme.toJson(),
      );
      expect(payloadOf(EditorMessages.focus(token: token)), {
        'type': 'focus',
        'token': token,
      });
    });
  });

  group('messages from the page', () {
    EditorEvent? decode(Map<String, Object?> message, {String? expected}) =>
        decodeEditorMessage(jsonEncode(message), token: expected);

    test('before init only ready counts, without a token', () {
      expect(decode({'type': 'ready'}), isA<EditorReady>());
      expect(decode({'type': 'state', 'dirty': true}), isNull);
      expect(decode({'type': 'html', 'requestId': 1, 'html': ''}), isNull);
    });

    test('after init a message without the token, or with another, is '
        'dropped', () {
      expect(decode({'type': 'ready'}, expected: token), isNull);
      expect(decode({'type': 'mentionEnd'}, expected: token), isNull);
      expect(
        decode({'type': 'mentionEnd', 'token': 'other'}, expected: token),
        isNull,
      );
      expect(
        decode({'type': 'mentionEnd', 'token': token}, expected: token),
        isA<MentionEnd>(),
      );
    });

    test('state with its active marks and blocks', () {
      final event = decode({
        'type': 'state',
        'token': token,
        'dirty': true,
        'canUndo': true,
        'canRedo': false,
        'active': {
          'bold': true,
          'heading': 2,
          'taskList': true,
          'link': true,
          'linkHref': 'https://example.org/a',
          'table': true,
        },
      }, expected: token);

      final state = (event! as EditorStateChanged).state;
      expect(state.dirty, isTrue);
      expect(state.canUndo, isTrue);
      expect(state.canRedo, isFalse);
      expect(state.active.bold, isTrue);
      expect(state.active.italic, isFalse);
      expect(state.active.heading, 2);
      expect(state.active.taskList, isTrue);
      expect(state.active.link, isTrue);
      expect(state.active.linkHref, 'https://example.org/a');
      expect(state.active.table, isTrue);
      expect(
        (decode({
                  'type': 'state',
                  'token': token,
                  'active': {'link': false, 'linkHref': null},
                }, expected: token)!
                as EditorStateChanged)
            .state
            .active
            .linkHref,
        isNull,
      );
    });

    test('a heading beyond the toolbar keeps its level', () {
      final event = decode({
        'type': 'state',
        'token': token,
        'active': {'heading': 5},
      }, expected: token);

      expect((event! as EditorStateChanged).state.active.heading, 5);
    });

    test('mentions, html answers and failures', () {
      expect(
        (decode({
                  'type': 'mentionQuery',
                  'token': token,
                  'query': 'ja',
                  'caret': {'x': 1, 'y': 2, 'height': 3},
                }, expected: token)!
                as MentionQuery)
            .query,
        'ja',
      );
      final html =
          decode({
                'type': 'html',
                'token': token,
                'requestId': 3,
                'html': '<p></p>',
                'dirty': true,
              }, expected: token)!
              as EditorHtml;
      expect(
        (html.requestId, html.document.html, html.document.dirty),
        (3, '<p></p>', true),
      );
      final clean =
          decode({
                'type': 'html',
                'token': token,
                'requestId': 4,
                'html': '<p>a</p>',
              }, expected: token)!
              as EditorHtml;
      expect(clean.document.dirty, isFalse);
      expect(
        decode({
          'type': 'error',
          'token': token,
          'message': 'init failed',
        }, expected: token),
        isA<EditorFailed>(),
      );
    });

    test('anything else is ignored', () {
      expect(decodeEditorMessage('not json', token: token), isNull);
      expect(decodeEditorMessage('[1, 2]', token: token), isNull);
      expect(
        decode({'type': 'navigate', 'token': token}, expected: token),
        isNull,
      );
      expect(decode({'type': 'html', 'token': token}, expected: token), isNull);
      expect(
        decode({
          'type': 'linkRequest',
          'token': token,
          'href': 'https://example.org',
        }, expected: token),
        isNull,
      );
    });
  });

  group('saving', () {
    test('an empty document for a description never written is no change', () {
      expect(unchangedDescription('', '<p></p>'), isTrue);
      expect(unchangedDescription('<p>a</p>', '<p>a</p>'), isTrue);
      expect(unchangedDescription('<p>a</p>', '<p></p>'), isFalse);
      expect(unchangedDescription('', '<p>a</p>'), isFalse);
    });

    test("the links name the account's bases and the public URL as the "
        'API root', () {
      final links = editorLinksOf(
        AccountLinkBases(
          serverRoot: Uri.parse('https://api.example.org/vikunja/'),
          frontendUrl: Uri.parse('https://tasks.example.org/'),
        ),
      );
      expect(links.taskLinkBases, [
        'https://api.example.org/vikunja/',
        'https://tasks.example.org/',
      ]);
      expect(links.apiRoot, 'https://tasks.example.org');

      final withoutFrontend = editorLinksOf(
        AccountLinkBases(serverRoot: Uri.parse('https://api.example.org/v/')),
      );
      expect(withoutFrontend.apiRoot, 'https://api.example.org/v');
      expect(editorLinksOf(null).apiRoot, '');
    });
  });
}
