import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

typedef _Row = (String title, String? parent);

/// Each line as its title and its parent's title, the way the web's tests
/// state them.
List<_Row> _rows(String text) {
  final lines = parseSubtasksViaIndention(text);
  return [
    for (final line in lines)
      (
        line.text,
        line.parentIndex == null ? null : lines[line.parentIndex!].text,
      ),
  ];
}

void main() {
  // The vectors of the web's parseSubtasksViaIndention.test.ts.
  group('parseSubtasksViaIndention.test.ts', () {
    test('a single task has no parent', () {
      expect(_rows('single task'), [('single task', null)]);
    });

    test('several tasks without indentation have no parent', () {
      expect(_rows('task one\ntask two'), [
        ('task one', null),
        ('task two', null),
      ]);
    });

    test('two tasks with indentation', () {
      expect(_rows('parent task\n  sub task'), [
        ('parent task', null),
        ('sub task', 'parent task'),
      ]);
    });

    test('several subtasks', () {
      expect(_rows('parent task\n  sub task one\n  sub task two'), [
        ('parent task', null),
        ('sub task one', 'parent task'),
        ('sub task two', 'parent task'),
      ]);
    });

    test('several levels', () {
      expect(_rows('parent task\n  sub task\n    sub sub task'), [
        ('parent task', null),
        ('sub task', 'parent task'),
        ('sub sub task', 'sub task'),
      ]);
    });

    test('several levels with several tasks', () {
      expect(
        _rows(
          'parent task\n'
          '  sub task\n'
          '    sub sub task one\n'
          '    sub sub task two',
        ),
        [
          ('parent task', null),
          ('sub task', 'parent task'),
          ('sub sub task one', 'sub task'),
          ('sub sub task two', 'sub task'),
        ],
      );
    });

    test('four levels, back up to the third', () {
      expect(
        _rows(
          'parent task\n'
          '  sub task\n'
          '    sub sub task one\n'
          '      sub sub sub task\n'
          '    sub sub task two',
        ),
        [
          ('parent task', null),
          ('sub task', 'parent task'),
          ('sub sub task one', 'sub task'),
          ('sub sub sub task', 'sub sub task one'),
          ('sub sub task two', 'sub task'),
        ],
      );
    });

    test('list markers are stripped', () {
      expect(_rows('* parent task\n  * sub task one\n  sub task two'), [
        ('parent task', null),
        ('sub task one', 'parent task'),
        ('sub task two', 'parent task'),
      ]);
    });

    test('an indented first line alone', () {
      expect(_rows('  single task'), [('single task', null)]);
    });

    test("the parent's project goes to every subtask", () {
      final lines = parseSubtasksViaIndention(
        'parent task +list\n  sub task 1\n  sub task 2',
      );

      expect(lines, [
        const IndentedLine(text: 'parent task +list'),
        const IndentedLine(
          text: 'sub task 1',
          parentIndex: 0,
          inheritedProject: 'list',
        ),
        const IndentedLine(
          text: 'sub task 2',
          parentIndex: 0,
          inheritedProject: 'list',
        ),
      ]);
    });

    test("the first line's indentation is cut from every line", () {
      expect(_rows('  parent task\n  sub task one\n    sub task two'), [
        ('parent task', null),
        ('sub task one', null),
        ('sub task two', 'sub task one'),
      ]);
    });

    test('a later line without indentation stops the cut', () {
      expect(
        _rows(
          '  parent task\n'
          '  sub task one\n'
          'first level task one\n'
          '  sub task two',
        ),
        [
          ('parent task', null),
          ('sub task one', null),
          ('first level task one', null),
          ('sub task two', 'first level task one'),
        ],
      );
    });

    test('a later line with less indentation lowers the cut', () {
      expect(
        _rows(
          '  parent task\n'
          '  sub task one\n'
          ' first level task one\n'
          '   sub task two',
        ),
        [
          ('parent task', null),
          ('sub task one', null),
          ('first level task one', null),
          ('sub task two', 'first level task one'),
        ],
      );
    });
  });

  group('lines', () {
    test('no text, no lines', () {
      expect(parseSubtasksViaIndention(''), isEmpty);
      expect(parseSubtasksViaIndention('  \n\t\n'), isEmpty);
    });

    test('blank lines, CR LF and CR are line breaks and drop out', () {
      expect(_rows('parent\r\n\r\n  child\r  \r\n  sibling\n\n'), [
        ('parent', null),
        ('child', 'parent'),
        ('sibling', 'parent'),
      ]);
    });

    test('a subtask indented less than its predecessor finds the nearest '
        'line with less indent', () {
      expect(_rows('parent\n    deep\n  shallow'), [
        ('parent', null),
        ('deep', 'parent'),
        ('shallow', 'parent'),
      ]);
    });

    test('the parent is the line by position, also among equal titles', () {
      final lines = parseSubtasksViaIndention('Same\n  Child\nSame\n  Child');

      expect([for (final line in lines) line.parentIndex], [null, 0, null, 2]);
    });

    test('the text keeps everything after the marker as typed', () {
      expect(_rows('Buy milk  \n  Oat *shopping !2 '), [
        ('Buy milk  ', null),
        ('Oat *shopping !2 ', 'Buy milk  '),
      ]);
    });

    test('the result cannot be changed', () {
      expect(
        () => parseSubtasksViaIndention('a').add(const IndentedLine(text: 'b')),
        throwsUnsupportedError,
      );
    });
  });

  group('list markers', () {
    final cases = <(String, String)>[
      ('- task', 'task'),
      ('* task', 'task'),
      ('+ task', 'task'),
      ('- [ ] task', 'task'),
      ('* [ ] task', 'task'),
      ('+ [ ] task', 'task'),
      ('[ ] task', 'task'),
      ('- - task', '- task'),
      ('-task', '-task'),
      ('[x] task', '[x] task'),
      ('- [x] task', '[x] task'),
      ('-  task', ' task'),
    ];

    for (final (line, text) in cases) {
      test('"$line" is "$text"', () {
        expect(_rows('$line\n  child'), [(text, null), ('child', text)]);
      });
    }

    test('a marker after the indent of a subtask is stripped', () {
      expect(_rows('- parent\n  - [ ] child\n    + grandchild'), [
        ('parent', null),
        ('child', 'parent'),
        ('grandchild', 'child'),
      ]);
    });

    test('a line that is only a marker is no task; its subtasks move up to '
        'its parent', () {
      expect(_rows('parent\n  a\n  - \n    child\n  b'), [
        ('parent', null),
        ('a', 'parent'),
        ('child', 'parent'),
        ('b', 'parent'),
      ]);
      expect(_rows('- \n  child\nnext'), [('child', null), ('next', null)]);
    });

    test('a line that is only a marker is no task and no parent', () {
      expect(_rows('parent\n  - \n    child\n- [ ] \n[ ] '), [
        ('parent', null),
        ('child', 'parent'),
      ]);
    });
  });

  group('tabs count as four spaces', () {
    test('tab-indented levels', () {
      expect(_rows('parent\n\tchild\n\t\tgrandchild\n\tsibling'), [
        ('parent', null),
        ('child', 'parent'),
        ('grandchild', 'child'),
        ('sibling', 'parent'),
      ]);
    });

    test('a tab and four spaces are the same level', () {
      expect(_rows('parent\n\tchild\n    sibling\n  \t  grandchild'), [
        ('parent', null),
        ('child', 'parent'),
        ('sibling', 'parent'),
        ('grandchild', 'sibling'),
      ]);
    });

    test("a tab on the first line is cut like the web's", () {
      expect(_rows('\tparent\n\t\tchild\n\tsibling'), [
        ('parent', null),
        ('child', 'parent'),
        ('sibling', null),
      ]);
    });
  });

  group('projects', () {
    test('a subtask with its own project inherits nothing', () {
      final lines = parseSubtasksViaIndention('Parent +home\n  Child +work');

      expect(lines[1].inheritedProject, isNull);
    });

    test('grandchildren inherit through their parent', () {
      final lines = parseSubtasksViaIndention(
        'Parent +home\n'
        '  Child\n'
        '    Grandchild\n'
        '  Other +work\n'
        '    Its child',
      );

      expect(
        [for (final line in lines) line.inheritedProject],
        [null, 'home', 'home', null, 'work'],
      );
    });

    test('inheritance passes a line that is only a marker', () {
      final lines = parseSubtasksViaIndention(
        'Parent +home\n  -\x20\n    Child',
      );

      expect(
        lines[1],
        const IndentedLine(
          text: 'Child',
          parentIndex: 0,
          inheritedProject: 'home',
        ),
      );
    });

    test('top-level lines never inherit', () {
      final lines = parseSubtasksViaIndention('First +home\nSecond');

      expect(lines[1].inheritedProject, isNull);
    });

    test('a quoted project name is inherited without the quotes', () {
      final lines = parseSubtasksViaIndention("Parent +'Big house'\n  Child");

      expect(lines[1].inheritedProject, 'Big house');
    });

    test("todoist mode reads the parent's #project", () {
      final lines = parseSubtasksViaIndention(
        'Parent #home +list\n  Child',
        mode: QuickAddMagicMode.todoist,
      );

      expect(lines[1].inheritedProject, 'home');
    });

    test('with magic disabled nothing is inherited', () {
      final lines = parseSubtasksViaIndention(
        'Parent +home\n  Child',
        mode: QuickAddMagicMode.disabled,
      );

      expect(lines[1], const IndentedLine(text: 'Child', parentIndex: 0));
    });

    test('a project inside a quoted title is no project', () {
      final lines = parseSubtasksViaIndention('"Fix +home"\n  Child');

      expect(lines[1].inheritedProject, isNull);
    });
  });

  group('parseQuickAddProject', () {
    final now = DateTime(2021, 6, 24, 12);

    for (final (text, mode) in [
      ('Buy milk +home', QuickAddMagicMode.vikunja),
      ("Buy milk +'Big house' tomorrow", QuickAddMagicMode.vikunja),
      ('+home', QuickAddMagicMode.vikunja),
      ('Buy milk', QuickAddMagicMode.vikunja),
      ('"Buy +milk"', QuickAddMagicMode.vikunja),
      ("*'a +b' rest", QuickAddMagicMode.vikunja),
      ('Buy milk +home +work', QuickAddMagicMode.vikunja),
      ('Buy milk #home @label', QuickAddMagicMode.todoist),
      ('Buy milk +home', QuickAddMagicMode.todoist),
      ('Buy milk +home', QuickAddMagicMode.disabled),
    ]) {
      test('agrees with parseTaskText: "$text" in $mode', () {
        expect(
          parseQuickAddProject(text, mode: mode),
          parseTaskText(text, now: now, mode: mode).project,
        );
      });
    }
  });
}
