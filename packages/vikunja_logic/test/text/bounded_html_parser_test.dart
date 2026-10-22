// HTML fixtures are concatenated without whitespace on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:vikunja_logic/src/text/bounded_html_parser.dart';

({dom.Document document, bool complete}) _parse(String html) =>
    parseBoundedHtml('<body>$html</body>');

bool _complete(String html) => _parse(html).complete;

void _expectLikePackageHtml(String html, {String? reason}) {
  final (:document, :complete) = _parse(html);
  expect(complete, isTrue, reason: reason);
  expect(
    document.outerHtml,
    html_parser.parse('<body>$html</body>').outerHtml,
    reason: reason,
  );
}

Iterable<String> _fixtureHtml() sync* {
  final oracle = jsonDecode(
    File('test/fixtures/sanitizer_oracle.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final vector in oracle['vectors']! as List<Object?>) {
    final map = vector! as Map<String, Object?>;
    yield map['input']! as String;
    yield map['html']! as String;
  }
  final comments = jsonDecode(
    File('test/fixtures/comment_html_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final vector in comments['vectors']! as List<Object?>) {
    yield (vector! as Map<String, Object?>)['html']! as String;
  }
}

String _mailThread(int replies) {
  var thread = '<div dir="ltr">Original message</div>';
  for (var i = 1; i <= replies; i++) {
    thread = [
      '<div dir="ltr">Reply $i<br><div class="gmail_quote">',
      '<div dir="ltr" class="gmail_attr">On Mon, someone wrote:<br></div>',
      '<blockquote class="gmail_quote" style="margin:0 0 0 .8ex">',
      thread,
      '</blockquote></div></div>',
    ].join();
  }
  return thread;
}

String _editorDocument(int kilobytes) {
  final random = Random(7);
  final html = StringBuffer();
  while (html.length < kilobytes * 1000) {
    switch (random.nextInt(4)) {
      case 0:
        html.write(
          '<p>Some <strong>bold</strong> and <em>italic</em> text '
          '<a target="_blank" rel="noopener noreferrer nofollow" '
          'href="https://example.com/${random.nextInt(1000)}">link</a></p>',
        );
      case 1:
        final depth = 1 + random.nextInt(10);
        html
          ..write('<ul><li><p>item</p>' * depth)
          ..write('</li></ul>' * depth);
      case 2:
        html.write(
          '<ul data-type="taskList"><li data-checked="false" '
          'data-type="taskItem"><label><input type="checkbox"><span></span>'
          '</label><div><p>task</p></div></li></ul>',
        );
      default:
        html.write(
          '<table><tbody><tr><th><p>a</p></th><th><p>b</p></th></tr>'
          '<tr><td><p>1</p></td><td><p>2</p></td></tr></tbody></table>',
        );
    }
  }
  return html.toString();
}

void main() {
  test('parses every recorded description and comment like package:html', () {
    for (final html in _fixtureHtml()) {
      _expectLikePackageHtml(html, reason: html);
    }
  });

  test('parses deep, misnested and large documents of the real world like '
      'package:html', () {
    final lines = [for (var i = 0; i < 12000; i++) 'Line $i<br>'].join();
    final documents = {
      'a mail thread of 60 replies': _mailThread(60),
      'sections with an unclosed bold heading':
          '${'<p><b>Heading</p>Body text<br>' * 130}LAST',
      'lines in unclosed fonts': '${'<font face="Arial">line<br>' * 130}LAST',
      'a font closed before its span':
          '<font face="Arial"><span>$lines</font></span><p>Signature</p>',
      'a link closed in every row of a table':
          '<a href="https://example.com"><table>'
          '${'<tr><td>x</td></a></tr>' * 1200}</table></a><p>after</p>',
      'fonts closed in every cell':
          '<font face="Arial"><table>'
          '${'<tr><td><font color="red">x</td></font></tr>' * 1200}'
          '</table></font><p>after</p>',
      'a bold closed before its span':
          '<b><span>${'line<br>' * 12000}</b></span><p>after</p>',
      'a bold closed inside a block':
          '<b><div><span>${'x<br>' * 12000}</b></span></div><p>after</p>',
      'a link opened in a link around many lines':
          '<a href="x"><div>${'line<br>' * 9000}<a href="y">next</a>',
      'an editor document of 1 MB': _editorDocument(1000),
    };
    for (final MapEntry(key: name, value: html) in documents.entries) {
      _expectLikePackageHtml(html, reason: name);
    }
  });

  group('stops at', () {
    test('the element that would open more than maxOpenElements', () {
      // `<html>` and `<body>` are open as well.
      expect(_complete('${'<div>' * (maxOpenElements - 2)}x'), isTrue);

      final (:document, :complete) = _parse(
        '${'<div>' * (maxOpenElements - 1)}x',
      );
      expect(complete, isFalse);
      expect(document.body!.text, isEmpty);
    });

    test('the token past maxListWalk', () {
      // Each `<br>` under 1,000 `div`s walks about 1,002 open elements.
      const depth = 1000;
      const edge = (maxListWalk - depth * depth ~/ 2) ~/ (depth + 2);
      String deep(int breaks) => '${'<div>' * depth}${'<br>' * breaks}';

      expect(_complete(deep(edge * 9 ~/ 10)), isTrue);
      expect(_complete(deep(edge * 11 ~/ 10)), isFalse);
    });

    test('the element past maxElements', () {
      // `<head>` and `<body>` count as well.
      expect(_complete('<br>' * (maxElements - 2)), isTrue);
      expect(_complete('<br>' * (maxElements - 1)), isFalse);
    });

    test('the copy of a formatting element past maxAttributeText', () {
      // Each paragraph reopens the `b` and copies its 1,005 characters.
      String reopened(int paragraphs) =>
          '<p><b title="${'x' * 1000}">${'</p><p>x' * paragraphs}';
      const edge = maxAttributeText ~/ 1005;

      expect(_complete(reopened(edge * 9 ~/ 10)), isTrue);
      expect(_complete(reopened(edge * 11 ~/ 10)), isFalse);
    });

    test('the adoption agency that would clone past maxAttributeText', () {
      // Each cycle clones the 60,009 characters of the `b` about 120 times.
      final open = '<b style="${'a:b;' * 15000}">';
      final cycle = '${'<div>' * 120}${'</b>' * 15}${'</div>' * 120}x';

      expect(_complete('${open}x${cycle * 2}'), isTrue);
      expect(_complete('${open}x${cycle * 4}'), isFalse);
    });

    // Markup misplaced in a table and the adoption agency both search about
    // (2n)²/2 sibling positions for n lines of text and a break.
    final siblingEdge = sqrt(maxSiblingSearch / 2).floor();

    test('markup misplaced in a table past maxSiblingSearch', () {
      String misplaced(int lines) => '<table>${'x<br>' * lines}</table>';

      expect(_complete(misplaced(siblingEdge * 9 ~/ 10)), isTrue);
      expect(_complete(misplaced(siblingEdge * 11 ~/ 10)), isFalse);
    });

    test('the adoption agency moving children past maxSiblingSearch', () {
      String moved(int lines) => '<b><div>${'x<br>' * lines}</b>after';

      expect(_complete(moved(siblingEdge * 9 ~/ 10)), isTrue);
      final (:document, :complete) = _parse(moved(siblingEdge * 11 ~/ 10));
      expect(complete, isFalse);
      expect(document.body!.text, isNot(contains('after')));
    });

    test('a token, not while the adoption agency moves a node', () {
      // With these lines the search runs out in the agency for `</b>`, after
      // it took the div out of the b and before it puts it before the table.
      String html(String end) => '<table>${'x<br>' * 11584}<b><div>KEPT$end';

      expect(_complete(html('')), isTrue);
      final (:document, :complete) = _parse(html('</b>'));
      expect(complete, isFalse);
      expect(document.body!.text, contains('KEPT'));
    });
  });

  group('numeric character references', () {
    test('past 64 bits are U+FFFD, as below them past U+10FFFF', () {
      for (final html in [
        '&#99999999999999999999;',
        '&#x10000000000000000;',
        '&#x8000000000000000;',
        '&#${'9' * 5000};',
        '&#99999999999999999999',
      ]) {
        final (:document, :complete) = _parse(html);

        expect(complete, isTrue, reason: html);
        expect(document.body!.text, '�', reason: html);
      }
      expect(
        _parse('<a href="&#99999999999999999999;x">y</a>').document
            .querySelector('a')!
            .attributes['href'],
        '�x',
      );
    });

    test('within 64 bits read as package:html reads them', () {
      final random = Random(1);
      for (var i = 0; i < 2000; i++) {
        final hex = random.nextBool();
        final digits = hex ? '0123456789abcdefABCDEF' : '0123456789';
        final number = [
          for (var j = 1 + random.nextInt(19); j > 0; j--)
            digits[random.nextInt(digits.length)],
        ].join();
        if (int.tryParse(number, radix: hex ? 16 : 10) == null) continue;
        final html =
            '<p title="&#${hex ? 'x' : ''}$number">'
            '&#${hex ? 'x' : ''}$number${random.nextBool() ? ';' : ''}z</p>';

        _expectLikePackageHtml(html, reason: html);
      }
    });
  });
}
