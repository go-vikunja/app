import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

typedef _Vector = ({
  String id,
  String text,
  List<MentionSpan> mentions,
  QuotedComment? reply,
  String html,
});

List<_Vector> _vectors() {
  final json = jsonDecode(
    File('test/fixtures/comment_html_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return [
    for (final vector
        in (json['vectors']! as List<Object?>).cast<Map<String, Object?>>())
      (
        id: vector['id']! as String,
        text: vector['text']! as String,
        mentions: [
          for (final span
              in ((vector['mentions'] as List<Object?>?) ?? const [])
                  .cast<Map<String, Object?>>())
            MentionSpan(
              start: span['start']! as int,
              end: span['end']! as int,
              username: span['username']! as String,
              label: span['label']! as String,
            ),
        ],
        reply: switch (vector['reply']) {
          {'id': final int id, 'html': final String html} => QuotedComment(
            id: id,
            html: html,
          ),
          _ => null,
        },
        html: vector['html']! as String,
      ),
  ];
}

const _olderQuote = '<blockquote data-comment-id="3"><p>older</p></blockquote>';
const _taskUrl = 'https://vikunja.example.com/tasks/4';

void main() {
  group('commentHtmlFromText', () {
    for (final vector in _vectors()) {
      test(vector.id, () {
        expect(
          commentHtmlFromText(
            vector.text,
            mentions: vector.mentions,
            reply: vector.reply,
          ),
          vector.html,
        );
      });
    }
  });

  test('a quote nested thousands of elements deep', () {
    const depth = 5000;
    final html = [
      '<div>' * depth,
      '<mention-user data-id="a" data-label="Ann"></mention-user>',
      '</div>' * depth,
    ].join();

    final quoted = commentHtmlFromText(
      '',
      reply: QuotedComment(id: 1, html: html),
    );

    expect(quoted, contains('@Ann'));
    expect(quoted, isNot(contains('mention-user')));
  });

  group('quotedTextOf', () {
    for (final (name, html, text) in const [
      ('empty', '', ''),
      ("the editor's empty document", '<p></p>', ''),
      (
        'mentions as @label',
        '<p>hi <mention-user data-id="jdoe" data-label="Jane Doe" '
            'data-mention-suggestion-char="@"></mention-user> !</p>',
        'hi @Jane Doe !',
      ),
      (
        'a mention without label as @username, leading @ of a label once',
        '<p><mention-user data-id="jdoe"></mention-user> '
            '<mention-user data-id="b" data-label="@@Bob"></mention-user></p>',
        '@jdoe @Bob',
      ),
      ('its own reply quotes left out', '$_olderQuote<p>mine</p>', 'mine'),
      ('unless there is nothing else', '$_olderQuote<p></p>', 'older'),
      (
        'other quotes kept',
        '<blockquote><p>cited</p></blockquote><p>x</p>',
        'cited x',
      ),
      (
        'blocks, list items and breaks on one line',
        '<h2>Title</h2><p>a<br>b</p><ul><li><p>c</p></li><li><p>d</p></li>'
            '</ul><ol><li><p>e</p></li></ol><pre><code>f\n  g</code></pre>',
        'Title a b c d e f g',
      ),
      (
        'task items and table cells',
        '<ul data-type="taskList"><li data-checked="true" '
            'data-type="taskItem"><label><input type="checkbox" '
            'checked="checked"><span></span></label><div><p>done</p></div>'
            '</li></ul><table><tbody><tr><td><p>c1</p></td><td><p>c2</p>'
            '</td></tr></tbody></table>',
        'done c1 c2',
      ),
      (
        'images and rules left out',
        '<p>a</p><img src="https://example.com/x.png" alt="pic"><hr><p>b</p>',
        'a b',
      ),
      (
        'links as their text',
        '<p><a href="https://example.com">site</a> '
            '<a href="$_taskUrl">$_taskUrl</a></p>',
        'site $_taskUrl',
      ),
      (
        'what the schema drops is gone',
        '<p>x</p><script>alert(1)</script><style>p{}</style>',
        'x',
      ),
      (
        "other clients' plain text",
        'line one\nline   two ',
        'line one line two',
      ),
    ]) {
      test(name, () => expect(quotedTextOf(html), text));
    }
  });
}
