// Every JSONL vector of scratchpad/step24/language.md §14 (upstream model,
// HTTP and web tests plus vectors derived from the server's code), each as
// one test. A vector the engine does not own (sorting, the favourites
// scope, the web editor's widgets) is a skipped test saying why, so none
// goes missing silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/src/filter/filter_nodes.dart';
import 'package:vikunja_logic/src/filter/filter_preprocess.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

final DateTime _now = utc('2026-10-20T08:05:00Z');

FilterContext _context({
  String zoneName = 'UTC',
  bool includeNulls = false,
  DateTime? now,
}) => FilterContext(
  now: now ?? _now,
  location: zone(zoneName),
  includeNulls: includeNulls,
);

int? _errorCode(String filter) => switch (parseTaskFilter(filter)) {
  FilterError(:final code) => code,
  FilterExpression() => null,
};

const _savedFilter1 =
    "start_date > '2018-12-11T03:46:40+00:00' || "
    "end_date < '2018-12-13T11:20:01+00:00' || "
    "due_date > '2018-11-29T14:00:00+00:00'";
const _view161 =
    "start_date > '2018-12-11T03:46:40+00:00' || "
    "end_date < '2018-12-13T11:20:01+00:00'";

void main() {
  setUpAll(loadTimeZones);

  group('§14.2 parse vectors', () {
    for (final vector in loadJsonl('language_parse.jsonl')) {
      _vectorTest(vector, () => _checkParse(vector));
    }
  });

  group('§14.2 replaceFilterOperators', () {
    for (final vector in loadJsonl('language_replace_operators.jsonl')) {
      test(vector['in']! as String, () {
        expect(replaceOperatorWords(vector['in']! as String), vector['out']);
      });
    }
  });

  group('§14.2 complexity', () {
    for (final vector in loadJsonl('language_complexity.jsonl')) {
      _vectorTest(vector, () => _checkComplexity(vector));
    }
  });

  group('§14.3 model results', () {
    for (final vector in loadJsonl('language_model_results.jsonl')) {
      _vectorTest(
        vector,
        () => _checkResult(vector),
        skip: switch (vector['project']) {
          -1 => 'the favourites pseudo project is a scope, which the app owns',
          _ => null,
        },
      );
    }
  });

  group('§14.3 sort', () {
    for (final vector in loadJsonl('language_model_sort.jsonl')) {
      _vectorTest(
        vector,
        () {},
        skip: 'an order, not a filter: the lists sort themselves (D43)',
      );
    }
  });

  group('§14.4 HTTP results', () {
    for (final vector in loadJsonl('language_http_results.jsonl')) {
      _vectorTest(
        vector,
        () => _checkResult(vector),
        skip: vector.containsKey('sort')
            ? 'an order, not a filter: the lists sort themselves (D43)'
            : null,
      );
    }
  });

  group('§14.5 derived vectors', () {
    for (final vector in loadJsonl('language_derived.jsonl')) {
      _vectorTest(vector, () => _checkDerived(vector));
    }
  });

  group('§14.6 web transforms', () {
    for (final vector in loadJsonl('language_web_transforms.jsonl')) {
      _vectorTest(
        vector,
        () => _checkTransform(vector),
        skip: vector['fn'] == 'hasFilterQuery'
            ? "the web's substring test (a bug: `Landing` holds `in`) is not "
                  'ported'
            : null,
      );
    }
  });

  group('§14.6 other web vectors', () {
    for (final vector in loadJsonl('language_web_other.jsonl')) {
      final filter = vector['filter'];
      _vectorTest(
        vector,
        () =>
            expect(parseTaskFilter(filter! as String), isA<FilterExpression>()),
        skip: filter is String
            ? null
            : "the web editor's highlighting, autocomplete and popup belong "
                  'to the filter builder (section C)',
      );
    }
  });
}

void _vectorTest(
  Map<String, Object?> vector,
  void Function() body, {
  String? skip,
}) {
  final name = [
    vector['src'],
    vector['f'] ?? vector['in'] ?? vector['search'] ?? vector['text'] ?? '',
  ].join(' ');
  test(name, body, skip: skip);
}

Object? _shown(Object value, FilterContext context) => switch (value) {
  final FilterDate date =>
    date.resolve(context.now, context.location)?.toIso8601String(),
  _ => value,
};

