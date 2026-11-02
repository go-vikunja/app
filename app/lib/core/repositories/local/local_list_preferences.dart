import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';

/// [ListPreferences] in the account's database, one JSON value per key.
/// Reading never fails: a value this version cannot read is the default,
/// field by field.
final class LocalListPreferences implements ListPreferences {
  new(this._db);

  final AppDatabase _db;

  static String viewKey(String listKey) => 'list:$listKey';
  static const upcomingKey = 'upcoming';
  static const projectTreeKey = 'projects';
  static const tableColumnsKey = 'table_columns';

  /// Written by versions that reopened a project on the view it showed
  /// last; nothing reads it now, [forget] still removes it.
  static String lastViewKey(int projectId) => 'last_view:$projectId';

  @override
  Stream<ViewPreferences> watchView(String listKey) => _db.listPreferencesDao
      .watchValue(viewKey(listKey))
      .map(decodeViewPreferences)
      .distinct();

  @override
  Future<void> saveView(String listKey, ViewPreferences preferences) => _db
      .listPreferencesDao
      .write(viewKey(listKey), encodeViewPreferences(preferences));

  @override
  Stream<UpcomingPreferences> watchUpcoming() => _db.listPreferencesDao
      .watchValue(upcomingKey)
      .map(decodeUpcomingPreferences)
      .distinct();

  @override
  Future<void> saveUpcoming(UpcomingPreferences preferences) => _db
      .listPreferencesDao
      .write(upcomingKey, encodeUpcomingPreferences(preferences));

  @override
  Stream<ProjectTreePreferences> watchProjectTree() => _db.listPreferencesDao
      .watchValue(projectTreeKey)
      .map(decodeProjectTreePreferences)
      .distinct();

  @override
  Future<void> saveProjectTree(ProjectTreePreferences preferences) => _db
      .listPreferencesDao
      .write(projectTreeKey, encodeProjectTreePreferences(preferences));

  @override
  Stream<Set<TableColumn>> watchTableColumns() => _db.listPreferencesDao
      .watchValue(tableColumnsKey)
      .map(decodeTableColumns)
      .distinct(setEquals);

  @override
  Future<void> saveTableColumns(Set<TableColumn> columns) => _db
      .listPreferencesDao
      .write(tableColumnsKey, encodeTableColumns(columns));

  /// Drops what is kept for deleted projects and views: their lists' sort
  /// and done preferences, a table's sort, a timeline's range and zoom, an
  /// old version's last view and the collapsed state.
  Future<void> forget({
    Set<int> projectIds = const {},
    Set<int> viewIds = const {},
  }) => _db.transaction(() async {
    final dao = _db.listPreferencesDao;
    await dao.removeAll([
      for (final viewId in viewIds)
        viewKey(listKeyFor(projectId: 0, viewId: viewId)),
      for (final projectId in projectIds) ...[
        viewKey(listKeyFor(projectId: projectId, viewId: 0)),
        lastViewKey(projectId),
      ],
    ]);
    if (projectIds.isEmpty) return;
    final tree = decodeProjectTreePreferences(await dao.read(projectTreeKey));
    if (!tree.collapsed.any(projectIds.contains)) return;
    await saveProjectTree(
      tree.copyWith(collapsed: tree.collapsed.difference(projectIds)),
    );
  });
}

String encodeViewPreferences(ViewPreferences preferences) => jsonEncode({
  'sort': preferences.sort.wireName,
  'show_done': preferences.showDone,
  'table_sort': preferences.tableSort.wireName,
  'timeline': _encodeTimeline(preferences.timeline),
});

ViewPreferences decodeViewPreferences(String? stored) {
  final json = _decode(stored);
  return ViewPreferences(
    sort: TaskListSort.fromWireName(switch (json['sort']) {
      final String sort => sort,
      _ => null,
    }),
    showDone: json['show_done'] == true,
    tableSort: TableSort.fromWireName(switch (json['table_sort']) {
      final String sort => sort,
      _ => null,
    }),
    timeline: _decodeTimeline(json['timeline']),
  );
}

