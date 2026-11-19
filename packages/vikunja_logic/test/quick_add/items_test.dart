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

    test('D102-7: removing a label leaves a longer one (the web cut it)', () {
      final result = parse('x *a *abc');
      expect(result.labels, ['a', 'abc']);
      expect(result.text, 'x');
      expect(parse('x *bug *bugfix y').text, 'x y');
    });

    test('D102-7: a doubled prefix inside a line leaves with its label', () {
      final result = parse('Fix **bike');
      expect(result.labels, ['bike']);
      expect(result.text, 'Fix');
    });

    test('D102-7: a quoted label before punctuation leaves the text', () {
      final result = parse('Plan trip *"New York", then book');
      expect(result.labels, ['New York']);
      // The web's cleanup leaves the space before the comma (D38's limits).
      expect(result.text, 'Plan trip , then book');
    });

    test('D102-7: punctuation ends a token only before a space or the end, '
        'and a longer label is not cut', () {
      final result = parse('x *bug *bug.');
      expect(result.labels, ['bug', 'bug.']);
      expect(result.text, 'x');
      expect(cleanupItemText('x *bug.x', ['bug'], '*'), 'x *bug.x');
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

    test('D102-7: a doubled prefix inside a line leaves with its project', () {
      final result = parse('x ++p');
      expect(result.project, 'p');
      expect(result.text, 'x');
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

    group('D102-8: only a whole number (the web reads it with parseInt)', () {
      test('!2fa is no priority and stays in the text', () {
        final result = parse('Set up !2fa for the admin');
        expect(result.priority, isNull);
        expect(result.text, 'Set up !2fa for the admin');
      });

      test('!2fa !4 is 4', () {
        final result = parse('Set up !2fa !4');
        expect(result.priority, 4);
        expect(result.text, 'Set up !2fa');
      });

      test('!03 is 3 and leaves the text', () {
        final result = parse('Lorem !03 x');
        expect(result.priority, 3);
        expect(result.text, 'Lorem x');
      });

      test('signs, hex, quoted spaces are no priority', () {
        for (final text in ['x !+3', 'x !-0', "x !' 3'", 'x !0x3', 'x !0x']) {
          expect(parse(text).priority, isNull, reason: text);
        }
      });

      test('removing !1 leaves !12 (D102-7)', () {
        final result = parse('x !1 !12');
        expect(result.priority, 1);
        expect(result.text, 'x !12');
      });

      test('D102-7: a doubled prefix inside a line leaves with it', () {
        final result = parse('x !!3');
        expect(result.priority, 3);
        expect(result.text, 'x');
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

    test('D102-7: a resolved name leaves before punctuation and with a '
        'doubled prefix', () {
      final result = parse('Call @bob tomorrow.');
      expect(result.text, 'Call @bob.');
      expect(
        cleanupItemText(
          result.text,
          result.assignees,
          '@',
          beforePunctuation: true,
        ),
        'Call .',
      );
      final doubled = parse('Ask @@alice');
      expect(doubled.assignees, ['alice']);
      expect(cleanupItemText(doubled.text, doubled.assignees, '@'), 'Ask ');
    });

    test('an unquoted item before punctuation is the item the parser read '
        'there, not the one without it: `!3,` and `+work,` stay', () {
      expect(parse('Fix !3 now !3,').text, 'Fix now !3,');
      expect(parse('Fix +work now +work,').text, 'Fix now +work,');
      expect(cleanupItemText('Ask @bob @bob,', ['bob'], '@'), 'Ask @bob,');
      // Quoted, the item ends at its quote, also before punctuation.
      expect(parse('Plan trip *"New York", then book').labels, ['New York']);
      expect(
        parse('Plan trip *"New York", then book').text,
        'Plan trip , then book',
      );
    });

    test('a month word before an apostrophe is no date, as it stays in the '
        'title (D102-1)', () {
      for (final text in [
        "Book venue for dec 12's party",
        "Book venue for 12 dec's party",
        "Prep 5th may's launch",
      ]) {
        final result = parse(text);
        expect(result.date, isNull, reason: text);
        expect(result.text, text, reason: text);
      }
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

    test('D102-7: only a whole token (the web cut `ice` out of `@alice`)', () {
      expect(cleanupItemText('x @al @alice', ['al'], '@'), 'x @alice');
      expect(cleanupItemText('mail@al.com @al', ['al'], '@'), 'mail@al.com ');
    });
  });
}
