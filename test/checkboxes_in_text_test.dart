import 'package:test/test.dart';
import 'package:vikunja_app/core/utils/checkboxes_in_text.dart';

void main() {
  group('Checkbox parsing tests', () {
    group('getCheckboxesInText', () {
      test('Empty text should return no checkboxes', () {
        final result = getCheckboxesInText('');
        expect(result.checked.isEmpty, true);
        expect(result.unchecked.isEmpty, true);
      });

      test('Text with no checkboxes should return no matches', () {
        final result =
            getCheckboxesInText('This is regular text without checkboxes');
        expect(result.checked.isEmpty, true);
        expect(result.unchecked.isEmpty, true);
      });

      test('Text with checked checkboxes should return checked matches', () {
        final text = '''
        - [x] Completed task 1
        * [x] Completed task 2
        - [x] Another completed task
        ''';
        final result = getCheckboxesInText(text);
        expect(result.checked.length, 3);
        expect(result.unchecked.length, 0);
      });

      test('Text with unchecked checkboxes should return unchecked matches',
          () {
        final text = '''
        - [ ] Uncompleted task 1
        * [ ] Uncompleted task 2
        - [ ] Another uncompleted task
        ''';
        final result = getCheckboxesInText(text);
        expect(result.checked.length, 0);
        expect(result.unchecked.length, 3);
      });

      test('Text with mixed checkboxes should return correct matches', () {
        final text = '''
        - [x] Completed task
        - [ ] Uncompleted task 1
        * [x] Another completed task
        * [ ] Uncompleted task 2
        - [ ] Uncompleted task 3
        ''';
        final result = getCheckboxesInText(text);
        expect(result.checked.length, 2);
        expect(result.unchecked.length, 3);
      });

      test('Should handle different bullet point styles', () {
        final text = '''
        - [x] Dash with checked
        * [x] Asterisk with checked
        - [ ] Dash with unchecked
        * [ ] Asterisk with unchecked
        ''';
        final result = getCheckboxesInText(text);
        expect(result.checked.length, 2);
        expect(result.unchecked.length, 2);
      });

      test('Should ignore malformed checkboxes', () {
        final text = '''
        - [x] Valid checked
        - [ ] Valid unchecked
        - [y] Invalid checkbox
        - [] Missing space
        [x] Missing bullet
        ''';
        final result = getCheckboxesInText(text);
        expect(result.checked.length, 1);
        expect(result.unchecked.length, 1);
      });
    });

    group('getCheckboxStatistics', () {
      test('Empty text should return zero statistics', () {
        final stats = getCheckboxStatistics('');
        expect(stats.total, 0);
        expect(stats.checked, 0);
      });

      test('Text with only checked boxes should return correct stats', () {
        final text = '''
        - [x] Task 1
        - [x] Task 2
        * [x] Task 3
        ''';
        final stats = getCheckboxStatistics(text);
        expect(stats.total, 3);
        expect(stats.checked, 3);
      });

      test('Text with only unchecked boxes should return correct stats', () {
        final text = '''
        - [ ] Task 1
        - [ ] Task 2
        * [ ] Task 3
        ''';
        final stats = getCheckboxStatistics(text);
        expect(stats.total, 3);
        expect(stats.checked, 0);
      });

      test('Text with mixed checkboxes should return correct stats', () {
        final text = '''
        - [x] Completed task 1
        - [ ] Uncompleted task 1
        - [x] Completed task 2
        * [ ] Uncompleted task 2
        * [ ] Uncompleted task 3
        - [x] Completed task 3
        ''';
        final stats = getCheckboxStatistics(text);
        expect(stats.total, 6);
        expect(stats.checked, 3);
      });

      test('Should handle text with other content mixed in', () {
        final text = '''
        This is a task description.
        
        - [x] Completed subtask
        - [ ] Pending subtask
        
        Some more text here.
        
        * [x] Another completed task
        
        Final notes.
        ''';
        final stats = getCheckboxStatistics(text);
        expect(stats.total, 3);
        expect(stats.checked, 2);
      });
    });

    group('CheckboxStatistics class', () {
      test('Should create instance with correct values', () {
        final stats = CheckboxStatistics(total: 5, checked: 3);
        expect(stats.total, 5);
        expect(stats.checked, 3);
      });
    });

    group('MatchedCheckboxes class', () {
      test('Should create instance with correct collections', () {
        final checked = <Match>[];
        final unchecked = <Match>[];
        final matched =
            MatchedCheckboxes(checked: checked, unchecked: unchecked);
        expect(matched.checked, checked);
        expect(matched.unchecked, unchecked);
      });
    });
  });
}
