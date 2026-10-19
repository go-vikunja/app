import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/src/text/rich_text_parser.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'rich_text_json.dart';

final Uri _apiRoot = Uri.parse('https://tasks.example.com');
final List<Uri> _bases = [Uri.parse('https://tasks.example.com/')];

// Text placed inside something the parser must drop, or into an attribute
// the tree does not keep: none of it may come out.
const _leak = 'LEAK';

const _schemaTypes = {
  'doc',
  'paragraph',
  'heading',
  'blockquote',
  'bulletList',
  'orderedList',
  'listItem',
  'taskList',
  'taskItem',
  'codeBlock',
  'horizontalRule',
  'table',
  'tableRow',
  'tableHeader',
  'tableCell',
  'image',
  'text',
  'hardBreak',
  'mention',
  'taskLink',
};

const _hrefs = [
  'https://example.com/a?b=c#d',
  'http://example.com',
  'mailto:me@example.com',
  'tel:+491',
  '/projects/1',
  '#frag',
  'www.example.com',
  'https://tasks.example.com/tasks/5',
  '/tasks/7',
  'javascript:alert(1)',
  'JaVaScRiPt:alert(1)',
  '  javascript:alert(1)',
  'java&#x09;script:alert(1)',
  'java&#9;script:alert(1)',
  'jav&#x0A;ascript:alert(1)',
  'java&#13;script:alert(1)',
  '&#106;avascript:alert(1)',
  '&#x6A;&#x61;vascript:alert(1)',
  '&#1;javascript:alert(1)',
  'java&#xA0;script:alert(1)',
  'javascript&colon;alert(1)',
  'data:text/html;base64,PHNjcmlwdD4=',
  'DATA:text/html,x',
  ' data:x',
  'vbscript:msgbox(1)',
  'VbScRiPt:msgbox(1)',
  'file:///etc/passwd',
  'intent://x',
  '',
];

const _imageSources = [
  'https://images.example/cat.png',
  'http://images.example/dog.png',
  'https://tasks.example.com/api/v2/tasks/5/attachments/9',
  '/api/v1/tasks/6/attachments/10',
  'javascript:alert(1)',
  'JAVASCRIPT:alert(1)',
  'data:image/png;base64,AAAA',
  ' data:image/svg+xml,<svg onload=alert(1)>',
  'vbscript:x',
  'x',
  '//tracker.example/p.gif',
  '',
];

const _words = [
  'alpha',
  'beta',
  ' ',
  '  ',
  '\n',
  '\r\n',
  '\t',
  '&nbsp;',
  '&lt;script&gt;',
  '&amp;',
  '👍',
  // A `<` before a letter would open a tag and swallow the markup after it.
  '< ',
  '>',
  'x',
  'https://tasks.example.com/tasks/5',
];

const _cellColours = ['#f00', 'red; background:url(x)', 'rgb(1,2,3)'];

const _blockTags = [
  'p',
  'h1',
  'h3',
  'h6',
  'blockquote',
  'div',
  'section',
  'pre',
  'li',
  'td',
  'th',
  'tr',
  'table',
];

const _inlineTags = [
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'del',
  'strike',
  'sub',
  'sup',
  'code',
  'span',
  'mark',
  'font',
];

// Elements whose content (or attribute) must never show; the first text
// inside each is the leak marker.
const _droppedContainers = [
  'script',
  'style',
  'iframe',
  'object',
  'template',
  'noscript',
  'noembed',
  'noframes',
  'title',
  'textarea',
  'button',
  'video',
  'audio',
  'canvas',
  'svg',
  'math',
  'option',
];

const _droppedVoid = ['embed', 'input', 'meta', 'link', 'base'];

final class _Generator {
  new(int seed) : _random = Random(seed);

  final Random _random;

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

  bool _chance(int percent) => _random.nextInt(100) < percent;

  String _hostileAttributes() => [
    if (_chance(40)) ' onclick="$_leak()"',
    if (_chance(20)) " OnMouseOver='$_leak()'",
    if (_chance(30)) ' style="background:url(javascript:$_leak)"',
    if (_chance(20)) ' id="$_leak"',
    if (_chance(20)) ' class="$_leak"',
    if (_chance(10)) ' data-x="$_leak"',
  ].join();

