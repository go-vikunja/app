import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/src/text/bounded_html_parser.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

final Uri _apiRoot = Uri.parse('https://tasks.example.com');

RichDocument _parse(String html) =>
    parseRichText(html, apiRoot: _apiRoot, taskLinkBases: const []);

final String _checklist = [
  '<ul data-type="taskList"><li data-checked="false" data-type="taskItem">',
  '<label><input type="checkbox"><span></span></label><div><p>Milk</p>',
  '</div></li></ul>',
].join();

final String _tooDeep = '<div>' * maxOpenElements;

/// [unit] repeated to about [kilobytes] of HTML.
String _repeat(String unit, int kilobytes) =>
    unit * (kilobytes * 1000 ~/ unit.length);

/// Each cell leaves the marker of its `object` in the list of active
/// formatting elements.
final String _markers = '<table>${_repeat('<td><object>', 500)}</table>';

/// Formatting elements with [attributes] alike but their last, closed
/// again once 256 are open: each is compared with the 256 before it.
String _formattingAlike(int attributes, int kilobytes) {
  final html = StringBuffer();
  for (var i = 0; html.length < kilobytes * 1000; i++) {
    html.write('<b');
    for (var a = 0; a < attributes; a++) {
      html.write(' a${a.toRadixString(36)}');
    }
    html.write(' z="$i">');
    if (i >= 256) html.write('</b>');
  }
  return html.toString();
}

String _attributes(int kilobytes) {
  final attributes = StringBuffer();
  for (var i = 0; attributes.length < kilobytes * 1000; i++) {
    attributes.write(' a${i.toRadixString(36)}');
  }
  return attributes.toString();
}

