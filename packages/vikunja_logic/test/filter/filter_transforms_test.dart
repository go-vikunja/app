import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/src/filter/web_conditions.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

const _lookups = LookupTables(
  labels: {
    1: 'Work',
    2: 'R&D',
    3: 'a, b',
    4: "'Quoted'",
    5: "Mary's",
    6: ' padded ',
    7: '(paren)',
    8: 'x"y\'z&',
    9: 'work',
    10: '5',
  },
  projects: {11: 'Inbox', 12: 'My Project', 13: 'Q&A'},
);

String _forApi(String text) => filterForApi(text, lookups: _lookups);
String _fromApi(String text) => filterFromApi(text, lookups: _lookups);

void main() {
  group('filterForApi', () {
    test('canonicalises known fields in any case, then snake_cases them', () {
      expect(
        _forApi('DUEDATE > now && Labels = work && createdby = anna'),
        'due_date > now && labels = 1 && created_by = anna',
      );
    });

    test('leaves snake_case and unknown fields alone', () {
      expect(_forApi('due_date > now'), 'due_date > now');
      expect(_forApi('project_id = Inbox'), 'project_id = Inbox');
      expect(_forApi('identifier = x'), 'identifier = x');
    });

    test('resolves the first title equal ignoring case', () {
      expect(_forApi('labels = WORK'), 'labels = 1');
      expect(
        _forApi('project = my project && done = false'),
        'project = 12 && done = false',
      );
    });

    test('list items one by one, unresolved ones as typed', () {
      expect(_forApi('labels in work, R&D'), 'labels in work, R&D');
      expect(_forApi('labels in Work, Nope'), 'labels in 1, Nope');
      expect(
        _forApi('labels not in "Work", \'Quoted\''),
        'labels not in 1, Quoted',
      );
    });

    test('leaves an empty value alone', () {
      expect(_forApi("labels = ''"), "labels = ''");
      expect(_fromApi("labels = ''"), "labels = ''");
      expect(_fromApi('  '), '');
    });

    test('strips enclosing quotes from list items, all quotes after', () {
      expect(_forApi('labels in "Work\', work'), 'labels in Work, 1');
      expect(_forApi('labels in " Work "'), 'labels in 1');
    });

    test('strips quotes from label and project values', () {
      expect(_forApi("labels = 'Nope'"), 'labels = Nope');
      expect(_forApi('project = "Inbox"'), 'project = 11');
    });

    test('keeps >= and <= whole, unlike the web', () {
      expect(_forApi('labels >= work'), 'labels >= 1');
      expect(_forApi('project <= inbox'), 'project <= 11');
    });

    test('trims, and keeps nothing for blanks', () {
      expect(_forApi('  done = false  '), 'done = false');
      expect(_forApi('   '), '');
      expect(_forApi(''), '');
    });
  });

  group('filterFromApi', () {
    test('camelCases fields only where an operator follows', () {
      expect(
        _fromApi('due_date < now && created_by_id = 3 && title = due_date'),
        'dueDate < now && created_by_id = 3 && title = due_date',
      );
    });

    test('shows titles that come back to the same id', () {
      expect(_fromApi('labels = 1'), 'labels = Work');
      expect(_fromApi('labels in 1, 10'), 'labels in Work, 5');
      expect(_fromApi('project = 12'), 'project = My Project');
      expect(_fromApi('labels = 3'), 'labels = a, b');
    });

    test('quotes a single title the bare form would break', () {
      expect(_fromApi('labels = 2'), 'labels = "R&D"');
      expect(_fromApi('labels = 4'), 'labels = "\'Quoted\'"');
      expect(_fromApi('project = 13'), 'project = "Q&A"');
    });

    test('reads quoted ids too, as the web does', () {
      expect(_fromApi('labels = "1"'), 'labels = Work');
      expect(_fromApi("labels in '1', 10"), 'labels in Work, 5');
      expect(_fromApi("labels = 'x'"), 'labels = x');
    });

    test('keeps ids it cannot show safely', () {
      // A case-insensitive twin, blanks around, both quote kinds, a list
      // breaker.
      expect(_fromApi('labels = 9'), 'labels = 9');
      expect(_fromApi('labels = 6'), 'labels = 6');
      expect(_fromApi('labels = 8'), 'labels = 8');
      expect(_fromApi('labels in 1, 2, 3'), 'labels in Work, 2, 3');
      expect(_fromApi('labels = 99'), 'labels = 99');
    });
  });

  group('a stored filter survives the round trip through the builder', () {
    for (final filter in [
      'labels = 1',
      'labels = 2',
      'labels = 3',
      'labels = 4',
      'labels = 5',
      'labels = 6',
      'labels = 7',
      'labels = 8',
      'labels = 9',
      'labels = 10',
      'labels in 1, 2, 3',
      'labels not in 4, 5, 6, 7, 8, 9, 10',
      'project = 11 && labels in 1, 10',
      'project in 12, 13',
      '(project = 13 || labels = 2) && done = false',
      'due_date < now/d && percent_done > 0.5 && created_by = anna',
    ]) {
      test(filter, () {
        expect(_forApi(_fromApi(filter)), filter);
      });
    }
  });

  group('ids nothing here has a title for', () {
    test('are the numbers filterFromApi keeps', () {
      final ids = untitledFilterIds(
        'labels in 1, 9, 99 && project = 42 && labels != 6 && project in 11, 7',
        lookups: _lookups,
      );
      expect(ids.labels, {9, 99, 6});
      expect(ids.projects, {42, 7});
      expect(
        untitledFilterIds(
          'labels = 1 && project = 12',
          lookups: _lookups,
        ).labels,
        isEmpty,
      );
    });

    test('stay ids through an edit, even where a title is that number', () {
      // Label 10 is titled "5"; label 5 is not stored here.
      const lookups = LookupTables(labels: {10: '5', 1: 'Work'});
      const stored = 'labels = 5 && done = false';
      final shown = filterFromApi(stored, lookups: lookups);
      expect(shown, 'labels = 5 && done = false');
      final keep = untitledFilterIds(stored, lookups: lookups);
      final edited = shown.replaceFirst('false', 'true');
      expect(
        filterForApi(edited, lookups: lookups, keepIds: keep),
        'labels = 5 && done = true',
      );
      expect(
        filterForApi('labels in 5, Work', lookups: lookups, keepIds: keep),
        'labels in 5, 1',
      );
      expect(
        filterForApi(edited, lookups: lookups),
        'labels = 10 && done = true',
      );
    });

    test('a kept number in a project condition too', () {
      const lookups = LookupTables(projects: {3: '42'});
      const keep = FilterIds(projects: {42});
      expect(
        filterForApi('project = 42', lookups: lookups, keepIds: keep),
        'project = 42',
      );
      expect(filterForApi('project = 42', lookups: lookups), 'project = 3');
    });
  });

  group("the web's condition pattern", () {
    // The pattern as a JavaScript regex, the reference the hand-written
    // matcher follows.
    RegExp pattern(String field) => RegExp(
      '\\b($field)\\s*'
      r'(!=|>=|<=|=|>|<|\blike\b|\bnot in\b|\bin\b|\?=)\s*'
      '(?:(["\'])((?:\\\\.|(?!\\3)[^\\\\])*?)\\3|([^&|()<]+?))'
      r'(?=\s*(?:&&|\||\)|$))',
    );

    test('matches like the regex on random input', () {
      const alphabet = [
        'labels',
        'labels',
        'project',
        ' ',
        ' ',
        '\t',
        ' ',
        '=',
        '>',
        '<',
        '!',
        '?',
        'in',
        'not in',
        'like',
        '&',
        '&&',
        '|',
        '(',
        ')',
        '"',
        "'",
        r'\',
        '\n',
        'a',
        'B',
        ',',
        '_',
      ];
      final random = Random(51);
      String pick(List<String> from) => from[random.nextInt(from.length)];
      String junk(int most) =>
          [for (var i = random.nextInt(most); i > 0; i--) pick(alphabet)]
              .join();
      String condition() => [
        pick(['labels', 'project', 'xlabels', 'labels_']),
        junk(2).replaceAll(RegExp('[^ \t\u00a0]'), ''),
        pick(['=', '!=', '>=', 'in', ' in ', 'not in ', 'like', '?=', '<']),
        junk(5),
        pick(['', ' && ', '||', ')', ' ', '&', '(']),
      ].join();
      var matched = 0;
      for (var round = 0; round < 30000; round++) {
        // Mostly condition-shaped pieces, so that many of them match.
        final text = [
          for (var piece = 1 + random.nextInt(3); piece > 0; piece--)
            if (random.nextInt(4) == 0) junk(6) else condition(),
        ].join();
        for (final field in ['labels', 'project']) {
          final expected = [
            for (final match in pattern(field).allMatches(text))
              (
                match.start,
                match.end,
                match[2],
                match[4] ?? match[5],
                match[4] != null,
              ),
          ];
          final actual = [
            for (final condition in webConditions(text, field))
              (
                condition.start,
                condition.end,
                condition.operator,
                condition.value,
                condition.quoted,
              ),
          ];
          expect(actual, expected, reason: '$field in ${text.codeUnits}');
          matched += expected.length;
        }
      }
      expect(matched, greaterThan(1000));
    });

    test('long runs of blanks cost linear time', () {
      final stopwatch = Stopwatch()..start();
      _forApi('labels = ${' ' * 16000}x&');
      _fromApi('labels = ${' ' * 16000}x(');
      _forApi('labels = "a ' * 1500);

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
