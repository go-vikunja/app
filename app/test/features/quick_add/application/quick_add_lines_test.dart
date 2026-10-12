import 'package:flutter_test/flutter_test.dart';
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
}