void main() {
  test('a document past a limit keeps what came before it and ends with an '
      'ellipsis', () {
    final html = '<p>before</p>$_checklist${_tooDeep}deep<p>after</p>';

    final document = _parse(html);

    expect(document.truncated, isTrue);
    expect(document.plainText, 'before\nMilk\n…');
    final item = document.taskItems.single;
    final toggled = toggleTaskItem(html, item, checked: true)!;
    expect(toggled, contains('data-checked="true"'));
    expect(_parse(toggled).taskItems.single.checked, isTrue);
  });

  test('the ellipsis follows open lists and tables at the top level', () {
    final document = _parse('<ul><li><table><tr><td>$_tooDeep');

    expect(document.blocks.last, isA<RichParagraph>());
    expect(document.plainText, endsWith('…'));
  });

  test('a document within the limits is not truncated', () {
    expect(_parse('<p>a</p>$_checklist').truncated, isFalse);
  });

  test('a reply preview of a truncated comment ends with an ellipsis', () {
    const quote = '<blockquote data-comment-id="5"><p>quoted</p></blockquote>';

    expect(quotedTextOf('$quote<p>own</p>$_tooDeep'), 'own …');
    expect(quotedTextOf('$quote$_tooDeep'), 'quoted …');
    expect(quotedTextOf(_tooDeep), '…');
  });

  test('a number too large for package:html is U+FFFD everywhere', () {
    const html = '<p>&#99999999999999999999;</p>';

    expect(_parse(html).plainText, '�');
    expect(quotedTextOf(html), '�');
    expect(
      commentHtmlFromText('', reply: const QuotedComment(id: 1, html: html)),
      contains('�'),
    );
  });

  group('hostile markup stays fast', () {
    String closingScans(String opening, String repeated) =>
        '$opening${repeated * 60000}${'</q>' * 60000}';

    String cycles(String open) {
      final cycle = '${'<div>' * 120}${'</b>' * 15}${'</div>' * 120}x';
      return '${open}x${_repeat(cycle, 900)}';
    }

    // Each with whether it ends truncated. Times without the limits, on a
    // laptop: nesting 20 s to 110 s, foster parenting 82 s, the adoption
    // agency 65 s, blank TipTap paragraphs 24 s, joined text 9 s, a long
    // attribute reopened minutes; many attributes reopened ran out of
    // memory, and so did quoting a long link reopened.
    final hostile = <String, (bool, String Function())>{
      'divs': (true, () => '${'<div>' * 50000}x${'</div>' * 50000}'),
      'lists': (true, () => '${'<ul><li>' * 20000}x${'</li></ul>' * 20000}'),
      'blockquotes': (true, () => '<blockquote>' * 30000),
      'self-closing divs': (true, () => '${'<div/>' * 50000}x'),
      'dropped elements nested': (true, () => '${'<svg>' * 100000}x'),
      'ruby bases': (true, () => closingScans('', '<rb>')),
      'rows in svg': (true, () => closingScans('<svg>', '<tr>')),
      'cells outside a table': (
        true,
        () => _repeat('<td><dl><b><h3><dt><b>', 900),
      ),
      'CDATA outside foreign content': (
        true,
        () => _repeat(
          '<![CDATA[</a><!--<mi>]]>x<textarea>--><rb><b><dd><h1><u>',
          900,
        ),
      ),
      'math under a closed paragraph': (
        true,
        () => _repeat(
          '<h3><dl><blockquote></p><p><blockquote><blockquote><h3><math><dt>'
          '<div>',
          900,
        ),
      ),
      'list items deep in the stack': (
        true,
        () => '${'<div>' * (maxOpenElements - 8)}${_repeat('<li>', 1000)}',
      ),
      'end tags deep in the stack': (
        true,
        () => '${'<div>' * (maxOpenElements - 8)}${_repeat('</p>', 1000)}',
      ),
      'distinct formatting reopened in paragraphs': (
        true,
        () => [
          '<p>',
          for (var i = 0; i < 120; i++) '<b id="b$i">',
          _repeat('</p><p>x', 900),
        ].join(),
      ),
      'many attributes reopened in paragraphs': (
        true,
        () => '<p><b${_attributes(400)}>${_repeat('</p><p>x', 400)}',
      ),
      'a long style reopened in paragraphs': (
        true,
        () => '<p><b style="${'a:b;' * 125000}">${_repeat('</p><p>x', 500)}',
      ),
      'a long link reopened in paragraphs': (
        true,
        () =>
            '<p><a href="https://example.com/${'a' * 500000}">'
            '${_repeat('</p><p>x', 500)}',
      ),
      'a long style cloned by the adoption agency': (
        true,
        () => cycles('<b style="${'a:b;' * 25000}">'),
      ),
      'attributes compared with many formatting elements': (
        true,
        () => _formattingAlike(20, 1000),
      ),
      'markers left in the formatting list': (
        true,
        () =>
            '$_markers${_repeat('<blockquote><b>${'<ul>' * 8}</b></b>'
            '</blockquote>', 500)}',
      ),
      'links after markers left in the formatting list': (
        true,
        () => '$_markers${_repeat('<a>', 500)}',
      ),
      'text misplaced in a table': (
        true,
        () => '<table>${_repeat('x<br>', 900)}',
      ),
      'misplaced text after many siblings': (
        true,
        () => '${_repeat('<br>', 450)}<table>${_repeat('x<br>', 450)}',
      ),
      'the adoption agency moving many children': (
        true,
        () => '<b><div>${_repeat('x<br>', 900)}</b>',
      ),
      'blank TipTap text between paragraphs': (
        false,
        () => _repeat('<p>x</p>\n', 900),
      ),
      'lists nested in a list': (
        false,
        () => '<ul><li>x</li>${_repeat('<ul></ul>', 900)}',
      ),
      'text split by comments': (false, () => '<p>${_repeat('abc<!>', 900)}'),
      'numbers too large for package:html': (
        false,
        () => _repeat('&#99999999999999999999;', 900),
      ),
    };
    for (final MapEntry(key: name, value: (truncated, build))
        in hostile.entries) {
      test(name, () {
        final html = build();
        final watch = Stopwatch()..start();

        final document = _parse(html);

        expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
        expect(document.truncated, truncated);

        watch.reset();
        commentHtmlFromText('', reply: QuotedComment(id: 1, html: html));

        expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      });
    }
  });
}
