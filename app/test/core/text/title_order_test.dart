import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

void main() {
  List<String> sorted(List<String> titles) => [...titles]..sort(compareTitles);

  test('letters with accents sort with their base letters, as the web '
      'lists them with localeCompare', () {
    expect(sorted(['Zuhause', 'Übersicht', 'Bugs', 'Ärger', 'Apfel']), [
      'Apfel',
      'Ärger',
      'Bugs',
      'Übersicht',
      'Zuhause',
    ]);
    expect(sorted(['zèbre', 'Été', 'éclair', 'dent']), [
      'dent',
      'éclair',
      'Été',
      'zèbre',
    ]);
  });

  test('ß, æ and œ count as two letters', () {
    expect(sorted(['Strasze', 'Straße', 'Strast']), [
      'Straße',
      'Strast',
      'Strasze',
    ]);
    expect(sorted(['Aeb', 'Æa']), ['Æa', 'Aeb']);
    expect(sorted(['Oez', 'Œuvre']), ['Œuvre', 'Oez']);
  });

  test('a decomposed accent sorts like the composed one', () {
    expect(sorted(['Zoo', 'Übersicht']), ['Übersicht', 'Zoo']);
  });

  test('an accent alone decides after the letters; case alone is equal', () {
    expect(compareTitles('Ubersicht', 'Übersicht'), lessThan(0));
    expect(compareTitles('Übersicht', 'Ubersicht'), greaterThan(0));
    expect(compareTitles('Same', 'same'), 0);
    expect(compareTitles('ÜBER', 'über'), 0);
  });

  test('Romanian ș and ț, with a comma below, sort with s and t', () {
    expect(sorted(['Tara', 'Șanț', 'Sat']), ['Șanț', 'Sat', 'Tara']);
  });

  group('foldAccents', () {
    test('drops the accents of Latin letters and writes out æ, œ, ß and '
        'þ', () {
      expect(foldAccents('café'), 'cafe');
      expect(foldAccents('ärger mit öl'), 'arger mit ol');
      expect(foldAccents('straße'), 'strasse');
      expect(foldAccents('œuvre'), 'oeuvre');
      expect(foldAccents('æble'), 'aeble');
      expect(foldAccents('þing'), 'thing');
      expect(foldAccents('șanț'), 'sant');
    });

    test('drops a decomposed accent', () {
      expect(foldAccents('cafe\u0301'), 'cafe');
      expect(foldAccents('u\u0308bersicht'), 'ubersicht');
    });

    test('keeps plain ASCII and the letters it does not know', () {
      const ascii = 'plain ascii, 12 #3 - PROJ';
      expect(foldAccents(ascii), same(ascii));
      expect(foldAccents('ελληνικά'), 'ελληνικά');
    });
  });
}