/// The top level as the vectors write it: `[field, op, value]`, then
/// `[join, field, op, value]`.
List<List<Object?>> _flat(FilterExpression expression, FilterContext context) {
  final rows = <List<Object?>>[];
  for (final (index, item) in expression.root.items.indexed) {
    final conditions = switch (item.node) {
      FilterConditionNode(:final condition) => [condition],
      FilterRangeNode(:final conditions) => conditions,
      FilterGroupNode() => throw StateError('a group'),
    };
    for (final condition in conditions) {
      final values = [
        for (final value in condition.values) _shown(value, context),
      ];
      rows.add([
        if ((index > 0 || rows.isNotEmpty) && item.or)
          'OR'
        else if (index > 0 || rows.isNotEmpty)
          'AND',
        condition.field.wireName,
        condition.comparator.symbol,
        if (condition.comparator.isList ||
            condition.field == FilterField.assignees ||
            condition.field == FilterField.createdBy)
          values
        else
          values.single,
      ]);
    }
  }
  return rows;
}

String _iso(DateTime time) => time.toUtc().toIso8601String();

String _datemath(String expression, FilterContext context) =>
    _iso(evaluateDatemath(expression, context.now, location: context.location));

void _checkParse(Map<String, Object?> vector) {
  final filter = vector['f']! as String;
  final context = _context(zoneName: (vector['tz'] as String?) ?? 'UTC');
  if (vector['err'] case final int code) {
    expect(_errorCode(filter), code);
    return;
  }
  final expression = parsed(filter);
  final expected = vector['parse'];
  if (expected is List) {
    expect(_flat(expression, context), [
      for (final row in expected.cast<List<Object?>>())
        [for (final cell in row) _expectedCell(cell, context)],
    ]);
    return;
  }
  final value = vector['value'];
  Object? firstValue() => _flat(expression, context).first.last;
  switch ((filter, expected, value)) {
    case (_, final String rule, _) when rule.startsWith('2 groups'):
      final groups = [
        for (final item in expression.root.items)
          ((item.node as FilterGroupNode).group, item.or),
      ];
      expect(groups.map((group) => group.$2), [false, true]);
      expect(
        groups.first.$1.toString(),
        contains('priority >= 4 && due_date < now+7d'),
      );
      expect(
        groups.last.$1.toString(),
        '(done = false && assignees in John, Jane)',
      );
    case (_, 'value year == 1', _):
      expect(DateTime.parse(firstValue()! as String).year, 1);
    case (_, final String rule, _) when rule.startsWith('1 group'):
      final group =
          (expression.root.items.single.node as FilterGroupNode).group;
      expect(
        group.toString(),
        filter.contains('||')
            ? '(done = false || project_id = 1)'
            : '(project_id = 1)',
      );
    case (_, null, 'LA local midnight today, in UTC'):
      expect(firstValue(), _iso(tz.TZDateTime(context.location, 2026, 10, 20)));
    case (_, null, 'LA midnight tomorrow, in UTC'):
      expect(firstValue(), _iso(tz.TZDateTime(context.location, 2026, 10, 21)));
    case (_, null, final String rule)
        when rule.contains('year>=1') || rule == 'same':
      final bound = DateTime.parse(firstValue()! as String);
      expect(bound.year, greaterThanOrEqualTo(1));
      expect(bound.isBefore(DateTime.utc(1)), isFalse);
    case (_, null, final String instant):
      expect(firstValue(), utc(instant).toIso8601String());
    default:
      fail('unhandled parse vector');
  }
}

Object? _expectedCell(Object? cell, FilterContext context) {
  if (cell is! String) return cell;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(cell)) {
    return utc(cell).toIso8601String();
  }
  if (cell.startsWith('now')) {
    return _datemath(cell.split(' ').first, context);
  }
  return cell;
}

