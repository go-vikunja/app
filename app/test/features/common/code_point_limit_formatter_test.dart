import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';

void main() {
  final formatter = CodePointLimitFormatter(5);

  TextEditingValue value(String text, [int? start, int? end]) =>
      TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: start ?? text.length,
          extentOffset: end ?? start ?? text.length,
        ),
      );

  TextEditingValue format(TextEditingValue old, TextEditingValue next) =>
      formatter.formatEditUpdate(old, next);

  group('a text within the limit', () {
    test('is capped at the limit, counted in code points', () {
      final capped = format(value('abc'), value('abcdefg'));

      expect(capped.text, 'abcde');
      expect(capped.selection, const TextSelection.collapsed(offset: 5));
      expect(format(value(''), value('😀' * 6)).text, '😀' * 5);
    });

    test('a selection replaced by longer text keeps what fits', () {
      final capped = format(value('abc', 1, 2), value('aXYZWc', 5));

      expect(capped.text, 'aXYZW');
    });

    test('at the limit, typing changes nothing', () {
      final old = value('abcde', 2);

      expect(format(old, value('abXcde', 3)), old);
    });

    test('an edit that fits is taken as it is', () {
      final next = value('abcd');

      expect(format(value('abc'), next), next);
    });
  });

  group('a text already over the limit', () {
    final old = value('abcdefgh', 2, 4);

    test('keeps its old value when a selection is replaced by longer '
        'text', () {
      expect(format(old, value('abXYZefgh', 5)), old);
    });

    test('keeps its old value when typed into', () {
      final collapsed = value('abcdefgh', 3);

      expect(format(collapsed, value('abcXdefgh', 4)), collapsed);
    });

    test('takes a deletion and a replacement that is not longer', () {
      final deleted = value('abcdefg');
      final shorter = value('abXefgh', 3);
      final same = value('abXYefgh', 4);

      expect(format(value('abcdefgh'), deleted), deleted);
      expect(format(old, shorter), shorter);
      expect(format(old, same), same);
    });
  });
}
