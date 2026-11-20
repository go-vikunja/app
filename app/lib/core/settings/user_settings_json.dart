import 'dart:convert';

import 'package:vikunja_api/vikunja_api.dart' show userSettingsFrom;
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
  'default_due_time': ?settings.defaultDueTime?.wireName,
  'default_task_relation_type': settings.defaultTaskRelationType.wireName,
});

UserSettings decodeUserSettings(String? stored) {
  final Object? json;
  try {
    json = stored == null ? null : jsonDecode(stored);
  } on FormatException {
    return const UserSettings();
  }
  if (json is! Map<String, Object?>) return const UserSettings();
  return userSettingsFrom(
    json,
    json,
    quickAddDefaultReminders: switch (json['quick_add_default_reminders']) {
      final List<Object?> periods => List.unmodifiable([
        for (final seconds in periods.whereType<int>())
          Duration(seconds: seconds),
      ]),
      _ => const [],
    },
  );
}