Map<String, Object?> _encodeTimeline(TimelinePreferences timeline) => {
  'range': timeline.customRange?.toJson() ?? 'default',
  'without_dates': timeline.withoutDates,
  'day_width': timeline.dayWidth,
};

TimelinePreferences _decodeTimeline(Object? stored) {
  const defaults = TimelinePreferences();
  if (stored is! Map<String, Object?>) return defaults;
  return TimelinePreferences(
    customRange: GanttRange.fromJson(stored['range']),
    withoutDates: stored['without_dates'] == true,
    dayWidth: switch (stored['day_width']) {
      final num width when width.isFinite => width.toDouble().clamp(
        TimelinePreferences.minDayWidth,
        TimelinePreferences.maxDayWidth,
      ),
      _ => defaults.dayWidth,
    },
  );
}

/// The web's keys, in its column order.
String encodeTableColumns(Set<TableColumn> columns) => jsonEncode([
  for (final column in TableColumn.values)
    if (columns.contains(column)) column.wireName,
]);

/// [TableColumn.defaults] when none is known.
Set<TableColumn> decodeTableColumns(String? stored) {
  final keys = switch (_decodeJson(stored)) {
    final List<Object?> keys => keys,
    _ => const <Object?>[],
  };
  final columns = {
    for (final key in keys) ?TableColumn.fromWire(key is String ? key : null),
  };
  return columns.isEmpty ? TableColumn.defaults : Set.unmodifiable(columns);
}

String encodeUpcomingPreferences(UpcomingPreferences preferences) =>
    jsonEncode({
      'preset': preferences.preset?.name,
      'custom_from': ?_encodeDate(preferences.customFrom),
      'custom_to': ?_encodeDate(preferences.customTo),
      'show_overdue': preferences.showOverdue,
      'show_without_due_date': preferences.showWithoutDueDate,
    });

UpcomingPreferences decodeUpcomingPreferences(String? stored) {
  final json = _decode(stored);
  const defaults = UpcomingPreferences();
  final customFrom = _decodeDate(json['custom_from']);
  final customTo = _decodeDate(json['custom_to']);
  final custom =
      json.containsKey('preset') &&
      json['preset'] == null &&
      customFrom != null &&
      customTo != null;
  return UpcomingPreferences(
    preset: custom
        ? null
        : DateRangePreset.fromName(switch (json['preset']) {
                final String name => name,
                _ => null,
              }) ??
              defaults.preset,
    customFrom: customFrom,
    customTo: customTo,
    showOverdue: switch (json['show_overdue']) {
      final bool show => show,
      _ => defaults.showOverdue,
    },
    showWithoutDueDate: switch (json['show_without_due_date']) {
      final bool show => show,
      _ => defaults.showWithoutDueDate,
    },
  );
}

String encodeProjectTreePreferences(ProjectTreePreferences preferences) =>
    jsonEncode({
      'show_archived': preferences.showArchived,
      'show_saved_filters': preferences.showSavedFilters,
      'collapsed': preferences.collapsed.toList()..sort(),
    });

ProjectTreePreferences decodeProjectTreePreferences(String? stored) {
  final json = _decode(stored);
  return ProjectTreePreferences(
    showArchived: json['show_archived'] == true,
    showSavedFilters: json['show_saved_filters'] != false,
    collapsed: switch (json['collapsed']) {
      final List<Object?> ids => Set.unmodifiable(ids.whereType<int>()),
      _ => const {},
    },
  );
}

Map<String, Object?> _decode(String? stored) => switch (_decodeJson(stored)) {
  final Map<String, Object?> json => json,
  _ => const {},
};

Object? _decodeJson(String? stored) {
  if (stored == null) return null;
  try {
    return jsonDecode(stored);
  } on FormatException {
    return null;
  }
}

/// A local calendar date, `YYYY-MM-DD`.
String? _encodeDate(DateTime? date) {
  if (date == null) return null;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-'
      '${two(date.day)}';
}

DateTime? _decodeDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final [year, month, day] = [
    for (var group = 1; group <= 3; group++) int.parse(match[group]!),
  ];
  final date = DateTime(year, month, day);
  // Rejects dates like 2026-02-31, which DateTime would roll over.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
