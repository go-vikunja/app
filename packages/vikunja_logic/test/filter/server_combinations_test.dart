// How the server combined filters with views, saved filters and searches
// on the probe fixture (server.md §6–§8), rebuilt from the engine's parts.

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

final DateTime _now = utc('2026-10-20T08:05:00Z');

final Map<String, FilterableTask> _mainProject = {
  for (final MapEntry(:key, :value) in probeTasks.entries)
    if (value.projectId == mainProject) key: value,
};

String _keys(
  FilterExpression expression,
  Map<String, FilterableTask> scope, {
  bool includeNulls = false,
  String zoneName = 'GMT',
  String search = '',
}) {
  final bound = expression.bind(
    FilterContext(
      now: _now,
      location: zone(zoneName),
      includeNulls: includeNulls,
    ),
  );
  final searching = TaskSearchMatcher(search);
  return sortedKeys([
    for (final MapEntry(:key, :value) in scope.entries)
      if (bound.matches(value) && searching.matches(value)) key,
  ]).join(' ');
}

/// A project view: `(request) && (view)`, include-nulls if either has it.
String _view(
  String view, {
  String request = '',
  bool viewNulls = false,
  bool requestNulls = false,
  String zoneName = 'GMT',
  String search = '',
}) => _keys(
  parsed(request).and(parsed(view)),
  _mainProject,
  includeNulls: viewNulls || requestNulls,
  zoneName: zoneName,
  search: search,
);

/// A saved filter over `GET /tasks`'s scope.
String _saved(
  String saved, {
  bool savedNulls = false,
  String request = '',
  bool requestNulls = false,
  String zoneName = 'GMT',
  String search = '',
}) {
  final merged = mergeSavedFilter(
    saved: parsed(saved),
    savedIncludesNulls: savedNulls,
    request: parsed(request),
    requestIncludesNulls: requestNulls,
  );
  return _keys(
    merged.expression,
    probeAllTasks,
    includeNulls: merged.includeNulls,
    zoneName: zoneName,
    search: search,
  );
}

void main() {
  setUpAll(loadTimeZones);

  group('project views (§6)', () {
    test('a view covers its project only', () {
      expect(_view(''), 't1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12');
      expect(_view('project = $childProject'), '');
      expect(
        _view('project in $mainProject, $childProject'),
        't1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12',
      );
    });

    test("the request's filter is ANDed with the view's", () {
      expect(_view('done = false'), 't1 t2 t3 t4 t6 t7 t8 t10 t11 t12');
      expect(_view('done = false', request: 'done = true'), '');
      expect(
        _view('done = false', request: 'done = true || priority = 5'),
        't6',
      );
    });

    test("the view's include-nulls covers the request's filter", () {
      expect(
        _view('due_date < now', viewNulls: true),
        't3 t4 t5 t6 t7 t9 t10 t11 t12',
      );
      expect(
        _view('due_date < now', viewNulls: true, request: 'priority > 3'),
        't5 t6 t7 t9 t10 t11 t12',
      );
    });

    test("a view's search narrows like the request's", () {
      expect(_view('', search: 'alpha'), 't1 t9');
      expect(_view('done = false', search: 'alpha'), 't1');
    });

    test("the request's zone places the view's dates", () {
      const today = 'due_date >= now/d && due_date < now/d+1d';

      expect(_view(today), 't1 t2 t3');
      expect(_view(today, zoneName: 'Europe/Berlin'), 't1 t3 t4');
    });
  });

  group('saved filters (§8.5)', () {
    const urgentOpen = 'labels = $urgent && done = false';

    test('alone, and with a request filter ANDed', () {
      expect(_saved(urgentOpen), 'c1 t2 t3');
      expect(_saved(urgentOpen, request: 'priority = 2'), 't3');
      expect(_saved(urgentOpen, request: 'done = true'), '');
      expect(_saved(urgentOpen, request: 'project = $childProject'), 'c1');
      expect(_saved(urgentOpen, search: 'alpha'), 'c1');
    });

    test("a request's include-nulls stays with the request part", () {
      expect(
        _saved(urgentOpen, request: 'priority > 1', requestNulls: true),
        'c1 t3',
      );
      expect(
        _saved('priority > 2', request: 'labels = $urgent', requestNulls: true),
        'o1 t5 t6',
      );
      expect(_saved('priority > 2', requestNulls: true), 'o1 t4 t5 t6');
    });

    test("the saved filter's include-nulls covers the request too", () {
      expect(
        _saved('priority > 2', savedNulls: true),
        'c1 c2 g1 o1 o2 t1 t4 t5 t6 t7 t8 t9 t10 t11 t12',
      );
      for (final requestNulls in [false, true]) {
        expect(
          _saved(
            'priority > 2',
            savedNulls: true,
            request: 'labels = $urgent',
            requestNulls: requestNulls,
          ),
          'c1 c2 g1 o1 t1 t5 t6 t7 t8 t9 t10 t11 t12',
        );
      }
    });

    test("the owner's zone places a saved filter's dates", () {
      const today = 'due_date >= now/d && due_date < now/d+1d';

      expect(_saved(today), 'c1 t1 t2 t3');
      expect(_saved(today, zoneName: 'Europe/Berlin'), 'c1 t1 t3 t4');
    });

    test('an empty saved filter matches everything', () {
      const everything =
          'c1 c2 g1 o1 o2 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10 t11 t12';

      expect(_saved(''), everything);
      expect(_saved('', savedNulls: true), everything);
    });

    test('archived projects and pseudo projects stay out of reach', () {
      expect(_saved('labels = $urgent'), 'c1 t2 t3 t5');
      expect(_saved('project = $archivedProject'), '');
      expect(_saved('project = -1'), '');
      expect(_saved('project = -563'), '');
    });

    test("a view's filter on a saved filter is ANDed", () {
      expect(_saved(urgentOpen, request: 'priority = 2'), 't3');
      expect(_saved(urgentOpen, request: 'project = $childProject'), 'c1');
      expect(_saved('labels = $urgent'), 'c1 t2 t3 t5');
    });
  });

  test('mergeSavedFilter returns the parts it does not need to touch', () {
    final saved = parsed('done = false');

    expect(mergeSavedFilter(saved: saved, savedIncludesNulls: true), (
      expression: saved,
      includeNulls: true,
    ));
    expect(
      mergeSavedFilter(
        saved: FilterExpression.matchAll,
        savedIncludesNulls: false,
        request: saved,
        requestIncludesNulls: true,
      ),
      (expression: saved, includeNulls: true),
    );
  });
}
