import 'dart:convert';

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
  static String lastViewKey(int projectId) => 'last_view:$projectId';
  static const upcomingKey = 'upcoming';

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
  Future<int?> lastViewOf(int projectId) async => switch (_decode(
    await _db.listPreferencesDao.read(lastViewKey(projectId)),
  )) {
    {'view_id': final int viewId} when viewId >= 0 => viewId,
    _ => null,
  };

  @override
  Future<void> rememberView(int projectId, int viewId) => _db.listPreferencesDao
      .write(lastViewKey(projectId), jsonEncode({'view_id': viewId}));

  @override
  Stream<UpcomingPreferences> watchUpcoming() => _db.listPreferencesDao
      .watchValue(upcomingKey)
      .map(decodeUpcomingPreferences)
      .distinct();

  @override
  Future<void> saveUpcoming(UpcomingPreferences preferences) => _db
      .listPreferencesDao
      .write(upcomingKey, encodeUpcomingPreferences(preferences));
}

String encodeViewPreferences(ViewPreferences preferences) => jsonEncode({
  'sort': preferences.sort.wireName,
  'show_done': preferences.showDone,
});

ViewPreferences decodeViewPreferences(String? stored) {
  final json = _decode(stored);
  return ViewPreferences(
    sort: TaskListSort.fromWireName(switch (json['sort']) {
      final String sort => sort,
      _ => null,
    }),
    showDone: json['show_done'] == true,
  );
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

Map<String, Object?> _decode(String? stored) {
  if (stored == null) return const {};
  try {
    return switch (jsonDecode(stored)) {
      final Map<String, Object?> json => json,
      _ => const {},
    };
  } on FormatException {
    return const {};
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
