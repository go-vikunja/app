import 'package:vikunja_domain/vikunja_domain.dart';

/// The `settings` of `GET /user`. Every field the client does not
/// understand falls back to the server's or the web's default, because
/// `frontend_settings` is whatever JSON any client stored there.
UserSettings parseUserSettings(Object? json) {
  if (json is! Map<String, Object?>) return const UserSettings();
  final frontend = switch (json['frontend_settings']) {
    final Map<String, Object?> map => map,
    _ => const <String, Object?>{},
  };
  return userSettingsFrom(
    json,
    frontend,
    quickAddDefaultReminders: switch (frontend['quick_add_default_reminders']) {
      final List<Object?> entries => List.unmodifiable([
        for (final entry in entries)
          if (entry case {'relative_period': final int seconds})
            Duration(seconds: seconds),
      ]),
      _ => const [],
    },
  );
}

/// The settings from the account fields in [top] and the web's in
/// [frontend], which `GET /user` nests under `frontend_settings` and the
/// app's stored copy keeps beside them; the reminders' shape differs, so
/// the caller reads them.
UserSettings userSettingsFrom(
  Map<String, Object?> top,
  Map<String, Object?> frontend, {
  required List<Duration> quickAddDefaultReminders,
}) => UserSettings(
  name: switch (top['name']) {
    final String name => name,
    _ => '',
  },
  emailRemindersEnabled: top['email_reminders_enabled'] == true,
  discoverableByName: top['discoverable_by_name'] == true,
  discoverableByEmail: top['discoverable_by_email'] == true,
  overdueTasksRemindersEnabled: top['overdue_tasks_reminders_enabled'] != false,
  overdueTasksRemindersTime:
      ClockTime.tryParse(top['overdue_tasks_reminders_time']) ??
      UserSettings.defaultOverdueTasksRemindersTime,
  defaultProjectId: switch (top['default_project_id']) {
    final int id when id > 0 => id,
    _ => null,
  },
  weekStart: switch (top['week_start']) {
    final int day when day >= 0 && day <= 6 => day,
    _ => 0,
  },
  timezone: switch (top['timezone']) {
    final String timezone => timezone,
    _ => '',
  },
  language: switch (top['language']) {
    final String language => language,
    _ => '',
  },
  quickAddMagicMode: QuickAddMagicMode.fromWire(
    frontend['quick_add_magic_mode'],
  ),
  quickAddDefaultReminders: quickAddDefaultReminders,
  // A saved filter's pseudo project id: -1 is Favorites, 0 and up real
  // projects.
  filterIdUsedOnOverview: switch (frontend['filter_id_used_on_overview']) {
    final int id when id <= -2 => id,
    _ => null,
  },
  minimumPriority: switch (frontend['minimum_priority']) {
    final int priority when priority >= 1 && priority <= 5 => priority,
    _ => 0,
  },
  commentSortOrder: CommentSortOrder.fromWire(frontend['comment_sort_order']),
  dateDisplay: DateDisplay.fromWire(frontend['date_display']),
  timeFormat: TimeFormat.fromWire(frontend['time_format']),
  colorSchema: ColorSchema.fromWire(frontend['color_schema']),
  defaultViewKind: switch (frontend['default_view']) {
    final String kind => ProjectViewKind.fromWire(kind),
    _ => null,
  },
  defaultDueTime: _parseDefaultDueTime(frontend['default_due_time']),
  defaultTaskRelationType: switch (frontend['default_task_relation_type']) {
    final String kind =>
      TaskRelationKind.fromWire(kind) ?? TaskRelationKind.related,
    _ => TaskRelationKind.related,
  },
);

// The web's getDateWithTime takes only two-digit hours, where the server's
// own times also allow one.
final _twoDigitTime = RegExp(r'^\d{2}:\d{2}$');

ClockTime? _parseDefaultDueTime(Object? value) =>
    value is String && _twoDigitTime.hasMatch(value)
    ? ClockTime.tryParse(value)
    : null;
