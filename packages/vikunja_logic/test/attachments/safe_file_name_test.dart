import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  group('safeFileName', () {
    test('keeps ordinary names, unicode and leading dots included', () {
      for (final name in [
        'report.pdf',
        'Ünïcødé 日本 ü.txt',
        'emoji 😀.txt',
        'Müller.txt',
        '.hidden',
        '..double-dot-start.txt',
        'no extension',
      ]) {
        expect(safeFileName(name), name);
      }
    });

    test('replaces both path separators', () {
      expect(safeFileName('a/b/c.txt'), 'a_b_c.txt');
      expect(safeFileName(r'..\win\x.txt'), '.._win_x.txt');
      expect(
        safeFileName('../../databases/x.sqlite'),
        '.._.._databases_x.sqlite',
      );
      expect(safeFileName('/'), '_');
    });

    test('replaces double quotes, which a multipart name cannot carry', () {
      expect(safeFileName('Offer "final".pdf'), "Offer 'final'.pdf");
    });

    test('removes control and bidirectional formatting characters', () {
      expect(safeFileName('a\nb\tc\u0000d.txt'), 'abcd.txt');
      expect(safeFileName('a\u007f\u0085b.txt'), 'ab.txt');
      expect(safeFileName('invoice\u202etxt.exe'), 'invoicetxt.exe');
      expect(safeFileName('\u2066x\u2069\u200e.png'), 'x.png');
    });

    test('trims surrounding whitespace', () {
      expect(safeFileName('  notes.txt \n'), 'notes.txt');
    });

    test('a name that is empty or only dots becomes the fallback', () {
      for (final name in ['', '   ', '.', '..', '...', ' .. ', '\u0000']) {
        expect(safeFileName(name), 'file', reason: jsonEncode(name));
      }
      expect(safeFileName('..', fallback: 'attachment-12'), 'attachment-12');
    });

    test('cuts long names to the byte limit, keeping the extension', () {
      final ascii = safeFileName('${'a' * 300}.txt');
      expect(ascii, '${'a' * (maxSafeFileNameBytes - 4)}.txt');

      final wide = safeFileName('${'日' * 100}.txt');
      expect(utf8.encode(wide).length, lessThanOrEqualTo(maxSafeFileNameBytes));
      expect(wide, '${'日' * 65}.txt');

      final emoji = safeFileName('${'😀' * 60}.png');
      expect(emoji, '${'😀' * 49}.png');
    });

    test('a name at the limit stays whole', () {
      final name = '${'a' * (maxSafeFileNameBytes - 4)}.txt';
      expect(safeFileName(name), name);
    });

    test('an extension too long to be one is cut like the rest', () {
      final name = 'a.${'b' * 300}';
      expect(safeFileName(name), name.substring(0, maxSafeFileNameBytes));
    });
  });
}
