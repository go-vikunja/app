// HTML fixtures are concatenated without whitespace on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'rich_text_json.dart';

final Uri _apiRoot = Uri.parse('https://tasks.example.com');
final List<Uri> _bases = [
  Uri.parse('https://tasks.example.com/'),
  Uri.parse('https://web.example.com/vikunja/'),
];

RichDocument _parse(String html, {Uri? apiRoot}) =>
    parseRichText(html, apiRoot: apiRoot ?? _apiRoot, taskLinkBases: _bases);

List<RichTaskItem> _taskItems(RichDocument document) =>
    richNodes(document).whereType<RichTaskItem>().toList();

List<RichTextRun> _runs(RichDocument document) =>
    richNodes(document).whereType<RichTextRun>().toList();

int _depth(RichDocument document) => _blocksDepth(document.blocks);

int _blocksDepth(List<RichBlock> blocks) {
  var deepest = 0;
  for (final block in blocks) {
    final inner = <List<RichBlock>>[
      if (block case RichBlockquote(blocks: final inner)) inner,
      if (block
          case RichBulletList(:final items) || RichOrderedList(:final items))
        for (final item in items) item.blocks,
      if (block case RichTaskList(:final items))
        for (final item in items) item.blocks,
      if (block case RichTable(:final rows))
        for (final row in rows)
          for (final cell in row.cells) cell.blocks,
    ];
    for (final blocks in [const <RichBlock>[], ...inner]) {
      deepest = max(deepest, 1 + _blocksDepth(blocks));
    }
  }
  return deepest;
}

