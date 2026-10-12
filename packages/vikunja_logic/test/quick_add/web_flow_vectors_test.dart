import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

// What the web's task.test.ts and useQuickAddTask.test.ts feed the parser,
// and the research's probes of the web's false positives.
void main() {
  group('task.test.ts', () {
    test('only resolved assignees are cleaned, labels stay parsed', () {
      final parsed = parse('Task @alice @missing *label');
      expect(parsed.text, 'Task @alice @missing');
      expect(parsed.labels, ['label']);
      expect(parsed.assignees, ['alice', 'missing']);
      expect(cleanupItemText(parsed.text, ['alice'], '@'), 'Task @missing');
    });

    test('a magic-only title parses to no text', () {
      expect(parse(' *label ').text, '');
    });
  });

  group('useQuickAddTask.test.ts', () {
    test('a matched assignee is stripped from the title', () {
      final parsed = parse('Buy milk @jane');
      expect(parsed.assignees, ['jane']);
      expect(cleanupItemText(parsed.text, ['jane'], '@').trim(), 'Buy milk');
    });

    test('a label to create', () {
      final parsed = parse('Buy milk *Urgent');
      expect(parsed.text, 'Buy milk');
      expect(parsed.labels, ['Urgent']);
    });

    test('a title that is only magic', () {
      expect(parse('*Urgent').text, '');
      expect(parse('+Other').text, '');
    });

    test('several lines with the same label', () {
      for (final line in ['One *Urgent', 'Two *Urgent', 'Three *Urgent']) {
        expect(parse(line).labels, ['Urgent'], reason: line);
      }
    });
  });

  group('the research probes (client-logic.md 1.8)', () {
    test('D19-3: Read todays paper stays text', () {
      // The web: today, "Read s paper".
      expect(
        parse('Read todays paper'),
        const ParsedTaskText(text: 'Read todays paper'),
      );
    });

    test('D19-3: Plan next weekend trip stays text', () {
      // The web: next week, "Plan end trip".
      expect(
        parse('Plan next weekend trip'),
        const ParsedTaskText(text: 'Plan next weekend trip'),
      );
    });

    test('D19-4: buy 12 decorations stays text', () {
      // The web: Dec 12, "buy orations".
      expect(
        parse('buy 12 decorations'),
        const ParsedTaskText(text: 'buy 12 decorations'),
      );
    });

    test('D38-5: Something sep 17th on Oct 8 is Sep 17, in the past', () {
      expect(
        parse('Something sep 17th', now: DateTime(2026, 10, 8, 10, 30, 12)),
        ParsedTaskText(
          text: 'Something',
          date: DateTime(2026, 9, 17, 12),
          datePhrases: const ['17th', 'sep'],
        ),
      );
    });

    test('x 29th feb in 2026 is Mar 1 (web parity)', () {
      expect(
        ymd(parse('x 29th feb', now: DateTime(2026, 10, 8, 10)).date),
        '2026-3-1',
      );
    });

    test('D38-6: next monday on a Monday is today', () {
      final monday = DateTime(2026, 10, 12, 10, 30);
      expect(
        parse('x next monday', now: monday).date,
        DateTime(2026, 10, 12, 12),
      );
    });

    test('the quote escape keeps a date phrase as text', () {
      expect(parse('"delete mails up to january 30th"').date, isNull);
    });
  });
}
