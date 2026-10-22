// HTML fixtures are concatenated without whitespace on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

final Uri _apiRoot = Uri.parse('https://tasks.example.com');
final List<Uri> _bases = [Uri.parse('https://tasks.example.com/')];

RichDocument _parse(String html) =>
    parseRichText(html, apiRoot: _apiRoot, taskLinkBases: _bases);

List<RichTaskItem> _items(String html) => _parse(html).taskItems;

String _tipTapItem(
  String text, {
  bool checked = false,
  String? id,
  String nested = '',
}) =>
    '<li data-checked="$checked"${id == null ? '' : ' data-task-id="$id"'} '
    'data-type="taskItem"><label><input type="checkbox"'
    '${checked ? ' checked="checked"' : ''}><span></span></label>'
    '<div><p>$text</p>$nested</div></li>';

String _markdownItem(String text, {bool checked = false}) =>
    '<li data-type="taskItem" data-checked="$checked"><p>$text</p></li>';

String _taskList(List<String> items) =>
    '<ul data-type="taskList">${items.join()}</ul>';

/// Toggles every item of [html] in turn and checks that only that item
/// changes, that a second toggle restores [html] exactly and that the
/// offsets of an older parse are refused once they moved.
void _expectEachToggleIsLocal(String html) {
  final items = _items(html);
  expect(items, isNotEmpty);
  final before = checklistStatistics(html);
  for (var k = 0; k < items.length; k++) {
    final item = items[k];
    expect(item.sourceOffset, isNotNull, reason: 'item $k has an offset');
    final toggled = toggleTaskItem(html, item, checked: !item.checked);
    expect(toggled, isNotNull, reason: 'item $k toggles');
    final after = _items(toggled!);
    expect(after, hasLength(items.length));
    for (var j = 0; j < items.length; j++) {
      expect(
        after[j].checked,
        j == k ? !items[j].checked : items[j].checked,
        reason: 'item $j after toggling $k',
      );
      expect(after[j].taskId, items[j].taskId);
      expect(checklistItemText(after[j]), checklistItemText(items[j]));
    }
    final statistics = checklistStatistics(toggled);
    expect(statistics.total, before.total);
    expect(
      statistics.checked,
      before.checked + (item.checked ? -1 : 1),
      reason: 'the summary moves by one',
    );
    expect(
      toggled.substring(0, item.sourceOffset),
      html.substring(0, item.sourceOffset),
      reason: 'nothing before the item changes',
    );
    expect(
      toggleTaskItem(toggled, after[k], checked: item.checked),
      html,
      reason: 'toggling back restores every byte',
    );
    for (var j = 0; j < items.length; j++) {
      final stale = toggleTaskItem(toggled, items[j], checked: true);
      if (j > k) {
        expect(stale, isNull, reason: 'item $j moved after toggling $k');
      } else if (j < k) {
        expect(stale, isNotNull, reason: 'item $j stays where it was');
      }
    }
  }
}

