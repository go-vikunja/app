// The fixtures keep the web's lines.
// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

// The fixtures of the web's checklistFromText.test.ts, byte for byte (tabs,
// and the continuation line of a checked item indented with tabs and three
// spaces), so that the offsets match.
const _f1 = 'Lorem Ipsum';

const _f2 =
    '\n'
    '<ul data-type="taskList">\n'
    '\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Task</p></div>\n'
    '\t</li>\n'
    '\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Another task</p>\n'
    '\t\t\t<ul data-type="taskList">\n'
    '\t\t\t\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t\t\t\t<div><p>subtask</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t\t<li data-checked="true" data-type="taskItem"><label><input type="checkbox"\n'
    '\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t   checked="checked"><span></span></label>\n'
    '\t\t\t\t\t<div><p>done</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t</ul>\n'
    '\t\t</div>\n'
    '\t</li>\n'
    '</ul>';

const _f3 =
    '\n'
    '<ul data-type="taskList">\n'
    '\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Task</p></div>\n'
    '\t</li>\n'
    '</ul>';

const _f4 =
    '\n'
    '<ul data-type="taskList">\n'
    '\t<li data-checked="true" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Task</p></div>\n'
    '\t</li>\n'
    '</ul>';

const _f5 =
    '\n'
    '<ul data-type="taskList">\n'
    '\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Task</p></div>\n'
    '\t</li>\n'
    '\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t<div><p>Another task</p>\n'
    '\t\t\t<ul data-type="taskList">\n'
    '\t\t\t\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t\t\t\t<div><p>subtask</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t\t<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label>\n'
    '\t\t\t\t\t<div><p>subtask 2</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t\t<li data-checked="true" data-type="taskItem"><label><input type="checkbox"\n'
    '\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t   checked="checked"><span></span></label>\n'
    '\t\t\t\t\t<div><p>done</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t\t<li data-checked="true" data-type="taskItem"><label><input type="checkbox"\n'
    '\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t   checked="checked"><span></span></label>\n'
    '\t\t\t\t\t<div><p>also done</p></div>\n'
    '\t\t\t\t</li>\n'
    '\t\t\t</ul>\n'
    '\t\t</div>\n'
    '\t</li>\n'
    '</ul>';

void main() {
  test('the fixtures have the lengths of the web test file', () {
    expect(
      [_f2.length, _f3.length, _f4.length, _f5.length],
      [664, 163, 162, 992],
    );
  });

  group('findCheckboxesInText', () {
    test('F1 no checkbox', () {
      expect(findCheckboxesInText(_f1), isEmpty);
    });

    test('F2 multiple checkboxes, nested ones included', () {
      expect(findCheckboxesInText(_f2), [32, 163, 321, 464]);
    });

    test('F3 one unchecked checkbox', () {
      expect(findCheckboxesInText(_f3), [32]);
    });

    test('F4 one checked checkbox', () {
      expect(findCheckboxesInText(_f4), [32]);
    });

    test('F5 checked and unchecked merged in text order', () {
      expect(findCheckboxesInText(_f5), [32, 163, 321, 464, 609, 787]);
    });
  });

  group('checklistStatistics', () {
    test('F1 no checkbox', () {
      final stats = checklistStatistics(_f1);
      expect(stats.total, 0);
      expect(stats.isEmpty, isTrue);
      expect(stats.allDone, isFalse);
    });

    test('F2', () {
      expect(
        checklistStatistics(_f2),
        const ChecklistStatistics(total: 4, checked: 1),
      );
    });

    test('F3 one unchecked', () {
      final stats = checklistStatistics(_f3);
      expect(stats.total, 1);
      expect(stats.checked, 0);
      expect(stats.allDone, isFalse);
    });

    test('F4 one checked', () {
      final stats = checklistStatistics(_f4);
      expect(stats.total, 1);
      expect(stats.checked, 1);
      expect(stats.allDone, isTrue);
    });

    test('F5 multiple mixed and matched', () {
      final stats = checklistStatistics(_f5);
      expect(stats.total, 6);
      expect(stats.checked, 2);
      expect(stats.isEmpty, isFalse);
    });

    test('only the exact attribute counts', () {
      expect(
        checklistStatistics(
          '<li data-checked="TRUE"></li><li data-checked=true></li> '
          "<li data-checked='false'></li><li data-checked=\"false\"></li>",
        ),
        const ChecklistStatistics(total: 1),
      );
    });

    test('the empty description', () {
      expect(checklistStatistics(''), const ChecklistStatistics());
      expect(checklistStatistics('<p></p>').isEmpty, isTrue);
    });
  });
}
