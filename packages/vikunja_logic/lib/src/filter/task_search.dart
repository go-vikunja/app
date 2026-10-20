import 'package:vikunja_logic/src/filter/filterable_task.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';
import 'package:vikunja_logic/src/filter/sql_text.dart';

/// The server's `s`/`q` search without ParadeDB: [search] (trimmed) is a
/// substring of the title or the stored description, ignoring ASCII case,
/// with `%` and `_` as wildcards; the first `#12` in it also matches index
/// 12 in any project. An empty search matches everything.
bool matchesTaskSearch(String search, FilterableTask task) =>
    TaskSearchMatcher(search).matches(task);

/// [matchesTaskSearch] prepared once for many tasks.
final class TaskSearchMatcher {
  new(String search) : this._trimmed(goTrimSpace(search));

  new _trimmed(String text)
    : _pattern = text.isEmpty ? null : ContainsPattern(text),
      _index = _indexIn(text);

  final ContainsPattern? _pattern;
  final int? _index;

  bool matches(FilterableTask task) {
    final pattern = _pattern;
    if (pattern == null) return true;
    return pattern.matches(task.title) ||
        pattern.matches(task.description) ||
        task.index == _index;
  }
}

final _indexReference = RegExp('#([0-9]+)');

int? _indexIn(String text) {
  final index = goParseInt(_indexReference.firstMatch(text)?[1] ?? '');
  return index != null && index > 0 ? index : null;
}
