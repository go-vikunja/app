import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';
import 'package:vikunja_logic/src/filter/web_conditions.dart';

/// Label and project titles by id, for the web's title ↔ id transforms.
/// A title resolves to the first entry whose title equals it ignoring case.
@immutable
final class LookupTables {
  const new({this.labels = const {}, this.projects = const {}});

  final Map<int, String> labels;

  /// Real projects only.
  final Map<int, String> projects;
}

/// Label and project ids a filter's text holds as numbers.
@immutable
final class FilterIds {
  const new({this.labels = const {}, this.projects = const {}});

  final Set<int> labels;
  final Set<int> projects;

  FilterIds union(FilterIds other) => FilterIds(
    labels: {...labels, ...other.labels},
    projects: {...projects, ...other.projects},
  );
}

/// The web's `transformFilterStringForApi`: known camelCase fields
/// (`dueDate`, any case) become snake_case, label and project titles in
/// `labels` and `project` conditions ids (quotes stripped, list items
/// joined with `, `); titles nothing has stay as typed. Operators are
/// matched longest first, where the web reads `labels >= 5` as `>` with the
/// value `= 5` and breaks it. A number among [keepIds] stays that id even
/// when a label or project has it as its title.
String filterForApi(
  String text, {
  required LookupTables lookups,
  FilterIds keepIds = const FilterIds(),
}) {
  var result = text.trim();
  if (result.isEmpty) return '';
  for (final field in _webFields) {
    result = result.replaceAllMapped(
      RegExp('\\b($field)(\\s*$_operator)', caseSensitive: false),
      (match) => '$field${match[2]}',
    );
  }
  result = _resolveTitles(result, 'labels', lookups.labels, keepIds.labels);
  result = _resolveTitles(
    result,
    'project',
    lookups.projects,
    keepIds.projects,
  );
  for (final MapEntry(key: camel, value: snake) in _snakeCase.entries) {
    result = result.replaceAllMapped(
      RegExp('\\b($camel)(\\s*$_operator)'),
      (match) => '$snake${match[2]}',
    );
  }
  return result;
}

/// The web's `transformFilterStringFromApi`: snake_case fields become
/// camelCase and label and project ids titles, for display. Unlike the
/// web it renames fields only where an operator follows, never inside
/// values (`created_by_id` stays), reads ids strictly, and keeps an id
/// whose title would not come back to the same id through [filterForApi]
/// (quoting a single title with `&`, `|`, `(`, `)`, `<` or a leading quote
/// instead).
String filterFromApi(String text, {required LookupTables lookups}) {
  if (text.trim().isEmpty) return '';
  var result = text;
  for (final MapEntry(key: camel, value: snake) in _snakeCase.entries) {
    result = result.replaceAllMapped(
      RegExp('\\b($snake)(?=\\s*$_operator)'),
      (_) => camel,
    );
  }
  result = _showTitles(result, 'labels', lookups.labels);
  return _showTitles(result, 'project', lookups.projects);
}

/// The label and project ids of [text] (as the server takes it) that
/// [filterFromApi] shows as numbers, because nothing here has a title for
/// them that comes back to the same id. Pass them to [filterForApi] so
/// that an edit elsewhere in the filter keeps them.
FilterIds untitledFilterIds(String text, {required LookupTables lookups}) =>
    FilterIds(
      labels: _untitledIds(text, 'labels', lookups.labels),
      projects: _untitledIds(text, 'project', lookups.projects),
    );

Set<int> _untitledIds(String text, String field, Map<int, String> table) => {
  for (final condition in webConditions(text, field))
    if (condition.value.trim() case final keyword when keyword.isNotEmpty)
      for (final item
          in _listOperators.contains(condition.operator)
              ? keyword.split(',').map(_trimQuotes)
              : [keyword])
        if (goParseInt(item) case final id?
            when _shownTitle(
                  item,
                  table,
                  inList: _listOperators.contains(condition.operator),
                ) ==
                null)
          id,
};