void main() {
  group('legacy text is shown literally', () {
    test('plain text keeps its line breaks', () {
      final document = _parse('first line\nsecond line\r\n\r\nfourth');

      final paragraph = document.blocks.single as RichParagraph;
      expect(paragraph.inlines, [
        isA<RichTextRun>().having((r) => r.text, 'text', 'first line'),
        isA<RichHardBreak>(),
        isA<RichTextRun>().having((r) => r.text, 'text', 'second line'),
        isA<RichHardBreak>(),
        isA<RichHardBreak>(),
        isA<RichTextRun>().having((r) => r.text, 'text', 'fourth'),
      ]);
      expect(document.plainText, 'first line\nsecond line\n\nfourth');
    });

    test('markdown is not converted', () {
      final document = _parse('# Title\n- [ ] todo\n**bold** and `code`');

      expect(document.blocks.single, isA<RichParagraph>());
      expect(_runs(document).every((run) => run.marks.isEmpty), isTrue);
      expect(document.plainText, '# Title\n- [ ] todo\n**bold** and `code`');
    });

    test('an HTML-looking text with entities stays text', () {
      final document = _parse('&lt;script&gt;alert(1)&lt;/script&gt;');

      expect(document.plainText, '<script>alert(1)</script>');
    });
  });

  group('task items carry the offset findCheckboxesInText reports', () {
    void expectOffsets(String html, {required int items}) {
      final offsets = _taskItems(_parse(html)).map((item) => item.sourceOffset);
      expect(offsets, hasLength(items));
      expect(offsets, findCheckboxesInText(html));
    }

    test('the TipTap shape', () {
      expectOffsets(
        '<ul data-type="taskList">'
        '<li data-checked="true" data-type="taskItem"><label>'
        '<input type="checkbox" checked="checked"><span></span></label>'
        '<div><p>done</p></div></li>'
        '<li data-checked="false" data-type="taskItem"><label>'
        '<input type="checkbox"><span></span></label>'
        '<div><p>open</p></div></li></ul>',
        items: 2,
      );
    });

    test("the server's Markdown shape", () {
      expectOffsets(
        '<h1>Title</h1>\n<ul data-type="taskList">\n'
        '<li data-type="taskItem" data-checked="true"><p>done</p></li>\n'
        '<li data-type="taskItem" data-checked="false"><p>open</p></li>\n'
        '</ul>',
        items: 2,
      );
    });

    test('nested, indented with tabs, CR LF line ends and emoji before', () {
      expectOffsets(
        '<p>👍 🎉 👨‍👩‍👧</p>\r\n<ul data-type="taskList">\r\n'
        '\t<li data-checked="false" data-type="taskItem"><label>'
        '<input type="checkbox"><span></span></label>\r\n'
        '\t\t<div><p>Another task</p>\r\n'
        '\t\t\t<ul data-type="taskList">\r\n'
        '\t\t\t\t<li data-checked="true" data-type="taskItem"><label>'
        '<input type="checkbox"\r\n   checked="checked"><span></span></label>\r\n'
        '\t\t\t\t\t<div><p>done</p></div>\r\n'
        '\t\t\t\t</li>\r\n'
        '\t\t\t</ul>\r\n'
        '\t\t</div>\r\n'
        '\t</li>\r\n'
        '</ul>',
        items: 2,
      );
    });

    test('the checked state, the attribute anywhere in the start tag', () {
      final items = _taskItems(
        _parse(
          '<ul data-type="taskList">'
          '<li data-type="taskItem" title=\'data-checked="true"\' '
          'data-checked="false"><p>a</p></li>'
          '<li data-type="taskItem" data-checked="true"><p>b</p></li>'
          '</ul>',
        ),
      );

      expect(items.map((item) => item.checked), [false, true]);
      expect(items.first.sourceOffset, isNotNull);
    });

    test('unknown when findCheckboxesInText does not count the item', () {
      const html =
          '<ul data-type="taskList">'
          '<li data-type="taskItem" data-checked><p>empty means checked</p></li>'
          "<li data-type=\"taskItem\" data-checked='true'><p>quoted</p></li>"
          '<li data-type="taskItem" DATA-CHECKED="true"><p>upper</p></li>'
          '<li data-type="taskItem" data-checked="true" data-checked="false">'
          '<p>duplicate</p></li>'
          '</ul>';
      final items = _taskItems(_parse(html));

      expect(items.map((item) => item.checked), [true, true, true, true]);
      expect(items.map((item) => item.sourceOffset), [
        null,
        null,
        null,
        findCheckboxesInText(html).first,
      ]);
    });

    test('a plain item with data-checked is not a task item', () {
      const html =
          '<ul data-type="taskList"><li data-checked="true">plain</li></ul>';

      final items = _taskItems(_parse(html));

      expect(findCheckboxesInText(html), hasLength(1));
      expect(items.single.sourceOffset, isNull);
      expect(items.single.checked, isFalse);
    });
  });

  group('hostile markup', () {
    const dropped = {
      'script': '<p>a<script>LEAK()</script>b</p>',
      'style': '<style>LEAK{}</style><p>ab</p>',
      'iframe': '<p>a<iframe>LEAK</iframe>b</p>',
      'srcdoc': '<iframe srcdoc="&lt;p&gt;LEAK&lt;/p&gt;"></iframe><p>ab</p>',
      'template': '<template><p>LEAK</p></template><p>ab</p>',
      'svg': '<p>a<svg><text>LEAK</text><a href="x">LEAK</a></svg>b</p>',
      'math': '<p>a<math><mi>LEAK</mi></math>b</p>',
      'object': '<object data="x">LEAK</object><p>ab</p>',
      'noscript': '<noscript><p>LEAK</p></noscript><p>ab</p>',
      'title': '<title>LEAK</title><p>ab</p>',
      'video': '<video>LEAK</video><audio>LEAK</audio><p>ab</p>',
      'form controls':
          '<form><button>LEAK</button><textarea>LEAK</textarea>'
          '<select><option>LEAK</option></select></form><p>ab</p>',
    };
    for (final MapEntry(key: name, value: html) in dropped.entries) {
      test('$name is dropped with its content', () {
        final document = _parse(html);

        expect(document.plainText, 'ab');
        expect(document.plainText, isNot(contains('LEAK')));
      });
    }

    test('javascript:, data: and vbscript: links lose the link', () {
      final document = _parse(
        '<p><a href="javascript:alert(1)">a</a>'
        '<a href=" JaVaScRiPt:alert(1)">b</a>'
        '<a href="java&#x09;script:alert(1)">c</a>'
        '<a href="&#106;avascript:alert(1)">d</a>'
        '<a href="java&#x0A;script:alert(1)">e</a>'
        '<a href="&#x01;javascript:alert(1)">f</a>'
        '<a href="java&#xA0;script:alert(1)">g</a>'
        '<a href="data:text/html,x">h</a>'
        '<a href="vbscript:msgbox(1)">i</a>'
        '<a href="file:///etc/passwd">j</a></p>',
      );

      expect(_runs(document).map((run) => run.href), [null]);
      expect(document.plainText, 'abcdefghij');
    });

    test('allowed links are cleaned like a browser cleans a URL', () {
      final document = _parse(
        '<p><a href="  https://example.com/a?b#c  ">a</a> '
        '<a href="ht&#x09;tps://example.com/x">b</a> '
        '<a href="mailto:me@example.com">c</a> '
        '<a href="/projects/1">d</a></p>',
      );

      expect(_runs(document).map((run) => run.href).nonNulls, [
        'https://example.com/a?b#c',
        'https://example.com/x',
        'mailto:me@example.com',
        '/projects/1',
      ]);
    });

    test('images load from nowhere but this server or plain http(s)', () {
      final document = _parse(
        '<img src="javascript:alert(1)"><img src="x" onerror="alert(1)">'
        '<img src="data:image/png;base64,AAAA"><img src=" DATA:image/png,x">'
        '<img src="//tracker.example/p.png"><img src="ftp://example.com/a.png">'
        '<img src="https://images.example/cat.png" alt="cat">'
        '<img src="#" data-src="https://tasks.example.com/api/v2/tasks/5/attachments/9">',
      );

      final images = document.blocks.whereType<RichImage>().toList();
      expect(images.map((image) => imageSourceJson(image.source)), [
        {'external': 'https://images.example/cat.png'},
        {
          'attachment': [5, 9],
        },
      ]);
    });

    test('event handlers, styles and ids leave nothing behind', () {
      final document = _parse(
        '<p onclick="alert(1)" style="background:url(javascript:alert(1))" '
        'id="x">x</p><h1 onload="alert(2)">h</h1>',
      );

      expect(richDocumentJson(document), {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'x'},
            ],
          },
          {
            'type': 'heading',
            'attrs': {'level': 1},
            'content': [
              {'type': 'text', 'text': 'h'},
            ],
          },
        ],
      });
    });

    test('a cell colour must be a colour', () {
      final document = _parse(
        '<table><tr>'
        '<td data-background-color="#f00">a</td>'
        '<td data-background-color=" #00FF7f ">b</td>'
        '<td data-background-color="rgb(1, 2, 300)">c</td>'
        '<td data-background-color="rgb( 1,2 ,3 )">d</td>'
        '<td data-background-color="red; background-image: url(x)">e</td>'
        '<th data-background-color="#fff">f</th>'
        '</tr></table>',
      );

      final cells = richNodes(document).whereType<RichTableCell>();
      expect(cells.map((cell) => cell.backgroundColor), [
        0xFFFF0000,
        0xFF00FF7F,
        null,
        0xFF010203,
        null,
        null,
      ]);
    });

    test('deep nesting is cut short instead of overflowing the stack', () {
      for (final (open, close) in [
        ('<div>', '</div>'),
        ('<blockquote>', '</blockquote>'),
        ('<ul><li>', '</li></ul>'),
        ('<b>', '</b>'),
        ('<table><tr><td>', '</td></tr></table>'),
      ]) {
        final html = '${open * 5000}deep${close * 5000}<p>after</p>';

        final document = _parse(html);

        expect(document.plainText, contains('deep'));
        expect(document.plainText, endsWith('after'));
        expect(_depth(document), lessThan(200));
      }
    });

    group('long attributes parse in linear time', () {
      final spaces = ' ' * 100000;
      final inputs = {
        'href with inner spaces': '<p><a href="a${spaces}b">x</a></p>',
        'href with trailing spaces':
            '<p><a href="https://a.example$spaces">x</a></p>',
        'img src with inner spaces': '<img src="https://a.example/${spaces}b">',
        'style with inner spaces':
            '<p><b style="font-weight:a${spaces}b">x</b></p>',
        'style with a lone bang':
            '<p><b style="font-weight:a$spaces!${spaces}b">x</b></p>',
        'style with unterminated comments':
            '<p><b style="${'/* ' * 33000}">x</b></p>',
        'comment id of digits':
            '<blockquote data-comment-id="${'1' * 100000}x">q</blockquote>',
      };
      for (final MapEntry(key: name, value: html) in inputs.entries) {
        test(name, () {
          final watch = Stopwatch()..start();

          _parse(html);

          expect(watch.elapsedMilliseconds, lessThan(500));
        });
      }
    });

    test('style comments and !important are read like a browser', () {
      final document = _parse(
        '<p><b style="font-weight: /* x */ normal">a</b>'
        '<b style="font-weight: normal ! IMPORTANT">b</b>'
        '<b style="font-weight: normal /* unterminated">c</b>'
        '<b style="font-weight: /*/ normal */ bold">d</b>'
        '<b style="font-weight: normal!importantx">e</b></p>',
      );

      expect(_runs(document).map((run) => (run.text, run.marks.join(','))), [
        ('abc', ''),
        ('de', '${RichMark.bold}'),
      ]);
    });

    test('unclosed tags and stray end tags', () {
      final document = _parse(
        '<p><strong>bold <em>both</p><p>next</em></b></ul>',
      );

      final runs = _runs(document);
      expect(runs.last.text, 'next');
      expect(runs.last.marks, {RichMark.bold, RichMark.italic});
    });
  });

  group('nodes', () {
    test('mentions show their label, else their username', () {
      final document = _parse(
        '<p><mention-user data-id="jdoe" data-label="Jane Doe">@ignored'
        '</mention-user> and <mention-user data-id="max"></mention-user>'
        '<mention-user></mention-user></p>',
      );

      final mentions = richNodes(document).whereType<RichMention>().toList();
      expect(mentions.map((m) => (m.username, m.label)), [
        ('jdoe', 'Jane Doe'),
        ('max', ''),
      ]);
      expect(document.plainText, 'Jane Doe and max');
    });

    test('task links by the server root and the frontend URL', () {
      final document = _parse(
        '<p><a href="https://tasks.example.com/tasks/12">'
        'https://tasks.example.com/tasks/12</a> '
        '<a href="https://web.example.com/vikunja/tasks/13">'
        'https://web.example.com/vikunja/tasks/13</a> '
        '<a href="/tasks/14">/tasks/14</a> '
        '<a href="https://web.example.com/tasks/15">'
        'https://web.example.com/tasks/15</a></p>',
      );

      expect(
        richNodes(document).whereType<RichTaskLink>().map((l) => l.taskId),
        [12, 13, 14],
      );
      expect(_runs(document).map((run) => run.href).nonNulls, [
        'https://web.example.com/tasks/15',
      ]);
    });

    test('attachment images of a server under a sub-path', () {
      final document = _parse(
        '<img src="https://example.com/vikunja/api/v1/tasks/3/attachments/4">'
        '<img src="/vikunja/api/v2/tasks/3/attachments/5">'
        '<img src="https://example.com/api/v2/tasks/3/attachments/6">',
        apiRoot: Uri.parse('https://example.com/vikunja/'),
      );

      final sources = document.blocks.whereType<RichImage>().map(
        (image) => imageSourceJson(image.source),
      );
      expect(sources, [
        {
          'attachment': [3, 4],
        },
        {
          'attachment': [3, 5],
        },
        {'external': 'https://example.com/api/v2/tasks/3/attachments/6'},
      ]);
    });

    test('code blocks keep every space, a <br> is a newline', () {
      final document = _parse(
        '<pre><code class="hljs language-dart">void main() {\n'
        '  print(1);<br>}</code></pre>',
      );

      final code = document.blocks.single as RichCodeBlock;
      expect(code.text, 'void main() {\n  print(1);\n}');
      expect(code.language, 'dart');
    });

    test('ordered list starts like parseInt reads them', () {
      final starts = [
        for (final start in ['3', ' 7x', '-2', 'abc', ''])
          (_parse('<ol start="$start"><li>a</li></ol>').blocks.single
                  as RichOrderedList)
              .start,
      ];

      expect(starts, [3, 7, -2, 1, 1]);
    });

    test('reply quotes keep a positive integer comment id only', () {
      final ids = [
        for (final id in [
          '12',
          ' 7 ',
          '0x10',
          '1e2',
          '0',
          '-3',
          '1.5',
          'x',
          '+4',
          '5.',
          '.6e1',
          '7.0e0',
          '.',
          '1e',
        ])
          (_parse('<blockquote data-comment-id="$id">q</blockquote>')
                      .blocks
                      .single
                  as RichBlockquote)
              .commentId,
      ];

      expect(ids, [
        12,
        7,
        16,
        100,
        null,
        null,
        null,
        null,
        4,
        5,
        6,
        7,
        null,
        null,
      ]);
    });
  });

  group('isEmpty and plainText', () {
    test('empty without visible content', () {
      for (final html in [
        '',
        '   ',
        '<p></p>',
        '<p></p><p></p>',
        '<p><br></p>',
        '<p>&nbsp;</p>',
        '<ul><li><p></p></li></ul>',
        '<pre> </pre>',
        '<img src="x">',
      ]) {
        expect(_parse(html).isEmpty, isTrue, reason: html);
      }
    });

    test('not empty with text, a mention, a task link, a rule, a table, '
        'an image or a task item', () {
      for (final html in [
        'x',
        '<p><mention-user data-id="a"></mention-user></p>',
        '<p><a href="/tasks/1">/tasks/1</a></p>',
        '<hr>',
        '<table><tr><td></td></tr></table>',
        '<img src="https://example.com/a.png">',
        '<ul data-type="taskList"><li data-type="taskItem"><p></p></li></ul>',
      ]) {
        expect(_parse(html).isEmpty, isFalse, reason: html);
      }
    });

    test('plainText puts blocks on lines', () {
      final document = _parse(
        '<h2>Title</h2><p>a<br>b</p><ul><li>one</li><li>two</li></ul>'
        '<blockquote><p>quote</p></blockquote><hr>'
        '<img src="https://example.com/a.png" alt="picture">'
        '<table><tr><td>c1</td><td>c2</td></tr></table>',
      );

      expect(
        document.plainText,
        'Title\na\nb\none\ntwo\nquote\npicture\nc1\nc2',
      );
    });
  });

  test('isRichTextEmpty is the web string test', () {
    expect(isRichTextEmpty(''), isTrue);
    expect(isRichTextEmpty('<p></p>'), isTrue);
    expect(isRichTextEmpty('<p><br></p>'), isFalse);
  });
}
