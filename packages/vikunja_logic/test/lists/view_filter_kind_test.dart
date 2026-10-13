import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  test('no filter object: every task of the project', () {
    expect(classifyViewFilter(null), ViewFilterKind.none);
  });

  test("the server's default List view filter", () {
    expect(
      classifyViewFilter(const ViewFilter(filter: 'done = false')),
      ViewFilterKind.openOnly,
    );
  });

  final cases = <String, ViewFilterKind>{
    '': ViewFilterKind.none,
    '   ': ViewFilterKind.none,
    '\n\t': ViewFilterKind.none,
    'done = false': ViewFilterKind.openOnly,
    'done=false': ViewFilterKind.openOnly,
    '  done   =  false ': ViewFilterKind.openOnly,
    'Done = False': ViewFilterKind.openOnly,
    'DONE = FALSE': ViewFilterKind.openOnly,
    'done = 0': ViewFilterKind.openOnly,
    'done = true': ViewFilterKind.doneOnly,
    'done=TRUE': ViewFilterKind.doneOnly,
    'done = 1': ViewFilterKind.doneOnly,
    '\tdone = 1\n': ViewFilterKind.doneOnly,
    'done != true': ViewFilterKind.other,
    'done = false && priority >= 3': ViewFilterKind.other,
    'done = false || done = true': ViewFilterKind.other,
    '(done = false)': ViewFilterKind.other,
    "done = 'false'": ViewFilterKind.other,
    'done = f': ViewFilterKind.other,
    'done = 2': ViewFilterKind.other,
    'done = falsey': ViewFilterKind.other,
    'undone = false': ViewFilterKind.other,
    'd one = false': ViewFilterKind.other,
    'priority >= 3': ViewFilterKind.other,
    'due_date < now/d+1d': ViewFilterKind.other,
  };
  for (final MapEntry(key: filter, value: kind) in cases.entries) {
    test('${filter.isEmpty ? 'empty' : "'$filter'"} is ${kind.name}', () {
      expect(classifyViewFilter(ViewFilter(filter: filter)), kind);
    });
  }

  test('a search makes any filter other', () {
    for (final filter in ['', 'done = false', 'done = true']) {
      expect(
        classifyViewFilter(ViewFilter(filter: filter, search: 'zebra')),
        ViewFilterKind.other,
        reason: filter,
      );
    }
  });

  test('include nulls and the stored sort change nothing', () {
    expect(
      classifyViewFilter(
        const ViewFilter(
          filter: 'done = false',
          includeNulls: true,
          sortBy: ['priority'],
          orderBy: ['desc'],
        ),
      ),
      ViewFilterKind.openOnly,
    );
    expect(
      classifyViewFilter(const ViewFilter(includeNulls: true)),
      ViewFilterKind.none,
    );
  });
}