const List<String> _webFields = [
  'done',
  'priority',
  'percentDone',
  'dueDate',
  'startDate',
  'endDate',
  'doneAt',
  'reminders',
  'created',
  'updated',
  'assignees',
  'createdBy',
  'labels',
  'project',
];

const Map<String, String> _snakeCase = {
  'percentDone': 'percent_done',
  'dueDate': 'due_date',
  'startDate': 'start_date',
  'endDate': 'end_date',
  'doneAt': 'done_at',
  'createdBy': 'created_by',
};

const String _operator = r'(!=|>=|<=|=|>|<|\blike\b|\bnot in\b|\bin\b|\?=)';

const Set<String> _listOperators = {'in', 'not in', '?=', '?!='};

int? _idTitled(String title, Map<int, String> table) {
  final wanted = title.toLowerCase();
  for (final MapEntry(key: id, value: candidate) in table.entries) {
    if (candidate.toLowerCase() == wanted) return id;
  }
  return null;
}

final _quotes = RegExp('["\']');

String _resolveTitles(
  String text,
  String field,
  Map<int, String> table,
  Set<int> keepIds,
) => replaceWebConditions(text, field, (condition) {
  final operator = condition.operator;
  final keyword = condition.value;
  if (keyword.isEmpty) {
    return text.substring(condition.start, condition.end);
  }
  final items = _listOperators.contains(operator)
      ? keyword.trim().split(',').map(_trimQuotes)
      : [keyword.trim()];
  final value = items
      .map((item) {
        if (goParseInt(item) case final id? when keepIds.contains(id)) {
          return item;
        }
        final id =
            _idTitled(item, table) ??
            _idTitled(item.replaceAll(r'\', ''), table);
        return id?.toString() ?? item;
      })
      .join(', ')
      .replaceAll(_quotes, '');
  return '$field $operator $value';
});

/// Trimmed, and without quotes when the same kind encloses it.
String _trimQuotes(String item) {
  final trimmed = item.trim();
  final enclosed =
      trimmed.length >= 2 &&
      (trimmed.startsWith('"') && trimmed.endsWith('"') ||
          trimmed.startsWith("'") && trimmed.endsWith("'"));
  return enclosed ? trimmed.substring(1, trimmed.length - 1) : trimmed;
}

String _showTitles(String text, String field, Map<int, String> table) =>
    replaceWebConditions(text, field, (condition) {
      final operator = condition.operator;
      final keyword = condition.value.trim();
      if (keyword.isEmpty) {
        return text.substring(condition.start, condition.end);
      }
      if (!_listOperators.contains(operator)) {
        return '$field $operator '
            '${_shownTitle(keyword, table, inList: false) ?? keyword}';
      }
      final items = [
        for (final item in keyword.split(','))
          if (_trimQuotes(item) case final id)
            _shownTitle(id, table, inList: true) ?? id,
      ];
      return '$field $operator ${items.join(', ')}';
    });

final _unsafeInValue = RegExp('[&|()<]');

/// How [filterForApi] gets id [text] back from its title, or null when it
/// cannot.
String? _shownTitle(
  String text,
  Map<int, String> table, {
  required bool inList,
}) {
  final id = goParseInt(text);
  final title = id == null ? null : table[id];
  if (title == null || title.isEmpty || _idTitled(title, table) != id) {
    return null;
  }
  // filterForApi trims what it reads, so blanks around a title are lost.
  if (title != title.trim()) return null;
  final bare =
      !_unsafeInValue.hasMatch(title) &&
      !title.startsWith(_quotes) &&
      !(inList &&
          (title.contains(',') || title.endsWith('"') || title.endsWith("'")));
  if (bare) return title;
  if (inList || title.contains(r'\')) return null;
  if (!title.contains('"')) return '"$title"';
  if (!title.contains("'")) return "'$title'";
  return null;
}
