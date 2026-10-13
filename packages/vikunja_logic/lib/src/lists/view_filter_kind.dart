import 'package:vikunja_domain/vikunja_domain.dart';

/// How far the app can evaluate a view's filter on the device.
enum ViewFilterKind {
  /// No filter and no search: every task of the project.
  none,

  /// Exactly `done = false` (the server's default List view filter).
  openOnly,

  /// Exactly `done = true`.
  doneOnly,

  /// Anything else; only the server's answer tells which tasks match.
  other,
}

/// Whitespace and the case of `done`, `true` and `false` do not matter, and
/// `1`/`0` count as true/false; `filter_include_nulls` and the stored sort
/// do not affect the result (the server ignores a view's sort).
ViewFilterKind classifyViewFilter(ViewFilter? filter) {
  if (filter == null) return ViewFilterKind.none;
  if (filter.search.isNotEmpty) return ViewFilterKind.other;
  if (filter.filter.trim().isEmpty) return ViewFilterKind.none;
  return switch (_doneOnly.firstMatch(filter.filter)?[1]?.toLowerCase()) {
    'false' || '0' => ViewFilterKind.openOnly,
    'true' || '1' => ViewFilterKind.doneOnly,
    _ => ViewFilterKind.other,
  };
}

final _doneOnly = RegExp(
  r'^\s*done\s*=\s*(true|false|1|0)\s*$',
  caseSensitive: false,
);