void main() {
  group('toggleTaskItem', () {
    test('the TipTap shape: the value and the input change together', () {
      final html = _taskList([
        _tipTapItem('done', checked: true, id: 'a1'),
        _tipTapItem('open', id: 'b2'),
      ]);
      final items = _items(html);

      expect(
        toggleTaskItem(html, items[1], checked: true),
        _taskList([
          _tipTapItem('done', checked: true, id: 'a1'),
          _tipTapItem('open', checked: true, id: 'b2'),
        ]),
      );
      expect(
        toggleTaskItem(html, items[0], checked: false),
        _taskList([
          _tipTapItem('done', id: 'a1'),
          _tipTapItem('open', id: 'b2'),
        ]),
      );
    });

    test("the server's Markdown shape: only the value changes", () {
      const html =
          '<h1>List</h1>\n<ul data-type="taskList">\n'
          '<li data-type="taskItem" data-checked="false"><p>one</p></li>\n'
          '<li data-type="taskItem" data-checked="true"><p>two</p></li>\n'
          '</ul>';
      final items = _items(html);

      expect(
        toggleTaskItem(html, items[0], checked: true),
        html.replaceFirst('data-checked="false"', 'data-checked="true"'),
      );
      expect(
        toggleTaskItem(html, items[1], checked: false),
        html.replaceFirst(
          'data-checked="true"><p>two',
          'data-checked="false"><p>two',
        ),
      );
    });

    test('the state it already has gives the same text', () {
      final html = _taskList([_tipTapItem('a', checked: true)]);
      final item = _items(html).single;

      expect(toggleTaskItem(html, item, checked: true), same(html));
    });

    test('null without an offset', () {
      const html =
          '<ul data-type="taskList">'
          '<li data-type="taskItem" data-checked><p>empty means checked</p>'
          '</li></ul>';
      final item = _items(html).single;

      expect(item.sourceOffset, isNull);
      expect(toggleTaskItem(html, item, checked: false), isNull);
    });

    test('null for HTML the item was not parsed from', () {
      final html = _taskList([_tipTapItem('a'), _tipTapItem('b')]);
      final items = _items(html);

      expect(toggleTaskItem('<p>x</p>$html', items[0], checked: true), isNull);
      expect(
        toggleTaskItem(html.substring(0, 20), items[1], checked: true),
        isNull,
      );
      expect(toggleTaskItem('', items[0], checked: true), isNull);
      final otherState = html.replaceFirst(
        'data-checked="false"',
        'data-checked="true"',
      );
      expect(toggleTaskItem(otherState, items[0], checked: true), isNull);
    });

    test('a value inside another attribute is not an offset', () {
      const html =
          '<ul data-type="taskList">'
          '<li title=\'x data-checked="false"\' data-type="taskItem" '
          'data-checked="true"><p>a</p></li></ul>';
      final item = _items(html).single;
      final forged = RichTaskItem(
        checked: false,
        blocks: const [],
        sourceOffset: html.indexOf('data-checked="false"'),
      );

      expect(toggleTaskItem(html, forged, checked: true), isNull);
      expect(
        toggleTaskItem(html, item, checked: false),
        html.replaceFirst('data-checked="true"', 'data-checked="false"'),
      );
    });

    test('the input follows only in the exact TipTap shape', () {
      const spaced =
          '<ul data-type="taskList"><li data-checked="true" '
          'data-type="taskItem"><label><input type="checkbox"\r\n'
          '   checked="checked"><span></span></label><div><p>a</p></div>'
          '</li></ul>';
      const noLabel =
          '<ul data-type="taskList"><li data-checked="false" '
          'data-type="taskItem"> <label><input type="checkbox"><span></span>'
          '</label><div><p>a</p></div></li></ul>';

      expect(
        toggleTaskItem(spaced, _items(spaced).single, checked: false),
        spaced.replaceFirst('data-checked="true"', 'data-checked="false"'),
      );
      expect(
        toggleTaskItem(noLabel, _items(noLabel).single, checked: true),
        noLabel.replaceFirst('data-checked="false"', 'data-checked="true"'),
      );
    });

    test('the start tag ends at its real >, not one in a quoted value', () {
      const html =
          '<ul data-type="taskList"><li data-checked="false" title="a>b" '
          "data-x='>' data-type=\"taskItem\"><label><input type=\"checkbox\">"
          '<span></span></label><div><p>a</p></div></li></ul>';

      expect(
        toggleTaskItem(html, _items(html).single, checked: true),
        html
            .replaceFirst('data-checked="false"', 'data-checked="true"')
            .replaceFirst(
              '<input type="checkbox">',
              '<input type="checkbox" checked="checked">',
            ),
      );
    });

    test('an inconsistent input is set to the new state', () {
      const html =
          '<ul data-type="taskList"><li data-checked="false" '
          'data-type="taskItem"><label><input type="checkbox" '
          'checked="checked"><span></span></label><div><p>a</p></div></li>'
          '</ul>';

      expect(
        toggleTaskItem(html, _items(html).single, checked: true),
        html.replaceFirst('data-checked="false"', 'data-checked="true"'),
      );
    });

    test('nested items with tabs, CR LF line ends and emoji before them', () {
      _expectEachToggleIsLocal(
        '<p>👍 🎉 👨‍👩‍👧</p>\r\n<ul data-type="taskList">\r\n'
        '\t<li data-checked="false" data-type="taskItem"><label>'
        '<input type="checkbox"><span></span></label>\r\n'
        '\t\t<div><p>Another task 🙂</p>\r\n'
        '\t\t\t<ul data-type="taskList">\r\n'
        '\t\t\t\t<li data-checked="true" data-type="taskItem"><label>'
        '<input type="checkbox" checked="checked"><span></span></label>\r\n'
        '\t\t\t\t\t<div><p>done</p></div>\r\n'
        '\t\t\t\t</li>\r\n'
        '\t\t\t</ul>\r\n'
        '\t\t</div>\r\n'
        '\t</li>\r\n'
        '</ul>',
      );
    });

    test('identical items are told apart', () {
      _expectEachToggleIsLocal(
        _taskList([_tipTapItem('same'), _tipTapItem('same')]),
      );
    });

    test('items in tables, quotes and other lists', () {
      final list = _taskList([_markdownItem('a'), _markdownItem('b')]);
      _expectEachToggleIsLocal(
        '<table><tbody><tr><td>$list</td><td><p>x</p></td></tr></tbody>'
        '</table><blockquote>$list</blockquote><ul><li><p>p</p>$list</li>'
        '</ul>',
      );
    });

    test('items the web moves: stray, in a plain list, unclosed, in p, h1 '
        'and code', () {
      const stray =
          '<li data-type="taskItem" data-checked="false"><p>stray</p></li>';
      const inPlainList =
          '<ul><li data-type="taskItem" data-checked="true"><p>plain</p></li>'
          '</ul>';
      const unclosed =
          '<ul data-type="taskList"><li data-type="taskItem" '
          'data-checked="false"><p>unclosed<li data-type="taskItem" '
          'data-checked="true">next';
      const inParagraph =
          '<p>before <li data-type="taskItem" data-checked="false">in p</li>'
          '</p>';
      const inHeading =
          '<h1><li data-type="taskItem" data-checked="true">in h1</li></h1>';
      const inCode =
          '<pre><code><li data-type="taskItem" data-checked="false">code</li>'
          '</code></pre>';

      [
        stray,
        inPlainList,
        unclosed,
        inParagraph,
        inHeading,
        inCode,
      ].forEach(_expectEachToggleIsLocal);
    });

    test(
      'an item in a comment or a template is no item; the others toggle',
      () {
        const html =
            '<!-- <ul data-type="taskList"><li data-type="taskItem" '
            'data-checked="false"><p>old</p></li></ul> -->'
            '<template><li data-type="taskItem" data-checked="true">t</li>'
            '</template>'
            '<ul data-type="taskList"><li data-type="taskItem" '
            'data-checked="false"><p>real</p></li></ul>';
        final item = _items(html).single;

        final toggled = toggleTaskItem(html, item, checked: true)!;

        expect(
          toggled,
          html.replaceFirst(
            'data-checked="false"><p>real',
            'data-checked="true"><p>real',
          ),
        );
        expect(
          checklistStatistics(toggled),
          const ChecklistStatistics(total: 3, checked: 2),
        );
      },
    );

    test('a toggle shifts later offsets by one', () {
      final html = _taskList([
        _markdownItem('a'),
        _markdownItem('b', checked: true),
        _markdownItem('c'),
      ]);
      final items = _items(html);
      final toggled = toggleTaskItem(html, items[0], checked: true)!;
      final after = _items(toggled);

      expect(after[0].sourceOffset, items[0].sourceOffset);
      expect(after[1].sourceOffset, items[1].sourceOffset! - 1);
      expect(after[2].sourceOffset, items[2].sourceOffset! - 1);
      final back = toggleTaskItem(toggled, after[1], checked: false)!;
      expect(_items(back)[2].sourceOffset, items[2].sourceOffset);
    });

    test('random documents: a toggle changes only its item', () {
      final random = Random(25);
      for (var round = 0; round < 250; round++) {
        _expectEachToggleIsLocal(_randomDocument(random));
      }
    });
  });

  group('RichTaskItem.taskId', () {
    test('the stored id; null when missing, empty or repeated', () {
      const html =
          '<ul data-type="taskList">'
          '<li data-type="taskItem" data-checked="false" data-task-id="one">'
          '<p>a</p></li>'
          '<li data-type="taskItem" data-checked="false" data-task-id="">'
          '<p>b</p></li>'
          '<li data-type="taskItem" data-checked="false"><p>c</p></li>'
          '<li data-type="taskItem" data-checked="false" data-task-id="one">'
          '<p>d</p></li>'
          '</ul>';

      expect(_items(html).map((item) => item.taskId), [
        'one',
        null,
        null,
        null,
      ]);
    });
  });

  group('taskItems', () {
    test('document order, nested items after their parent', () {
      final nested = _taskList([_tipTapItem('1.1'), _tipTapItem('1.2')]);
      final quoted = _taskList([_markdownItem('3')]);
      final inCell = _taskList([_markdownItem('4')]);
      final html =
          '${_taskList([_tipTapItem('1', nested: nested), _tipTapItem('2')])}'
          '<blockquote>$quoted</blockquote>'
          '<table><tbody><tr><td>$inCell</td></tr></tbody></table>';

      expect(_items(html).map(checklistItemText), [
        '1',
        '1.1',
        '1.2',
        '2',
        '3',
        '4',
      ]);
    });
  });

  group('checklistItemText', () {
    test('the own text with whitespace collapsed, without nested items', () {
      const item =
          '<li data-type="taskItem" data-checked="false"><p>  Buy\t<strong>'
          'milk</strong><br>and <mention-user data-id="jd" '
          'data-label="Jane"></mention-user> '
          '<a href="https://tasks.example.com/tasks/3">'
          'https://tasks.example.com/tasks/3</a></p>';
      final nested = _taskList([_markdownItem('child')]);
      final html = _taskList(['$item$nested</li>']);

      expect(
        checklistItemText(_items(html).first),
        'Buy milk and Jane https://tasks.example.com/tasks/3',
      );
    });
  });

  group('checklistToggleFor', () {
    test('by id when the item has one of its own', () {
      final html = _taskList([_tipTapItem('a', id: 'x1'), _tipTapItem('b')]);
      final document = _parse(html);

      expect(
        checklistToggleFor(document, document.taskItems[0], checked: true),
        const ChecklistToggle.byId('x1', checked: true),
      );
      expect(
        checklistToggleFor(document, document.taskItems[1], checked: false),
        const ChecklistToggle.byPosition(ordinal: 1, text: 'b', checked: false),
      );
    });

    test('by position for an item whose id an earlier item has', () {
      final html = _taskList([
        _tipTapItem('a', id: 'same'),
        _tipTapItem('b', id: 'same'),
      ]);
      final document = _parse(html);

      expect(
        checklistToggleFor(document, document.taskItems[1], checked: true),
        const ChecklistToggle.byPosition(ordinal: 1, text: 'b', checked: true),
      );
    });

    test('an item of another document is an error', () {
      final html = _taskList([_tipTapItem('a')]);

      expect(
        () => checklistToggleFor(
          _parse(html),
          _parse(html).taskItems.single,
          checked: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('rebaseChecklistToggles', () {
    final base = _taskList([
      _tipTapItem('milk', id: 'm1'),
      _tipTapItem('eggs', id: 'e2', checked: true),
    ]);

    test('on the unchanged HTML it is the toggle itself', () {
      final document = _parse(base);
      final toggle = checklistToggleFor(
        document,
        document.taskItems[0],
        checked: true,
      );

      expect(
        rebaseChecklistToggles(base, [toggle]),
        toggleTaskItem(base, document.taskItems[0], checked: true),
      );
    });

    test('by id onto a description changed around the item', () {
      String server({required bool milk, required bool eggs}) {
        final list = _taskList([
          _tipTapItem('bread 🍞', id: 'b0'),
          _tipTapItem('milk (2 l)', id: 'm1', checked: milk),
          _tipTapItem('eggs', id: 'e2', checked: eggs),
        ]);
        return '<h2>Shopping</h2>\r\n$list<p>added on the web</p>';
      }

      final rebased = rebaseChecklistToggles(
        server(milk: false, eggs: true),
        const [
          ChecklistToggle.byId('m1', checked: true),
          ChecklistToggle.byId('e2', checked: false),
        ],
      );

      expect(rebased, server(milk: true, eggs: false));
    });

    test('by position when the text still matches, else dropped', () {
      const markdown =
          '<ul data-type="taskList">\n'
          '<li data-type="taskItem" data-checked="false"><p>milk</p></li>\n'
          '<li data-type="taskItem" data-checked="false"><p>eggs</p></li>\n'
          '</ul>';
      const toggle = ChecklistToggle.byPosition(
        ordinal: 1,
        text: 'eggs',
        checked: true,
      );

      final normalisedByTheWeb = _taskList([
        _tipTapItem('milk', id: 'n1'),
        _tipTapItem('eggs', id: 'n2'),
      ]);
      expect(
        rebaseChecklistToggles(normalisedByTheWeb, const [toggle]),
        _taskList([
          _tipTapItem('milk', id: 'n1'),
          _tipTapItem('eggs', id: 'n2', checked: true),
        ]),
      );
      expect(
        rebaseChecklistToggles(markdown, const [toggle]),
        markdown.replaceFirst(
          'data-checked="false"><p>eggs',
          'data-checked="true"><p>eggs',
        ),
      );

      final renamed = markdown.replaceFirst('eggs', 'six eggs');
      expect(rebaseChecklistToggles(renamed, const [toggle]), renamed);
      final inserted = markdown.replaceFirst(
        '<li',
        '<li data-type="taskItem" data-checked="false"><p>new</p></li><li',
      );
      expect(rebaseChecklistToggles(inserted, const [toggle]), inserted);
    });

    test('a toggle whose item is gone or cannot be toggled is dropped', () {
      const server =
          '<ul data-type="taskList">'
          '<li data-type="taskItem" data-checked data-task-id="m1"><p>milk'
          '</p></li></ul>';

      expect(
        rebaseChecklistToggles(server, const [
          ChecklistToggle.byId('m1', checked: false),
          ChecklistToggle.byId('gone', checked: true),
          ChecklistToggle.byPosition(ordinal: 5, text: 'x', checked: true),
        ]),
        server,
      );
      expect(
        rebaseChecklistToggles('', const [
          ChecklistToggle.byId('m1', checked: true),
        ]),
        '',
      );
    });

    test('taps in order: the last one for an item wins', () {
      final rebased = rebaseChecklistToggles(base, const [
        ChecklistToggle.byId('m1', checked: true),
        ChecklistToggle.byId('m1', checked: false),
        ChecklistToggle.byId('e2', checked: false),
        ChecklistToggle.byId('e2', checked: true),
        ChecklistToggle.byId('m1', checked: true),
      ]);

      expect(
        rebased,
        _taskList([
          _tipTapItem('milk', id: 'm1', checked: true),
          _tipTapItem('eggs', id: 'e2', checked: true),
        ]),
      );
    });

    test('random documents: taps recorded on one version apply to another', () {
      final random = Random(52);
      for (var round = 0; round < 150; round++) {
        final html = _randomDocument(random);
        final document = _parse(html);
        final items = document.taskItems;
        final k = random.nextInt(items.length);
        final toggle = checklistToggleFor(
          document,
          items[k],
          checked: !items[k].checked,
        );
        final expected = toggleTaskItem(
          html,
          items[k],
          checked: !items[k].checked,
        );

        expect(rebaseChecklistToggles(html, [toggle]), expected);
        const prefix = '<p>changed on the web</p>\r\n';
        expect(
          rebaseChecklistToggles('$prefix$html', [toggle]),
          '$prefix$expected',
        );
      }
    });

    test('random documents: many taps give what tapping one by one gives', () {
      final random = Random(53);
      for (var round = 0; round < 300; round++) {
        var html = _randomDocument(random);
        if (random.nextInt(4) == 0) html = html.replaceFirst('"id1"', '"id0"');
        final items = _items(html);
        final toggles = [
          for (var i = random.nextInt(13); i > 0; i--)
            _randomToggle(random, items),
        ];
        const prefix = '<p>changed on the web</p>\r\n';

        expect(
          rebaseChecklistToggles(html, toggles),
          _rebaseOneByOne(html, toggles),
          reason: html,
        );
        expect(
          rebaseChecklistToggles('$prefix$html', toggles),
          _rebaseOneByOne('$prefix$html', toggles),
          reason: html,
        );
      }
    });

    test('an item whose checkbox runs into the next one', () {
      // The second item closes the first inside its label.
      const cut =
          '<li data-checked="false" data-task-id="a" data-type="taskItem">'
          '<label><input type="checkbox">';
      final html = _taskList([cut, _tipTapItem('b', id: 'b', checked: true)]);
      const toggles = [
        ChecklistToggle.byId('b', checked: false),
        ChecklistToggle.byId('a', checked: true),
      ];

      final rebased = rebaseChecklistToggles(html, toggles);

      expect(rebased, _rebaseOneByOne(html, toggles));
      expect(_items(rebased).map((item) => item.checked), [true, false]);
    });

    test('many taps on a long checklist read it once', () {
      final html = _taskList([
        for (var i = 0; i < 6000; i++) _tipTapItem('item $i', id: 'i$i'),
      ]);
      final toggles = [
        for (var i = 0; i < 100; i++)
          ChecklistToggle.byId('i${i * 60}', checked: true),
      ];
      final watch = Stopwatch()..start();

      final rebased = rebaseChecklistToggles(html, toggles);

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(_items(rebased).where((item) => item.checked), hasLength(100));
    });
  });
}

/// How `rebaseChecklistToggles` worked before it read the HTML only once:
/// the item of each tap looked up again after every tap.
String _rebaseOneByOne(String html, List<ChecklistToggle> toggles) {
  var rebased = html;
  for (final toggle in toggles) {
    final items = _items(rebased);
    final ordinal = toggle.ordinal;
    final item = switch (toggle.itemId) {
      final id? => items.where((item) => item.taskId == id).firstOrNull,
      null
          when ordinal! >= 0 &&
              ordinal < items.length &&
              checklistItemText(items[ordinal]) == toggle.text =>
        items[ordinal],
      null => null,
    };
    if (item == null) continue;
    rebased = toggleTaskItem(rebased, item, checked: toggle.checked) ?? rebased;
  }
  return rebased;
}

ChecklistToggle _randomToggle(Random random, List<RichTaskItem> items) {
  final checked = random.nextBool();
  final ordinal = random.nextInt(items.length + 2);
  final item = ordinal < items.length ? items[ordinal] : null;
  return switch (random.nextInt(4)) {
    0 => ChecklistToggle.byId(item?.taskId ?? 'gone', checked: checked),
    1 => ChecklistToggle.byPosition(
      ordinal: ordinal,
      text: item == null ? 'x' : checklistItemText(item),
      checked: checked,
    ),
    2 => ChecklistToggle.byPosition(
      ordinal: ordinal,
      text: 'changed',
      checked: checked,
    ),
    _ => ChecklistToggle.byId('id${random.nextInt(20)}', checked: checked),
  };
}

const _words = ['milk', 'eggs', '🍞 bread', 'tea\tcup', 'a<b', 'x&amp;y'];

/// A description with task items in every shape and place the parser
/// gives an offset to, at most two levels deep.
String _randomDocument(Random random) => _DocumentGenerator(random).document();

final class _DocumentGenerator {
  new(this.random);

  final Random random;
  var _nextId = 0;

  String document() {
    final blocks = [
      list(0),
      for (var i = random.nextInt(4); i > 0; i--) block(),
    ]..shuffle(random);
    return blocks.join(separator());
  }

  String separator() => ['', '\n', '\r\n', '\t', ' '][random.nextInt(5)];

  String text() => _words[random.nextInt(_words.length)];

  String block() => switch (random.nextInt(6)) {
    0 => '<p>${text()} 👨‍👩‍👧</p>',
    1 => '<blockquote>${list(0)}</blockquote>',
    2 =>
      '<table><tbody><tr><td>${list(0)}</td><td><p>${text()}</p></td>'
          '</tr></tbody></table>',
    3 => '<ul><li><p>${text()}</p>${list(0)}</li></ul>',
    _ => list(0),
  };

  String list(int depth) {
    final count = 1 + random.nextInt(3);
    return '<ul data-type="taskList">${separator()}'
        '${[for (var i = 0; i < count; i++) item(depth)].join(separator())}'
        '${separator()}</ul>';
  }

  String item(int depth) {
    final checked = random.nextBool();
    final nested = depth < 2 && random.nextInt(4) == 0 ? list(depth + 1) : '';
    final id = random.nextInt(3) == 0 ? null : 'id${_nextId++}';
    final extra = random.nextInt(4) == 0 ? ' title="a>b \'q\'"' : '';
    if (random.nextBool()) {
      return '<li data-checked="$checked"'
          '${id == null ? '' : ' data-task-id="$id"'}$extra '
          'data-type="taskItem"><label><input type="checkbox"'
          '${checked ? ' checked="checked"' : ''}><span></span></label>'
          '${separator()}<div><p>${text()}</p>$nested</div></li>';
    }
    return '<li data-type="taskItem"$extra data-checked="$checked"'
        '${id == null ? '' : ' data-task-id="$id"'}><p>${text()}</p>'
        '$nested</li>';
  }
}
