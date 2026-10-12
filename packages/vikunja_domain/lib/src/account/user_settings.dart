import 'package:meta/meta.dart';

/// `frontend_settings.quick_add_magic_mode`; the web defaults to vikunja.
enum QuickAddMagicMode {
  disabled('disabled'),
  vikunja('vikunja'),
  todoist('todoist');

  new(this.wireName);

  final String wireName;

  static QuickAddMagicMode fromWire(Object? value) =>
      values.where((mode) => mode.wireName == value).firstOrNull ?? vikunja;
}

/// The signed-in user's settings as the server stores them, read with the
/// user (`GET /user`). Read-only until step 30.
@immutable
final class UserSettings {
  const new({
    this.defaultProjectId,
    this.weekStart = 0,
    this.timezone = '',
    this.language = '',
    this.quickAddMagicMode = QuickAddMagicMode.vikunja,
    this.quickAddDefaultReminders = const [],
  });

  /// Null when unset (the server's 0).
  final int? defaultProjectId;

  /// 0 = Sunday … 6 = Saturday.
  final int weekStart;
  final String timezone;
  final String language;
  final QuickAddMagicMode quickAddMagicMode;

  /// `frontend_settings.quick_add_default_reminders`: periods relative to
  /// the due date, negative before it.
  final List<Duration> quickAddDefaultReminders;

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
      other.defaultProjectId == defaultProjectId &&
      other.weekStart == weekStart &&
      other.timezone == timezone &&
      other.language == language &&
      other.quickAddMagicMode == quickAddMagicMode &&
      _sameDurations(other.quickAddDefaultReminders, quickAddDefaultReminders);

  @override
  int get hashCode => Object.hash(
    defaultProjectId,
    weekStart,
    timezone,
    language,
    quickAddMagicMode,
    Object.hashAll(quickAddDefaultReminders),
  );

  static bool _sameDurations(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
