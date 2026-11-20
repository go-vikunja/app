import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

List<int> _named(String wanted, Map<int, String> identifiers) => [
  for (final entry in namedByIdentifier(
    wanted,
    identifiers.entries,
    identifierOf: (entry) => entry.value,
  ))
    entry.key,
];

void main() {
  test('upper-cased and unique ignoring case (2.4 and later): the one '
      'project, in any case', () {
    const identifiers = {1: 'GARDEN', 2: 'STRAßE', 3: 'MY-PRJ', 4: ''};

    for (final (wanted, id) in [
      ('GARDEN', 1),
      ('garden', 1),
      ('Garden', 1),
      ('straße', 2),
      ('STRAßE', 2),
      ('my-prj', 3),
    ]) {
      expect(_named(wanted, identifiers), [id], reason: wanted);
    }
    expect(_named('NOPE', identifiers), isEmpty);
    expect(_named('', identifiers), isEmpty, reason: 'none without one');
  });

  test('as typed and unique only as typed (2.3): the exact one wins, '
      'another case names every match', () {
    const identifiers = {1: 'ab', 2: 'AB', 3: 'Cd'};

    expect(_named('ab', identifiers), [1]);
    expect(_named('AB', identifiers), [2]);
    expect(_named('Ab', identifiers), [1, 2]);
    expect(_named('aB', identifiers), [1, 2]);
    expect(_named('cd', identifiers), [3], reason: 'one in another case');
  });

  test('stale rows with the same identifier are all named', () {
    expect(_named('AB', {1: 'AB', 2: 'AB', 3: 'ab'}), [1, 2]);
  });
}
