import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';

void main() {
  test('one line is taken as typed', () {
    expect(splitQuickAddLines('  - Buy milk  '), ['  - Buy milk  ']);
    expect(splitQuickAddLines('*label'), ['*label']);
    expect(splitQuickAddLines('\n\n  Buy milk\n  \n'), ['  Buy milk']);
  });

  test('blank text is no line', () {
    expect(splitQuickAddLines(''), isEmpty);
    expect(splitQuickAddLines(' \n\t\r\n '), isEmpty);
  });

  test('several lines lose indentation and list markers', () {
    expect(
      splitQuickAddLines(
        '  - One\n    * Two *label\n  + Three\n  [ ] Four\n'
        '  - [ ] Five\n  Six +project',
      ),
      ['One', 'Two *label', 'Three', 'Four', 'Five', 'Six +project'],
    );
  });

  test('every kind of line break', () {
    expect(splitQuickAddLines('One\r\nTwo\rThree\nFour'), [
      'One',
      'Two',
      'Three',
      'Four',
    ]);
  });

  test('a prefix without a space is no marker', () {
    expect(splitQuickAddLines('*label task\n+project task\n-1 degrees'), [
      '*label task',
      '+project task',
      '-1 degrees',
    ]);
  });

  test('a line that is only a marker is dropped', () {
    expect(splitQuickAddLines('- One\n- \n* [ ] \nTwo'), ['One', 'Two']);
  });

  group('quickAddTaskLines', () {
    test('one line is one task without a parent, as typed', () {
      expect(quickAddTaskLines('  - Buy milk'), [
        const IndentedLine(text: '  - Buy milk'),
      ]);
    });

    test('indented lines are subtasks of the nearest line above with less '
        'indent and inherit its project', () {
      expect(quickAddTaskLines('Car +Garage\n  - Tyres\n    Valves\nShop'), [
        const IndentedLine(text: 'Car +Garage'),
        const IndentedLine(
          text: 'Tyres',
          parentIndex: 0,
          inheritedProject: 'Garage',
        ),
        const IndentedLine(
          text: 'Valves',
          parentIndex: 1,
          inheritedProject: 'Garage',
        ),
        const IndentedLine(text: 'Shop'),
      ]);
    });

    test('the project inherits in the prefix of the mode', () {
      expect(
        quickAddTaskLines(
          'Car #Garage\n  Tyres',
          mode: QuickAddMagicMode.todoist,
        ).last.inheritedProject,
        'Garage',
      );
    });

    test('the count of tasks is the count of titles', () {
      const text = '- One\n  - Two\n- \n    Three';

      expect(quickAddTaskLines(text).length, splitQuickAddLines(text).length);
    });
  });
}
