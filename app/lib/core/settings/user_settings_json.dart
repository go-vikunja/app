import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// `UserSettings` as the sync stores them in `sync_state`. Reading never
/// fails: a value this version cannot read is the defaults until the next
/// sync writes it again.
String encodeUserSettings(UserSettings settings) => jsonEncode({
  'name': settings.name,
  'email_reminders_enabled': settings.emailRemindersEnabled,
  'discoverable_by_name': settings.discoverableByName,
  'discoverable_by_email': settings.discoverableByEmail,
  'overdue_tasks_reminders_enabled': settings.overdueTasksRemindersEnabled,
  'overdue_tasks_reminders_time': settings.overdueTasksRemindersTime.wireName,
  'default_project_id': ?settings.defaultProjectId,
  'week_start': settings.weekStart,
  'timezone': settings.timezone,
  'language': settings.language,
  'quick_add_magic_mode': settings.quickAddMagicMode.wireName,
  'quick_add_default_reminders': [
    for (final period in settings.quickAddDefaultReminders) period.inSeconds,
  ],
  'filter_id_used_on_overview': ?settings.filterIdUsedOnOverview,
  'minimum_priority': settings.minimumPriority,
  'comment_sort_order': settings.commentSortOrder.wireName,
  'date_display': ?settings.dateDisplay?.wireName,
  'time_format': ?settings.timeFormat?.wireName,
  'color_schema': settings.colorSchema.wireName,
  'default_view': ?settings.defaultViewKind?.wireName,
});

UserSettings decodeUserSettings(String? stored) {
  final Object? json;
  try {
    json = stored == null ? null : jsonDecode(stored);
  } on FormatException {
    return const UserSettings();
  }
  if (json is! Map<String, Object?>) return const UserSettings();
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
    quickAddMagicMode: QuickAddMagicMode.fromWire(json['quick_add_magic_mode']),
    quickAddDefaultReminders: switch (json['quick_add_default_reminders']) {
      final List<Object?> periods => List.unmodifiable([
        for (final seconds in periods.whereType<int>())
          Duration(seconds: seconds),
      ]),
      _ => const [],
    },
    filterIdUsedOnOverview: switch (json['filter_id_used_on_overview']) {
      final int id when id < Project.favoritesId => id,
      _ => null,
    },
    minimumPriority: switch (json['minimum_priority']) {
      final int priority when priority >= 1 && priority <= 5 => priority,
      _ => 0,
    },
    commentSortOrder: CommentSortOrder.fromWire(json['comment_sort_order']),
    dateDisplay: DateDisplay.fromWire(json['date_display']),
    timeFormat: TimeFormat.fromWire(json['time_format']),
    colorSchema: ColorSchema.fromWire(json['color_schema']),
    defaultViewKind: switch (json['default_view']) {
      final String kind => ProjectViewKind.fromWire(kind),
      _ => null,
    },
  );
}
