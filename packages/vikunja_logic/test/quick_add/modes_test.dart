import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

void main() {
  group('quickAddPrefixes', () {
    test('vikunja: * + ! @', () {
      expect(quickAddPrefixes(QuickAddMagicMode.vikunja), (
        label: '*',
        project: '+',
        priority: '!',
        assignee: '@',
      ));
    });

    test('todoist: @ # ! +', () {
      expect(quickAddPrefixes(QuickAddMagicMode.todoist), (
        label: '@',
        project: '#',
        priority: '!',
        assignee: '+',
      ));
    });

    test('disabled: none', () {
      expect(quickAddPrefixes(QuickAddMagicMode.disabled), isNull);
    });
  });

  test('returns text with no intents as is', () {
    final result = parse('Lorem Ipsum');
    expect(result, const ParsedTaskText(text: 'Lorem Ipsum'));
  });

  test('ignores email addresses', () {
    expect(
      parse('Lorem Ipsum email@example.com'),
      const ParsedTaskText(text: 'Lorem Ipsum email@example.com'),
    );
  });

  test('parses nothing when disabled, not even trimming', () {
    const text = ' Lorem Ipsum today *label +project !2 @user every day ';
    expect(
      parse(text, mode: QuickAddMagicMode.disabled),
      const ParsedTaskText(text: text),
    );
  });

  group('todoist mode', () {
    test('the web vector', () {
      final result = parse(
        'Lorem Ipsum today @label #project !2 +user',
        mode: QuickAddMagicMode.todoist,
      );
      expect(result.text, 'Lorem Ipsum  +user');
      expect(ymd(result.date), '2021-6-24');
      expect(result.labels, ['label']);
      expect(result.project, 'project');
      expect(result.priority, 2);
      expect(result.assignees, ['user']);
    });

    test('vikunja prefixes mean something else there', () {
      final result = parse(
        'Lorem *label +project',
        mode: QuickAddMagicMode.todoist,
      );
      expect(result.text, 'Lorem *label +project');
      expect(result.labels, isEmpty);
      expect(result.project, isNull);
      expect(result.assignees, ['project']);
    });

    test('quoted items and a time after @', () {
      final result = parse(
        "Call @'with space' #\"my project\" tomorrow @ 15:00",
        mode: QuickAddMagicMode.todoist,
      );
      expect(result.text, 'Call');
      expect(result.labels, ['with space']);
      expect(result.project, 'my project');
      expect(result.date, DateTime(2021, 6, 25, 15));
    });
  });

  group('quote-escaped text', () {
    test('double quotes skip all parsing', () {
      expect(
        parse('"delete mails up to january 30th"'),
        const ParsedTaskText(text: 'delete mails up to january 30th'),
      );
    });

    test('single quotes skip all parsing', () {
      expect(
        parse("'buy mass tomorrow *label !2 @user'"),
        const ParsedTaskText(text: 'buy mass tomorrow *label !2 @user'),
      );
    });

    test('unmatched quotes are parsed', () {
      expect(parse('"delete mails today').date, isNotNull);
    });

    test('mismatched quote types are parsed', () {
      expect(parse('"delete mails today\'').date, isNotNull);
    });

    test('quotes in the middle are parsed', () {
      final result = parse('delete "mails" today');
      expect(result.date, isNotNull);
      expect(result.text, 'delete "mails"');
    });

    test('an empty quoted string', () {
      expect(parse('""'), const ParsedTaskText(text: ''));
    });

    test('a lone quote is text', () {
      expect(parse('"'), const ParsedTaskText(text: '"'));
    });

    test('the inner text is kept as is, spaces included', () {
      expect(parse('" today "'), const ParsedTaskText(text: ' today '));
    });

    test('a leading space means it is not quoted', () {
      expect(parse(' "a" ').text, '"a"');
    });

    test('also in todoist mode', () {
      expect(
        parse('"task today @label #project"', mode: QuickAddMagicMode.todoist),
        const ParsedTaskText(text: 'task today @label #project'),
      );
    });

    test('also in disabled mode, as on the web', () {
      expect(
        parse('"task today"', mode: QuickAddMagicMode.disabled),
        const ParsedTaskText(text: 'task today'),
      );
    });
  });

  test('a UTC now counts as the local time it stands for', () {
    final local = DateTime(2021, 6, 24, 12);
    expect(
      parseTaskText('x tomorrow', now: local.toUtc()).date,
      parseTaskText('x tomorrow', now: local).date,
    );
  });

  test('values are comparable', () {
    expect(parse('x *a tomorrow every day'), parse('x *a tomorrow every day'));
    expect(
      parse('x *a tomorrow every day').hashCode,
      parse('x *a tomorrow every day').hashCode,
    );
    expect(parse('x *a'), isNot(parse('x *b')));
  });
}