  String _markStyle() => _pick([
    '',
    ' style="font-weight:bold"',
    ' style="font-weight: 700; font-style: italic"',
    ' style="text-decoration: underline line-through"',
    ' style="vertical-align: sub"',
    ' style="vertical-align:super; font-weight:400"',
    ' style="FONT-STYLE: NORMAL"',
  ]);

  String _text() =>
      List.generate(1 + _random.nextInt(3), (_) => _pick(_words)).join();

  String _close(String tag) => _chance(10) ? '' : '</$tag>';

  String content(int depth) {
    final parts = <String>[];
    final count = 1 + _random.nextInt(depth > 0 ? 4 : 2);
    for (var i = 0; i < count; i++) {
      parts.add(_node(depth));
    }
    return parts.join(_chance(30) ? '\n' : '');
  }

  String _node(int depth) {
    if (depth <= 0) return _text();
    final roll = _random.nextInt(100);
    if (roll < 20) return _text();
    if (roll < 30) {
      final tag = _pick(_droppedContainers);
      if (tag == 'option') {
        return '<select${_hostileAttributes()}><option>$_leak</option></select>';
      }
      final close = _chance(15) ? '' : '</$tag>';
      return '<$tag${_hostileAttributes()}>$_leak${_chance(30) ? _text() : ''}'
          '$close';
    }
    if (roll < 33) return '<${_pick(_droppedVoid)}${_hostileAttributes()}>';
    if (roll < 45) {
      final tag = _pick(_inlineTags);
      return '<$tag${_markStyle()}${_hostileAttributes()}>'
          '${content(depth - 1)}${_close(tag)}';
    }
    if (roll < 55) {
      final href = _pick(_hrefs);
      final text = _chance(30) ? href : content(depth - 1);
      final extra = _chance(30) ? ' target="_self" rel="opener"' : '';
      final title = _chance(20) ? ' title="$_leak"' : '';
      return '<a href="$href"$extra$title${_hostileAttributes()}>$text'
          '${_close('a')}';
    }
    if (roll < 60) {
      final src = _pick(_imageSources);
      final dataSrc = _chance(20) ? ' data-src="${_pick(_imageSources)}"' : '';
      return '<img src="$src"$dataSrc alt="picture"${_hostileAttributes()}>';
    }
    if (roll < 64) {
      return '<mention-user data-id="user${_random.nextInt(9)}" '
          'data-label="User"${_hostileAttributes()}>$_leak</mention-user>';
    }
    if (roll < 70) return _pick(['<br>', '<hr>', '</p>', '</li>', '<br/>']);
    if (roll < 78) {
      final ordered = _chance(50);
      final tag = ordered ? 'ol' : 'ul';
      final start = ordered && _chance(50) ? ' start="${_text()}"' : '';
      final items = List.generate(
        1 + _random.nextInt(3),
        (_) => '<li>${content(depth - 1)}${_close('li')}',
      ).join();
      return '<$tag$start>$items${_close(tag)}';
    }
    if (roll < 84) {
      final items = List.generate(1 + _random.nextInt(3), (_) {
        final checked = _pick(['true', 'false', '', 'TRUE']);
        final body = _chance(50)
            ? '<label><input type="checkbox"></label><div>'
                  '${content(depth - 1)}</div>'
            : content(depth - 1);
        return '<li data-type="taskItem" data-checked="$checked"'
            '${_hostileAttributes()}>$body${_close('li')}';
      }).join();
      return '<ul data-type="taskList">$items${_close('ul')}';
    }
    if (roll < 88) {
      final rows = List.generate(1 + _random.nextInt(2), (_) {
        final cells = List.generate(1 + _random.nextInt(3), (_) {
          final tag = _chance(30) ? 'th' : 'td';
          final colour = _chance(30)
              ? ' data-background-color="${_pick(_cellColours)}"'
              : '';
          return '<$tag$colour colspan="${_random.nextInt(3)}">'
              '${content(depth - 1)}${_close(tag)}';
        }).join();
        return '<tr>$cells${_close('tr')}';
      }).join();
      return '<table>$rows${_close('table')}';
    }
    if (roll < 91) {
      return '<pre><code class="language-js"${_hostileAttributes()}>'
          '${content(depth - 1)}</code>${_close('pre')}';
    }
    final tag = _pick(_blockTags);
    final comment = tag == 'blockquote' && _chance(50)
        ? ' data-comment-id="${_pick(['12', '1 onmouseover=x', '-1'])}"'
        : '';
    return '<$tag$comment${_hostileAttributes()}>${content(depth - 1)}'
        '${_close(tag)}';
  }
}

