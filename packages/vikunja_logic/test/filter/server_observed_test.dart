// What Vikunja 2.7.0 (SQLite) answered on `GET /tasks` for the step 24
// probe fixture, v1 and v2 alike (scratchpad/step24/server.md), against
// the engine: one test per probed filter.

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

// SQLite stores dates as text without the bound's suffix, so a stored
// instant equal to the bound fails `=` and passes `<` and `!=`
// (server.md §4.4). The engine compares instants as written.
const _sqliteEqualInstants = {
  'reminders = 2026-10-25T08:00:00Z': 't8',
  'reminders != 2026-10-25T08:00:00Z':
      'c1 c2 g1 o1 o2 t1 t2 t3 t4 t5 t6 t7 t9 t10 t11 t12',
  'reminders in 2026-10-25T08:00:00Z': 't8',
  'due_date = 2026-10-20T21:30:00Z': 'c1 t1',
  'due_date = 2026-10-20 21:30': 'c1 t1',
  'due_date >= 2026-10-20T21:30:00Z && due_date <= 2026-10-20T21:30:00Z':
      'c1 t1',
  'due_date != 2026-10-20T21:30:00Z': 't2 t3 t4 t5 t8',
  'due_date != 2026-10-20T21:30:00Z [nulls]':
      'c2 g1 o1 o2 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12',
  'due_date in 2026-10-20T21:30:00Z': 'c1 t1',
  'due_date < 2026-10-20T21:30:00Z': 't3 t4 t5',
  'due_date >= 2026-10-20T21:30:00Z': 'c1 t1 t2 t8',
  'start_date < 2026-10-21': 't3',
  'start_date >= 2026-10-21': 't6',
  'start_date = 2026-10-21': 't6',
  'start_date >= now/d+1d': 't6',
  'start_date < now/d+1d': 't3',
  'end_date < 2026-10-25': 't3',
  'end_date >= 2026-10-25': 't6',
  'start_date < 2026-10-21T02:00:00+02:00': 't3',
  'start_date >= 2026-10-21T02:00:00+02:00': 't6',
};

// The server accepts these and then fails the request with a 500; the
// engine refuses them as an invalid value instead.
const _serverErrors = {'assignees > $userA', 'position > 0', 'position = 0'};

void main() {
  setUpAll(loadTimeZones);

  final rows = loadJsonl('server_observed.jsonl');

  test('the fixture holds every probed filter', () {
    expect(rows, hasLength(445));
  });

  for (final row in rows) {
    final filter = row['f']! as String;
    final timezone = row['tz']! as String;
    final includeNulls = row['nulls']! as bool;
    final key = '$filter${includeNulls ? ' [nulls]' : ''}';
    final label = row['label'] as String? ?? filter;
    final name =
        '${row['probe']} $label'
        '${timezone == 'GMT' ? '' : ' tz=$timezone'}'
        '${includeNulls ? ' nulls' : ''}';

    test(name, () {
      if (row['err'] == 2003) {
        expect(filterLocation(timezone), isNull);
        return;
      }
      final result = parseTaskFilter(filter);
      if (row['status'] == 500 || row.containsKey('err')) {
        final code = row['status'] == 500 ? 4019 : row['err'];
        if (row['status'] == 500) expect(_serverErrors, contains(filter));
        expect(result, isA<FilterError>().having((e) => e.code, 'code', code));
        return;
      }
      final context = FilterContext(
        now: utc(row['now']! as String),
        // `Local` is the server's zone; a bad zone is ignored without a
        // filter.
        location: filterLocation(timezone) ?? zone('GMT'),
        includeNulls: includeNulls,
      );
      final expected =
          _sqliteEqualInstants[key] ?? (row['ids']! as List).join(' ');
      expect(
        sortedKeys(matchingKeys(filter, probeAllTasks, context)).join(' '),
        expected,
      );
    });
  }
}
