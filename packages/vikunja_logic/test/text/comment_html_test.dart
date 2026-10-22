import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  group('the end of a web address', () {
    // The trimming before it was made linear.
    String trimmed(String address) {
      final punctuation = RegExp(r'''[.,;:!?'"]+$''');
      var trimmed = address.replaceFirst(punctuation, '');
      while (trimmed.endsWith(')') &&
          ')'.allMatches(trimmed).length > '('.allMatches(trimmed).length) {
        trimmed = trimmed
            .substring(0, trimmed.length - 1)
            .replaceFirst(punctuation, '');
      }
      return trimmed;
    }

    final link = RegExp('href="([^"]*)"');

    test('leaves punctuation and unopened brackets to the sentence', () {
      const tails = "a.,;:!?')(/";
      final random = Random(3);
      for (var i = 0; i < 5000; i++) {
        final address = [
          'https://a.example/x',
          for (var j = random.nextInt(12); j > 0; j--)
            tails[random.nextInt(tails.length)],
        ].join();

        final html = commentHtmlFromText('see $address now');

        expect(link.firstMatch(html)![1], trimmed(address), reason: address);
      }
    });

    test('is found in linear time', () {
      for (final address in [
        'https://example.com/${')' * 40000}',
        'https://example.com/${'.' * 40000}a',
        'https://example.com/${'(' * 20000}${')' * 40000}',
      ]) {
        final watch = Stopwatch()..start();

        commentHtmlFromText(address);

        expect(watch.elapsedMilliseconds, lessThan(500));
      }
    });
  });

  test('a quote nested thousands of elements deep', () {
    String quote(int depth) => commentHtmlFromText(
      '',
      reply: QuotedComment(
        id: 1,
        html: [
          '<div>' * depth,
          '<mention-user data-id="a" data-label="Ann"></mention-user>',
          '</div>' * depth,
        ].join(),
      ),
    );

    expect(quote(100), contains('@Ann'));
    expect(quote(5000), contains('…'));
    expect(quote(5000), isNot(contains('mention-user')));
  });

  test('a plain-text quote cut short keeps its paragraph and breaks', () {
    final quoted = commentHtmlFromText(
      '',
      reply: QuotedComment(id: 1, html: 'a\nb${'<span>x' * 1100}'),
    );

    expect(quoted, startsWith('<blockquote data-comment-id="1"><p>a<br>b'));
    expect(quoted, endsWith('</p><p>…</p></blockquote><p></p>'));
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