void _checkComplexity(Map<String, Object?> vector) {
  final src = vector['src']! as String;
  final filter = switch (src) {
    'filter_complexity_test.go:36' => '${'(' * 100}done = true${')' * 100}',
    ':42' => '${'(' * 101}done = true${')' * 101}',
    ':64' => 'done = false && ' * 1300,
    ':74' => '${'project not in 1 && ' * 820}done = true',
    ':92' => "title = value${"'" * 9000}suffix",
    ':106' => "title = '${'(' * 200}' && done = false",
    ':113' => "title = 'a \\'${'( ' * 150}done = false${' )' * 150}",
    _ => vector['f']! as String,
  };
  if (src == ':74') {
    expect(filter.length, greaterThan(16384));
    expect(
      quoteValues(replaceOperatorWords(filter)).length,
      lessThan(filter.length),
    );
  }
  if (src == ':92') {
    expect(filter.length, lessThan(16384));
  }
  final result = parseTaskFilter(filter);
  if (vector['err'] case final int code) {
    expect(result, isA<FilterError>().having((e) => e.code, 'code', code));
    if (src == ':64') {
      expect((result as FilterError).message, isNot(contains('done')));
    }
    return;
  }
  final expression = result as FilterExpression;
  switch (vector['parse']) {
    case '1 filter':
      var node = expression.root.items.single.node;
      while (node is FilterGroupNode) {
        node = node.group.items.single.node;
      }
      expect(node.toString(), 'done = true');
    case final String rule when rule.startsWith('2 filters'):
      expect(expression.root.items, hasLength(2));
      expect(
        expression.root.items.first.node.toString(),
        'title = ${'(' * 200}',
      );
    default:
      fail('unhandled complexity vector');
  }
}

Set<int> _ids(Object? spec) {
  if (spec is List) return {...spec.cast<int>()};
  final text = spec! as String;
  final base = text.startsWith('P1') ? fxProject1 : fxTasks.keys.toSet();
  final minus = RegExp(r'\{([^}]*)\}').firstMatch(text)?[1];
  if (minus == null) return base;
  final removed = <int>{};
  for (final part in minus.split(',')) {
    if (part.contains('..')) {
      final [from, to] = part.split('..').map(int.parse).toList();
      for (var id = from; id <= to; id++) {
        removed.add(id);
      }
    } else {
      removed.add(int.parse(part.trim()));
    }
  }
  return base.difference(removed);
}

/// A result vector over U1, project 1 or saved filter 1.
void _checkResult(Map<String, Object?> vector) {
  final src = vector['src']! as String;
  if (vector['err'] case final int code) {
    expect(_errorCode(vector['f']! as String), code);
    return;
  }
  if (src.endsWith(':2516')) return _checkLosAngelesToday();
  if (src.endsWith(':2567')) return _checkGanttInSavedFilter(vector);
  if (src.endsWith(':421')) {
    for (final filter in [
      _savedFilter1,
      "start_date > '2018-10-20T01:46:40+00:00'",
      "end_date > '2018-12-13T11:20:01+00:00'",
    ]) {
      final project = {for (final id in fxProject1) id: fxTasks[id]!};
      expect(
        matchingIds(parsed(filter), fxTasks, _context()),
        matchingIds(parsed(filter), project, _context()),
      );
    }
    return;
  }

  var scope = fxTasks;
  var filter = (vector['f'] as String?) ?? '';
  var includeNulls = vector['nulls'] == true;
  switch (vector['project']) {
    case 1:
      scope = {for (final id in fxProject1) id: fxTasks[id]!};
    case -2:
      filter = _savedFilter1;
  }
  if (vector['view'] == 161) {
    filter = filter.isEmpty ? _view161 : '($filter) && ($_view161)';
    includeNulls = true;
  }
  var ids = matchingIds(
    parsed(filter),
    scope,
    _context(includeNulls: includeNulls),
  );
  if (vector['search'] case final String search) {
    ids = [
      for (final id in ids)
        if (matchesTaskSearch(search, scope[id]!)) id,
    ];
  }
  if (vector.containsKey('ids')) expect(ids.toSet(), _ids(vector['ids']));
  if (vector['contains'] case final List<Object?> contained) {
    expect(ids, containsAll(contained));
  }
  if (vector['not'] case final List<Object?> excluded) {
    for (final id in excluded) {
      expect(ids, isNot(contains(id)));
    }
  }
  if (vector['full'] case final List<Object?> full) expect(ids, full);
}

void _checkLosAngelesToday() {
  final losAngeles = zone('America/Los_Angeles');
  final now = tz.TZDateTime(losAngeles, 2026, 10, 20, 15);
  final nextMidnight = tz.TZDateTime(losAngeles, 2026, 10, 21);
  final tasks = {
    1: FilterableTask(
      id: 1,
      projectId: 1,
      dueDate: nextMidnight.subtract(const Duration(hours: 1)),
    ),
    2: FilterableTask(
      id: 2,
      projectId: 1,
      dueDate: nextMidnight.add(const Duration(hours: 1)),
    ),
    3: FilterableTask(
      id: 3,
      projectId: 1,
      done: true,
      dueDate: nextMidnight.subtract(const Duration(hours: 1)),
    ),
  };
  expect(
    matchingIds(
      parsed('done = false && due_date < now/d+1d'),
      tasks,
      FilterContext(now: now, location: losAngeles),
    ),
    [1],
  );
}

// The request part keeps include-nulls, the saved filter does not
// (`mergeRequestFilter`).
void _checkGanttInSavedFilter(Map<String, Object?> vector) {
  const project = 5;
  final tasks = {
    1: FilterableTask(
      id: 1,
      projectId: project,
      startDate: utc('2020-06-01T00:00:00Z'),
      endDate: utc('2020-06-10T00:00:00Z'),
      assigneeUsernames: const {fxUser1},
    ),
    2: const FilterableTask(
      id: 2,
      projectId: project,
      assigneeUsernames: {fxUser1},
    ),
    3: const FilterableTask(id: 3, projectId: project),
  };
  final saved = parsed(
    'done = false && project = $project && assignees in $fxUser1',
  );
  final request = parsed(vector['f']! as String).includingNulls();
  expect(matchingIds(request.and(saved), tasks, _context()), [1, 2]);
}

void _checkDerived(Map<String, Object?> vector) {
  final src = vector['src']! as String;
  final filter = (vector['f'] as String?) ?? '';
  final zoneName = (vector['tz'] as String?) ?? 'UTC';
  if (vector['err'] case final int code) {
    if (code == 2003) {
      expect(filterLocation(zoneName), isNull);
      return;
    }
    expect(_errorCode(filter), code);
    return;
  }
  if (vector['fixture'] case final String fixture) {
    return _checkInlineFixture(fixture, vector);
  }
  if (vector['parse'] case final List<Object?> rows) {
    expect(_flat(parsed(filter), _context()), rows);
    return;
  }
  if (vector['value'] case final String value) {
    final context = _context(zoneName: zoneName);
    final bound = _flat(parsed(filter), context).first.last;
    switch (value) {
      case 'now+1d':
        expect(bound, _datemath('now+1d', context));
      case 'Monday 00:00 of this week in tz':
        expect(bound, _iso(DateTime.utc(2026, 10, 19)));
      default:
        expect(bound, utc(value).toIso8601String());
    }
    return;
  }
  if (vector['rule'] case final String rule) {
    expect(rule, contains('stuff ?= progress'));
    final titled = {
      1: const FilterableTask(id: 1, projectId: 1, title: 'stuff ?= progress'),
      2: const FilterableTask(id: 2, projectId: 1, title: 'stuff in progress'),
    };
    expect(matchingIds(parsed(filter), titled, _context()), [1]);
    return;
  }
  if (vector['ids'] == 'no filter, no error') {
    expect(filterLocation(zoneName), isNull);
    expect(parseTaskFilter(filter), FilterExpression.matchAll);
    return;
  }
  if (src == 'tasks.go:313-320') {
    final ids = [
      for (final MapEntry(:key, :value) in fxTasks.entries)
        if (matchesTaskSearch(vector['search']! as String, value)) key,
    ];
    expect(ids, vector['ids']);
    return;
  }
  if (vector['view_filter'] case final String viewFilter) {
    final project = {for (final id in fxProject1) id: fxTasks[id]!};
    expect(
      matchingIds(parsed(filter).and(parsed(viewFilter)), project, _context()),
      vector['ids'],
    );
    return;
  }
  if (vector['view_search'] case final String viewSearch) {
    final project = {for (final id in fxProject1) id: fxTasks[id]!};
    final ids = [
      for (final MapEntry(:key, :value) in project.entries)
        if (matchesTaskSearch(viewSearch, value)) key,
    ];
    expect(ids, vector['ids']);
    return;
  }
  if (vector['saved_filter'] case final String _) {
    final merged = parsed(filter).includingNulls().and(parsed('done = false'));
    expect(
      matchingIds(merged, fxTasks, _context()).toSet(),
      _ids(vector['ids']),
    );
    return;
  }
  final ids = matchingIds(
    parsed(filter),
    fxTasks,
    _context(includeNulls: vector['nulls'] == true),
  );
  expect(ids.toSet(), _ids(vector['ids']));
}

void _checkInlineFixture(String fixture, Map<String, Object?> vector) {
  final tasks = <String, FilterableTask>{};
  if (fixture.startsWith('a:') || fixture == 'same') {
    tasks
      ..['a'] = const FilterableTask(id: 1, projectId: 1)
      ..['b'] = const FilterableTask(id: 2, projectId: 1, priority: 3)
      ..['c'] = const FilterableTask(id: 3, projectId: 1, priority: null)
      ..['d'] = const FilterableTask(id: 4, projectId: 1, priority: 1);
  } else if (fixture.startsWith('x:')) {
    tasks
      ..['x'] = const FilterableTask(id: 1, projectId: 1)
      ..['y'] = const FilterableTask(id: 2, projectId: 1, percentDone: 0.5);
  } else if (fixture.startsWith('t1')) {
    tasks
      ..['t1'] = const FilterableTask(id: 1, projectId: 1, title: 'abc')
      ..['t2'] = const FilterableTask(id: 2, projectId: 1, title: 'aXc');
  } else {
    fail('unknown inline fixture');
  }
  expect(
    matchingKeys(
      vector['f']! as String,
      tasks,
      _context(includeNulls: vector['nulls'] == true),
    ),
    vector['ids'],
  );
}

final _maps = <String, Map<int, String>>{
  'M': {1: 'lorem', 2: 'ipsum'},
  'Mr': {1: 'lorem', 2: 'ipsum'},
  'Filtertest→123': {123: 'Filtertest'},
  'label→456': {456: 'label'},
  "John's→1": {1: "John's"},
  "Mary's→2": {2: "Mary's"},
  "John's Task→1, Mary's→2 (exact)": {1: "John's Task", 2: "Mary's"},
  "1→John's Task": {1: "John's Task"},
  "2→Mary's Project": {2: "Mary's Project"},
  "1,2→John's Task, Mary's Project": {1: "John's Task", 2: "Mary's Project"},
  '→lorem': {1: 'lorem'},
  '→undefined': {},
  '→null': {},
  '1→My Label': {1: 'My Label'},
  '2→My Project': {2: 'My Project'},
};

// The web's resolvers compare case-insensitively.
const _apostrophes = {
  1: "John's Task",
  2: "Mary's Project",
  3: "User's Label",
  4: "It's Working",
};

Map<int, String> _lookup(String? spec, String input) {
  if (spec == null) return const {};
  if (spec == '→1') {
    // A resolver that answers 1 for whatever title it gets.
    final title = RegExp(r'= (\w+)').firstMatch(input)![1]!;
    return {1: title};
  }
  if (spec.startsWith('ci:') || spec == 'same' || spec == 'apostrophe map') {
    return _apostrophes;
  }
  return _maps[spec] ?? (throw StateError('unknown map $spec'));
}

void _checkTransform(Map<String, Object?> vector) {
  final forApi = vector['fn'] == 'forApi';
  String run(String input) {
    final lookups = LookupTables(
      labels: _lookup(vector['labels'] as String?, input),
      projects: _lookup(vector['projects'] as String?, input),
    );
    return forApi
        ? filterForApi(input, lookups: lookups)
        : filterFromApi(input, lookups: lookups);
  }

  switch (vector['cases']) {
    case final Map<String, Object?> cases:
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(run(key), value, reason: key);
      }
    case final String _:
      // `:420-426`, the inverse of `:22-29`.
      final forward = loadJsonl('language_web_transforms.jsonl').first;
      for (final MapEntry(:key, :value)
          in (forward['cases']! as Map<String, Object?>).entries) {
        expect(run(value! as String), key, reason: '$value');
      }
    default:
      expect(run(vector['in']! as String), vector['out']);
  }
}
