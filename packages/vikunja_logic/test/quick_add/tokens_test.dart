import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';
import 'web_items.dart';

void main() {
  List<String> itemsOf(String text, String prefix) => {
    for (final token in quickAddTokens(text, prefix))
      if (token.item.isNotEmpty) token.item,
  }.toList();

  /// Each token as `[covered text] item`.
  List<String> tokensOf(String text, String prefix) => [
    for (final token in quickAddTokens(text, prefix))
      '[${text.substring(token.start, token.end)}] ${token.item}',
  ];

  group('quickAddTokens', () {
    test('reads the items the web splits out, over random text', () {
      const alphabet = [
        'a',
        'b',
        '*',
        '+',
        '@',
        '!',
        '"',
        "'",
        '.',
        ',',
        ' ',
        ' ',
      ];
      final random = Random(40);
      for (var i = 0; i < 20000; i++) {
        final text = [
          for (var j = random.nextInt(18); j > 0; j--)
            alphabet[random.nextInt(alphabet.length)],
        ].join();
        for (final prefix in ['*', '+', '@', '!']) {
          expect(
            itemsOf(text, prefix),
            webItemsFromPrefix(text, prefix),
            reason: '$prefix in <$text>',
          );
          for (final token in quickAddTokens(text, prefix)) {
            expect(text.startsWith(prefix, token.start), isTrue);
            expect(token.start == 0 || text[token.start - 1] == ' ', isTrue);
            expect(
              text.substring(
                token.itemStart,
                token.itemStart + token.item.length,
              ),
              token.item,
            );
            expect(
              token.end - token.itemStart - token.item.length,
              anyOf(0, token.quoted ? 1 : 0),
              reason: '<$text>',
            );
          }
        }
        final quotedWhole =
            text.length >= 2 &&
            (text.startsWith('"') || text.startsWith("'")) &&
            text.endsWith(text[0]);
        if (!quotedWhole) {
          expect(
            parse(text).labels,
            webItemsFromPrefix(text, '*'),
            reason: '<$text>',
          );
        }
      }
    });

    test('an item runs to the next space, a quoted one to its quote', () {
      expect(tokensOf('Buy *milk *"road trip" now', '*'), [
        '[*milk] milk',
        '[*"road trip"] road trip',
      ]);
      expect(tokensOf("x *'a b'c", '*'), ["[*'a b'] a b"]);
      expect(tokensOf('x *a,b y*z', '*'), ['[*a,b] a,b']);
    });

    test('a bare prefix is an empty item', () {
      expect(tokensOf('Call @', '@'), ['[@] ']);
      expect(tokensOf('x * y', '*'), ['[*] ']);
    });

    test('an unclosed quote runs to the next item of its prefix, not to the '
        'end of the line', () {
      expect(tokensOf('Buy *"milk *urgent', '*'), [
        '[*"milk] milk',
        '[*urgent] urgent',
      ]);
      expect(tokensOf('Buy *"milk +Home', '*'), ['[*"milk +Home] milk +Home']);
    });

    test('a quoted item ends at the next item of its prefix', () {
      expect(tokensOf('x *"a *b" c', '*'), ['[*"a] a', '[*b"] b"']);
    });

    test('one repeated prefix is dropped, but at the start of the text the '
        'web keeps it in the item', () {
      expect(tokensOf('Fix **bike', '*'), ['[**bike] bike']);
      expect(tokensOf('**bike now', '*'), ['[**bike] *bike']);
      expect(tokensOf('x ***a', '*'), ['[***a] *a']);
    });

    test('offsets point into the text', () {
      expect(quickAddTokens('Ask @@alice', '@'), [
        (start: 4, end: 11, itemStart: 6, item: 'alice', quoted: false),
      ]);
      expect(quickAddTokens('Sell +"Garage Sale" now', '+'), [
        (start: 5, end: 19, itemStart: 7, item: 'Garage Sale', quoted: true),
      ]);
    });
  });

  test('quoteQuickAddItem quotes an item with a space, with the quote it '
      'does not hold', () {
    expect(quoteQuickAddItem('plain'), 'plain');
    expect(quoteQuickAddItem('Home garage'), '"Home garage"');
    expect(quoteQuickAddItem('Say "hi" now'), "'Say \"hi\" now'");
    expect(quoteQuickAddItem('a\tb'), '"a\tb"');
  });

  test('quickAddPriority is a whole number from 0 to 5', () {
    expect(quickAddPriority('3'), 3);
    expect(quickAddPriority('03'), 3);
    expect(quickAddPriority('0'), 0);
    expect(quickAddPriority('6'), isNull);
    expect(quickAddPriority('2fa'), isNull);
    expect(quickAddPriority(''), isNull);
    expect(quickAddPriority('-1'), isNull);
    expect(quickAddPriority('9' * 30), isNull);
  });
}
