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
}
