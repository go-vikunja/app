import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

// `s`/`q` on `GET /tasks` for user A of the probe fixture (server.md §7).
const _observed = {
  'alpha': 'c1 o1 t1 t9',
  'ALPHA': 'c1 o1 t1 t9',
  'alp': 'c1 o1 t1 t9',
  'Alpha report': 't1',
  'report alpha': '',
  'alpha  report': '',
  ' alpha ': 'c1 o1 t1 t9',
  'quarterly': 't1',
  '<p>': 't1 t9 t11',
  'p>': 't1 t9 t11',
  'strasse': '',
  'straße': 't11',
  'ärger': '',
  'Ärger': 't11',
  'ÄRGER': 't11',
  '#3': 't3',
  '#1': 'c1 g1 o1 t1 t10',
  '#12': 't10 t12',
  '#12 literal': 't10 t12',
  'Kappa #12': 't10 t12',
  'FLT-3': '',
  'FLT': '',
  '3': '',
  '12': 't10',
  'a_p': 'c1 o1 t1 t3 t9 t10',
  '%': 'c1 c2 g1 o1 o2 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12',
  '_': 'c1 c2 g1 o1 o2 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12',
  '*': '',
  'Plan': 't3',
  'child': 'c1 c2 g1',
  'archived': '',
  'Delta': 't4',
  'xyz#3': 't3',
  '#03': 't3',
  '# 3': '',
  '#': 't10',
};

void main() {
  for (final MapEntry(key: search, value: expected) in _observed.entries) {
    test("'$search'", () {
      final matcher = TaskSearchMatcher(search);
      final keys = [
        for (final MapEntry(:key, :value) in probeAllTasks.entries)
          if (matcher.matches(value)) key,
      ];

      expect(sortedKeys(keys).join(' '), expected);
      expect([
        for (final MapEntry(:key, :value) in probeAllTasks.entries)
          if (matchesTaskSearch(search, value)) key,
      ], keys);
    });
  }

  test('an empty search matches everything', () {
    expect(matchesTaskSearch('', probeTasks['t1']!), isTrue);
    expect(matchesTaskSearch('  ', probeTasks['t1']!), isTrue);
  });

  test('#0 and numbers beyond 64 bits are no index', () {
    const zero = FilterableTask(id: 1, projectId: 1);

    expect(matchesTaskSearch('#0', zero), isFalse);
    expect(matchesTaskSearch('#99999999999999999999', zero), isFalse);
  });
}
