import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_tokens.dart';

void main() {
  final vikunja = quickAddPrefixes(QuickAddMagicMode.vikunja)!;
  final todoist = quickAddPrefixes(QuickAddMagicMode.todoist)!;

  TextEditingValue at(String text, [int? caret]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );

  group('activeMagicToken', () {
    test('the token being typed, from its prefix', () {
      expect(activeMagicToken(at('Buy *gro'), vikunja), (
        kind: MagicTokenKind.label,
        prefix: '*',
        start: 4,
        end: 8,
        query: 'gro',
      ));
    });

    test('a caret inside a token takes the whole token', () {
      expect(activeMagicToken(at('Buy +garage now', 7), vikunja), (
        kind: MagicTokenKind.project,
        prefix: '+',
        start: 4,
        end: 11,
        query: 'garage',
      ));
    });

    test('a bare prefix asks for everything', () {
      expect(activeMagicToken(at('Call @'), vikunja)?.query, '');
    });

    test('nothing once a space follows, inside a word, without a caret or '
        'for the priority', () {
      expect(activeMagicToken(at('Buy *milk '), vikunja), isNull);
      expect(activeMagicToken(at('mail me@home'), vikunja), isNull);
      expect(activeMagicToken(at('Fix !3'), vikunja), isNull);
      expect(
        activeMagicToken(
          const TextEditingValue(
            text: 'Buy *gro',
            selection: TextSelection(baseOffset: 4, extentOffset: 8),
          ),
          vikunja,
        ),
        isNull,
      );
    });

    test('an open quote runs to the caret, a closed one to its end', () {
      expect(activeMagicToken(at('Sell +"Garage Sa'), vikunja), (
        kind: MagicTokenKind.project,
        prefix: '+',
        start: 5,
        end: 16,
        query: 'Garage Sa',
      ));
      expect(activeMagicToken(at('Sell +"Garage Sale" now', 19), vikunja), (
        kind: MagicTokenKind.project,
        prefix: '+',
        start: 5,
        end: 19,
        query: 'Garage Sale',
      ));
    });

    test('an open quote ends at the next label, as the parser reads it, so '
        'that label is the one being typed', () {
      expect(activeMagicToken(at('Buy *"milk *urg'), vikunja), (
        kind: MagicTokenKind.label,
        prefix: '*',
        start: 11,
        end: 15,
        query: 'urg',
      ));
      expect(activeMagicToken(at('Buy *"milk *urg', 8), vikunja), (
        kind: MagicTokenKind.label,
        prefix: '*',
        start: 4,
        end: 8,
        query: 'mi',
      ));
    });

    test('works on any line of several', () {
      expect(activeMagicToken(at('Buy milk\nCall @sa'), vikunja), (
        kind: MagicTokenKind.assignee,
        prefix: '@',
        start: 14,
        end: 17,
        query: 'sa',
      ));
    });

    test('todoist prefixes', () {
      expect(
        activeMagicToken(at('Buy @gro'), todoist)?.kind,
        MagicTokenKind.label,
      );
      expect(
        activeMagicToken(at('Buy #ho'), todoist)?.kind,
        MagicTokenKind.project,
      );
      expect(
        activeMagicToken(at('Ask +sa'), todoist)?.kind,
        MagicTokenKind.assignee,
      );
    });
  });

  group('completeMagicToken', () {
    test('replaces the token and adds a space', () {
      final value = at('Buy *gro');
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          'groceries',
        ),
        at('Buy *groceries ', 15),
      );
    });

    test('reuses a space that follows', () {
      final value = at('Buy *gro milk', 6);
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          'groceries',
        ),
        at('Buy *groceries milk', 15),
      );
    });

    test('writes the item as given, quotes included', () {
      final value = at('Sell +gar');
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          '"Garage Sale"',
        ),
        at('Sell +"Garage Sale" '),
      );
      expect(quoteQuickAddItem('Say "hi" now'), "'Say \"hi\" now'");
      expect(quoteQuickAddItem('plain'), 'plain');
    });

    test('an open quote is completed up to the caret', () {
      final value = at('Sell +"Garage');
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          '"Garage Sale"',
        ),
        at('Sell +"Garage Sale" '),
      );
    });
  });

  group('writtenMagicItem', () {
    const label = MagicTokenKind.label;
    const project = MagicTokenKind.project;
    const mode = QuickAddMagicMode.vikunja;

    /// What the parser reads from [line] for [kind].
    String? readBack(String line, MagicTokenKind kind, QuickAddMagicMode mode) {
      final parsed = parseTaskText(
        line,
        now: DateTime(2026, 10, 10),
        mode: mode,
      );
      return switch (kind) {
        MagicTokenKind.label => parsed.labels.singleOrNull,
        MagicTokenKind.project => parsed.project,
        MagicTokenKind.assignee => parsed.assignees.singleOrNull,
      };
    }

    test('plain, or quoted where it holds a space', () {
      expect(writtenMagicItem('urgent', label, mode), 'urgent');
      expect(writtenMagicItem('Road trip', label, mode), '"Road trip"');
      expect(writtenMagicItem('Say "hi" now', label, mode), "'Say \"hi\" now'");
    });

    test('in the quote it lacks where it starts with a quote or the '
        'prefix', () {
      expect(writtenMagicItem("'90s", label, mode), '"\'90s"');
      expect(writtenMagicItem('"Later"', project, mode), '\'"Later"\'');
      expect(writtenMagicItem('*star', label, mode), '"*star"');
      expect(writtenMagicItem("Bob's plan", project, mode), '"Bob\'s plan"');
    });

    test('none where no writing reads back as the item', () {
      expect(writtenMagicItem('Bob\'s "big" plan', project, mode), isNull);
      expect(writtenMagicItem('a *b', label, mode), isNull);
      expect(writtenMagicItem('Sale *now', project, mode), isNull);
      expect(writtenMagicItem('Home @work', project, mode), isNotNull);
      expect(
        writtenMagicItem('Home @work', project, QuickAddMagicMode.todoist),
        isNull,
      );
      expect(writtenMagicItem('x', label, QuickAddMagicMode.disabled), isNull);
    });

    test('what it writes reads back as exactly the item, at the start of a '
        'line and after other words', () {
      for (final (item, kind) in [
        ('urgent', label),
        ('Road trip', label),
        ('Say "hi" now', label),
        ("'90s", label),
        ('*star', label),
        ('"Later"', project),
        ("Bob's plan", project),
        ('Home @work', project),
        ('Garage +Sale', label),
      ]) {
        for (final mode in [
          QuickAddMagicMode.vikunja,
          QuickAddMagicMode.todoist,
        ]) {
          final written = writtenMagicItem(item, kind, mode);
          if (written == null) continue;
          final prefixes = quickAddPrefixes(mode)!;
          final prefix = kind == label ? prefixes.label : prefixes.project;
          for (final line in [
            '$prefix$written',
            'Plan it $prefix$written soon',
          ]) {
            expect(readBack(line, kind, mode), item, reason: '$mode: $line');
          }
        }
      }
    });
  });

  group('removeMagicSpans', () {
    test('removes each span with one space next to it', () {
      const text = 'Buy *milk tomorrow at 9:00 +Home';
      expect(
        removeMagicSpans(at(text), const [
          MagicSpan(4, 9, MagicSpanKind.label),
          MagicSpan(27, 32, MagicSpanKind.project),
        ]),
        at('Buy tomorrow at 9:00'),
      );
    });

    test('keeps the caret with the text around it', () {
      expect(
        removeMagicSpans(at('Buy *milk now', 13), const [
          MagicSpan(4, 9, MagicSpanKind.label),
        ]),
        at('Buy now', 7),
      );
      expect(
        removeMagicSpans(at('Buy *milk now', 6), const [
          MagicSpan(4, 9, MagicSpanKind.label),
        ]),
        at('Buy now', 4),
      );
    });
  });
}