final _dangerousScheme = RegExp(
  '^(javascript|data|vbscript|file|intent):',
  caseSensitive: false,
);
final _allWhitespace = RegExp(
  r'[\x00-\x20\xA0\u1680\u180E\u2000-\u2029\u205F\u3000]',
);

void _expectSafe(RichDocument document, String html) {
  final reason = 'input: $html';
  void expectNoLeak(String? value) {
    if (value != null) expect(value, isNot(contains(_leak)), reason: reason);
  }

  void expectTypes(Map<String, Object?> node) {
    expect(_schemaTypes, contains(node['type']), reason: reason);
    for (final child in (node['content'] as List<Object?>?) ?? const []) {
      expectTypes(child! as Map<String, Object?>);
    }
  }

  expectTypes(richDocumentJson(document));
  expectNoLeak(document.plainText);
  for (final node in richNodes(document)) {
    switch (node) {
      case RichTextRun(:final text, :final href):
        expectNoLeak(text);
        if (href != null) {
          expectNoLeak(href);
          expect(allowedLinkHref(href), href, reason: reason);
          expect(
            href.replaceAll(_allWhitespace, ''),
            isNot(matches(_dangerousScheme)),
            reason: reason,
          );
        }
      case RichMention(:final username, :final label):
        expectNoLeak(username);
        expectNoLeak(label);
      case RichTaskLink(:final href, :final taskId):
        expect(parseTaskIdFromUrl(href, bases: _bases), taskId, reason: reason);
      case RichImage(:final alt, :final title):
        expectNoLeak(alt);
        expectNoLeak(title);
      case RichExternalImage(:final url):
        expect(url.scheme, anyOf('http', 'https'), reason: reason);
        expect(url.host, isNotEmpty, reason: reason);
        expectNoLeak(url.toString());
      case RichCodeBlock(:final text, :final language):
        expectNoLeak(text);
        expectNoLeak(language);
      case RichAttachmentImage() || _:
        break;
    }
  }
}

void main() {
  final seen = <Type>{};

  for (var batch = 0; batch < 10; batch++) {
    test('seeded random markup, batch $batch', () {
      for (var seed = batch * 100; seed < (batch + 1) * 100; seed++) {
        final html = _Generator(seed).content(5);
        final RichDocument document;
        try {
          document = parseRichText(
            html,
            apiRoot: _apiRoot,
            taskLinkBases: _bases,
          );
        } on Object catch (error) {
          fail('seed $seed threw $error for $html');
        }
        _expectSafe(document, html);
        seen.addAll(richNodes(document).map((node) => node.runtimeType));
      }
    });
  }

  test('the random markup reaches every kind of node', () {
    expect(
      seen,
      containsAll(<Type>[
        RichParagraph,
        RichHeading,
        RichBlockquote,
        RichBulletList,
        RichOrderedList,
        RichTaskList,
        RichTaskItem,
        RichCodeBlock,
        RichHorizontalRule,
        RichTable,
        RichTableCell,
        RichImage,
        RichAttachmentImage,
        RichExternalImage,
        RichTextRun,
        RichHardBreak,
        RichMention,
        RichTaskLink,
      ]),
    );
  });

  test('random bytes never throw', () {
    final random = Random(42);
    for (var i = 0; i < 300; i++) {
      final html = String.fromCharCodes(
        List.generate(random.nextInt(200), (_) {
          final roll = random.nextInt(10);
          if (roll < 3) return '<>/="\'&;#'.codeUnitAt(random.nextInt(9));
          if (roll < 4) return random.nextInt(0x20);
          if (roll < 5) return 0xD800 + random.nextInt(0x800);
          return 0x20 + random.nextInt(0x7F - 0x20);
        }),
      );
      expect(
        () => parseRichText(html, apiRoot: _apiRoot, taskLinkBases: _bases),
        returnsNormally,
        reason: html,
      );
    }
  });
}
