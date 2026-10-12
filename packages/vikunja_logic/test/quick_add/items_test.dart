import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

void main() {
  group('labels', () {
    test('parses labels', () {
      final result = parse('Lorem Ipsum *label1 *label2');
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['label1', 'label2']);
    });

    test('parses labels from the start', () {
      final result = parse('*label1 Lorem Ipsum *label2');
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['label1', 'label2']);
    });

    test('collapses duplicate labels', () {
      final result = parse('Lorem Ipsum *label1 *label1 *label2');
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['label1', 'label2']);
    });

    test("labels with spaces in '", () {
      final result = parse("Lorem *'label with space' Ipsum");
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['label with space']);
    });

    test('labels with spaces in "', () {
      final result = parse('Lorem *"label with space" Ipsum');
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['label with space']);
    });

    test('a label called like a date expression is a label', () {
      final result = parse('Lorem Ipsum *today');
      expect(result.text, 'Lorem Ipsum');
      expect(result.labels, ['today']);
      expect(result.date, isNull);
    });

    test('labels with parentheses are removed from the text', () {
      final result = parse('a *"a (a)"');
      expect(result.text, 'a');
      expect(result.labels, ['a (a)']);
    });

    test('labels with parentheses from the start', () {
      final result = parse('*"a (a)" a');
      expect(result.text, 'a');
      expect(result.labels, ['a (a)']);
    });

    test('a label alone leaves no text', () {
      final result = parse('*Urgent');
      expect(result.text, '');
      expect(result.labels, ['Urgent']);
    });

    test('the prefix needs the start or a space before it', () {
      expect(parse('x*label 5*3').labels, isEmpty);
    });

    test('a bare prefix is no label', () {
      expect(parse('x *').labels, isEmpty);
      expect(parse('x * y').text, 'x * y');
    });

    test('only the first prefix character is the prefix', () {
      final result = parse('**a x');
      expect(result.labels, ['*a']);
      expect(result.text, 'x');
    });

    test('an item runs to the next space only', () {
      expect(parse('x *a,b').labels, ['a,b']);
      expect(parse('x *a\ty').labels, ['a\ty']);
    });

    test('an unterminated quote runs to the end and stays in the text', () {
      final result = parse("x *'unterminated label");
      expect(result.labels, ['unterminated label']);
      expect(result.text, "x *'unterminated label");
    });

    test('labels differing in case are two labels, both removed', () {
      final result = parse('x *A *a');
      expect(result.labels, ['A', 'a']);
      expect(result.text, 'x');
    });

    test('web parity: removing a label also cuts it out of a longer one', () {
      final result = parse('x *a *abc');
      expect(result.labels, ['a', 'abc']);
      expect(result.text, 'x bc');
    });
  });

  group('project', () {
    test('parses a project', () {
      final result = parse('Lorem Ipsum +project');
      expect(result.text, 'Lorem Ipsum');
      expect(result.project, 'project');
    });

    test("a project with a space in '", () {
      final result = parse("Lorem Ipsum +'project with long name'");
      expect(result.text, 'Lorem Ipsum');
      expect(result.project, 'project with long name');
    });

    test('a project with a space in "', () {
      final result = parse('Lorem Ipsum +"project with long name"');
      expect(result.text, 'Lorem Ipsum');
      expect(result.project, 'project with long name');
    });

    test('only the first project counts; the others stay', () {
      final result = parse('Lorem Ipsum +project1 +project2 +project3');
      expect(result.text, 'Lorem Ipsum +project2 +project3');
      expect(result.project, 'project1');
    });

    test('a project called like a date is a project', () {
      final result = parse('Lorem Ipsum +today');
      expect(result.text, 'Lorem Ipsum');
      expect(result.project, 'today');
      expect(result.date, isNull);
    });

    test('a project from the start', () {
      final result = parse('+p x');
      expect(result.text, 'x');
      expect(result.project, 'p');
    });

    test('a project alone leaves no text', () {
      final result = parse('+Other');
      expect(result.text, '');
      expect(result.project, 'Other');
    });
  });

  group('priority', () {
    for (final priority in [0, 1, 2, 3, 4, 5]) {
      test('parses priority $priority', () {
        final result = parse('Lorem Ipsum !$priority');
        expect(result.text, 'Lorem Ipsum');
        expect(result.priority, priority);
      });
    }

    test('an invalid priority stays text', () {
      final result = parse('Lorem Ipsum !9999');
      expect(result.text, 'Lorem Ipsum !9999');
      expect(result.priority, isNull);
    });

    test('the first valid priority wins', () {
      final result = parse('Lorem Ipsum !9999 !1');
      expect(result.text, 'Lorem Ipsum !9999');
      expect(result.priority, 1);
    });

    test('!6 is not a priority', () {
      final result = parse('x !6');
      expect(result.text, 'x !6');
      expect(result.priority, isNull);
    });

    test('a priority from the start', () {
      final result = parse('!4 x');
      expect(result.text, 'x');
      expect(result.priority, 4);
    });

    test('a bare prefix is no priority', () {
      expect(parse('x ! 3').priority, isNull);
      expect(parse('x !').priority, isNull);
    });

    test('a negative number is no priority', () {
      expect(parse('x !-3').priority, isNull);
    });

    test('a huge number is no priority', () {
      expect(parse('x !99999999999999999999999').priority, isNull);
    });

    group('web parity: JS parseInt reads the leading number', () {
      test('!3abc is 3 and leaves abc', () {
        final result = parse('Lorem !3abc');
        expect(result.priority, 3);
        expect(result.text, 'Lorem abc');
      });

      test('!03 is 3 but stays in the text', () {
        final result = parse('Lorem !03 x');
        expect(result.priority, 3);
        expect(result.text, 'Lorem !03 x');
      });

      test('!+3 is 3 but stays in the text', () {
        final result = parse('Lorem !+3 x');
        expect(result.priority, 3);
        expect(result.text, 'Lorem !+3 x');
      });

      test('!-0 is 0', () {
        expect(parse('x !-0').priority, 0);
      });

      test("!' 3' is 3", () {
        expect(parse("x !' 3'").priority, 3);
      });

      test('!0x3 is hex 3 and stays in the text', () {
        final result = parse('Task !0x3');
        expect(result.priority, 3);
        expect(result.text, 'Task !0x3');
      });

      test('!0x9 is hex 9, no priority, so the next one counts', () {
        final result = parse('Task !0x9 !2');
        expect(result.priority, 2);
        expect(result.text, 'Task !0x9');
      });

      test('!0x and !0xg are NaN, no priority', () {
        expect(parse('Task !0x').priority, isNull);
        expect(parse('Task !0xg').priority, isNull);
        expect(parse('Task !-0X0').priority, 0);
      });

      test('removing !1 also cuts it out of !12', () {
        final result = parse('x !1 !12');
        expect(result.priority, 1);
        expect(result.text, 'x 2');
      });
    });
  });

  group('assignees', () {
    test('parses an assignee and keeps it in the text', () {
      final result = parse('Lorem Ipsum @user');
      expect(result.text, 'Lorem Ipsum @user');
      expect(result.assignees, ['user']);
    });

    test('parses multiple assignees', () {
      final result = parse('Lorem Ipsum @user1 @user2 @user3');
      expect(result.text, 'Lorem Ipsum @user1 @user2 @user3');
      expect(result.assignees, ['user1', 'user2', 'user3']);
    });

    test('collapses duplicate assignees', () {
      final result = parse('Lorem Ipsum @user1 @user1 @user2');
      expect(result.text, 'Lorem Ipsum @user1 @user1 @user2');
      expect(result.assignees, ['user1', 'user2']);
    });

    test("an assignee with a space in '", () {
      final result = parse("Lorem Ipsum @'user with long name'");
      expect(result.text, "Lorem Ipsum @'user with long name'");
      expect(result.assignees, ['user with long name']);
    });

    test('an assignee with a space in "', () {
      final result = parse('Lorem Ipsum @"user with long name"');
      expect(result.text, 'Lorem Ipsum @"user with long name"');
      expect(result.assignees, ['user with long name']);
    });

    test('an assignee called like a date is an assignee, not a date', () {
      final result = parse('Lorem Ipsum @today');
      expect(result.text, 'Lorem Ipsum @today');
      expect(result.assignees, ['today']);
      expect(result.date, isNull);
    });

    test('an email address after the prefix', () {
      final result = parse('Lorem Ipsum @email@example.com');
      expect(result.text, 'Lorem Ipsum @email@example.com');
      expect(result.assignees, ['email@example.com']);
    });

    test('a bare prefix is no assignee', () {
      expect(parse('x @').assignees, isEmpty);
      expect(parse('x @ y').assignees, isEmpty);
    });

    test('an assignee alone is text', () {
      final result = parse('@a');
      expect(result.text, '@a');
      expect(result.assignees, ['a']);
    });
  });

  test('everything together', () {
    final result = parse(
      'Reifen wechseln *wichtig *neu +Auto @anna !3 tomorrow at 9:00 '
      'every week',
    );
    expect(result.text, 'Reifen wechseln @anna');
    expect(result.labels, ['wichtig', 'neu']);
    expect(result.project, 'Auto');
    expect(result.assignees, ['anna']);
    expect(result.priority, 3);
    expect(result.date, DateTime(2021, 6, 25, 9));
    expect(
      result.repeats,
      const QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.weeks),
    );
  });

  group('cleanupItemText', () {
    test('removes resolved assignees only (the web vector)', () {
      expect(
        cleanupItemText('Task @alice @missing', ['alice'], '@'),
        'Task @missing',
      );
    });

    test('eats one trailing space, never the leading one', () {
      expect(cleanupItemText('a *b c', ['b'], '*'), 'a c');
      expect(cleanupItemText('Buy milk @jane', ['jane'], '@'), 'Buy milk ');
      expect(cleanupItemText('a *b  c', ['b'], '*'), 'a  c');
    });

    test('removes every occurrence, case-insensitively', () {
      expect(cleanupItemText('x @Alice y @ALICE', ['alice'], '@'), 'x y ');
    });

    test('removes quoted items', () {
      expect(cleanupItemText("x @'a b' y", ['a b'], '@'), 'x y');
      expect(cleanupItemText('x @"a b" y', ['a b'], '@'), 'x y');
      expect(
        cleanupItemText('x +"my (big) project"', ['my (big) project'], '+'),
        'x ',
      );
    });

    test('treats items and prefixes literally', () {
      expect(cleanupItemText('x *a.b *axb', ['a.b'], '*'), 'x *axb');
      expect(cleanupItemText(r'x #a$ y', [r'a$'], '#'), 'x y');
      expect(cleanupItemText('x !2 y', ['2'], '!'), 'x y');
      expect(cleanupItemText('x 2 y', ['2'], '!'), 'x 2 y');
    });

    test('needs the prefix', () {
      expect(cleanupItemText('alice @bob', ['alice'], '@'), 'alice @bob');
    });

    test('skips empty items', () {
      expect(cleanupItemText('x @ y', [''], '@'), 'x @ y');
    });

    test('web parity: also cuts the item out of a longer one', () {
      expect(cleanupItemText('x @al @alice', ['al'], '@'), 'x ice');
    });
  });
}
