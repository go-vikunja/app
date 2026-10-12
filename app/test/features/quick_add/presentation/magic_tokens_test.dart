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

    test('quotes a value with spaces', () {
      final value = at('Sell +gar');
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          'Garage Sale',
        ),
        at('Sell +"Garage Sale" '),
      );
      expect(quoteMagicValue('Say "hi" now'), "'Say \"hi\" now'");
      expect(quoteMagicValue('plain'), 'plain');
    });

    test('an open quote is completed up to the caret', () {
      final value = at('Sell +"Garage');
      expect(
        completeMagicToken(
          value,
          activeMagicToken(value, vikunja)!,
          'Garage Sale',
        ),
        at('Sell +"Garage Sale" '),
      );
    });
  });

  group('insertMagicText', () {
    test('at the caret, apart from the word before', () {
      expect(insertMagicText(at('Buy milk', 3), '*'), at('Buy * milk', 5));
      expect(insertMagicText(at('Buy milk'), '*'), at('Buy milk *'));
      expect(insertMagicText(at('Buy milk '), '+'), at('Buy milk +'));
    });

    test('apart from the word after, with the caret on the prefix', () {
      expect(insertMagicText(at('Buy', 0), '*'), at('* Buy', 1));
    });

    test('a whole token skips past its space', () {
      expect(
        insertMagicText(at('Buy milk'), '!3', trailingSpace: true),
        at('Buy milk !3 '),
      );
      expect(
        insertMagicText(at('Buy milk', 3), '!3', trailingSpace: true),
        at('Buy !3 milk', 7),
      );
    });

    test('replaces a selection', () {
      expect(
        insertMagicText(
          const TextEditingValue(
            text: 'Buy milk',
            selection: TextSelection(baseOffset: 4, extentOffset: 8),
          ),
          '*',
        ),
        at('Buy *'),
      );
    });
  });

  group('insertMagicPrefix', () {
    TextEditingValue selected(String text, int start, int end) =>
        TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: start, extentOffset: end),
        );

    test('makes the selection its item', () {
      expect(
        insertMagicPrefix(selected('Buy milk', 4, 8), '*'),
        at('Buy *milk'),
      );
      expect(
        insertMagicPrefix(selected('Buy oat milk now', 4, 12), '*'),
        at('Buy *"oat milk" now', 15),
      );
      expect(
        insertMagicPrefix(selected('Buy milk', 3, 8), '+'),
        at('Buy +milk'),
      );
    });

    test('without a selection it inserts the prefix at the caret', () {
      expect(insertMagicPrefix(at('Buy milk', 3), '*'), at('Buy * milk', 5));
    });

    test('a selection of spaces or over lines is not an item', () {
      expect(
        insertMagicPrefix(selected('Buy  milk', 3, 5), '*'),
        at('Buy  * milk', 6),
      );
      expect(
        insertMagicPrefix(selected('Buy\nmilk', 0, 8), '*'),
        at('Buy\nmilk *'),
      );
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
