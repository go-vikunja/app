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
  return UserSettings(
    name: switch (json['name']) {
      final String name => name,
      _ => '',
    },
    emailRemindersEnabled: json['email_reminders_enabled'] == true,
    discoverableByName: json['discoverable_by_name'] == true,
    discoverableByEmail: json['discoverable_by_email'] == true,
    overdueTasksRemindersEnabled:
        json['overdue_tasks_reminders_enabled'] != false,
    overdueTasksRemindersTime:
        ClockTime.tryParse(json['overdue_tasks_reminders_time']) ??
        UserSettings.defaultOverdueTasksRemindersTime,
    defaultProjectId: switch (json['default_project_id']) {
      final int id when id > 0 => id,
      _ => null,
    },
    weekStart: switch (json['week_start']) {
      final int day when day >= 0 && day <= 6 => day,
      _ => 0,
    },
    timezone: switch (json['timezone']) {
      final String timezone => timezone,
      _ => '',
    },
    language: switch (json['language']) {
      final String language => language,
      _ => '',
    },
    quickAddMagicMode: QuickAddMagicMode.fromWire(
      frontend['quick_add_magic_mode'],
    ),
    quickAddDefaultReminders: switch (frontend['quick_add_default_reminders']) {
      final List<Object?> entries => List.unmodifiable([
        for (final entry in entries)
          if (entry case {'relative_period': final int seconds})
            Duration(seconds: seconds),
      ]),
      _ => const [],
    },
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
  );
}
