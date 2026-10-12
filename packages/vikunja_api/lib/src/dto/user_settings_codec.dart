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
  );
}
