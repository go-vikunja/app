import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

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

/// `frontend_settings.comment_sort_order`; the web defaults to `asc`.
enum CommentSortOrder {
  oldestFirst('asc'),
  newestFirst('desc');

  new(this.wireName);

  final String wireName;

  static CommentSortOrder fromWire(Object? value) =>
      values.where((order) => order.wireName == value).firstOrNull ??
      oldestFirst;
}

/// `frontend_settings.date_display`; null on [UserSettings] when the user
/// never set it, so the app keeps its own formats.
enum DateDisplay {
  relative('relative'),
  monthDayYearDashed('mm-dd-yyyy'),
  dayMonthYearDashed('dd-mm-yyyy'),
  yearMonthDayDashed('yyyy-mm-dd'),
  monthDayYearSlashed('mm/dd/yyyy'),
  dayMonthYearSlashed('dd/mm/yyyy'),
  yearMonthDaySlashed('yyyy/mm/dd'),
  dayMonthYear('dayMonthYear'),
  weekdayDayMonthYear('weekdayDayMonthYear');

  new(this.wireName);

  final String wireName;

  static DateDisplay? fromWire(Object? value) =>
      values.where((display) => display.wireName == value).firstOrNull;
}

/// `frontend_settings.time_format`; null when never set (the device's
/// 12/24-hour setting applies).
enum TimeFormat {
  twelveHour('12h'),
  twentyFourHour('24h');

  new(this.wireName);

  final String wireName;

  static TimeFormat? fromWire(Object? value) =>
      values.where((format) => format.wireName == value).firstOrNull;
}

/// `frontend_settings.color_schema`; the web defaults to auto.
enum ColorSchema {
  light('light'),
  auto('auto'),
  dark('dark');

  new(this.wireName);

  final String wireName;

  static ColorSchema fromWire(Object? value) =>
      values.where((schema) => schema.wireName == value).firstOrNull ?? auto;
}

/// A time of day in the server's settings: Go's `15:04` layout, so `9:00`
/// and `09:00` are both valid and `09:00:00` is not.
@immutable
final class ClockTime {
  const new(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hour'),
      assert(minute >= 0 && minute < 60, 'minute');

  final int hour;
  final int minute;

  static final _layout = RegExp(r'^(\d{1,2}):(\d{2})$');

  static ClockTime? tryParse(Object? value) {
    if (value is! String) return null;
    final match = _layout.firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return ClockTime(hour, minute);
  }

  /// Zero-padded, as the web's time input sends it.
  String get wireName =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ClockTime($wireName)';
}

const _unset = Object();

/// The signed-in user's settings as the server stores them, read with the
/// user (`GET /user`). Settings the app does not model, among them every
/// other `frontend_settings` key, are never held here: a write starts from
/// the server's own copy (`UserSettingsWritePort`).
@immutable
final class UserSettings {
  const new({
    this.name = '',
    this.emailRemindersEnabled = false,
    this.discoverableByName = false,
    this.discoverableByEmail = false,
    this.overdueTasksRemindersEnabled = true,
    this.overdueTasksRemindersTime = defaultOverdueTasksRemindersTime,
    this.defaultProjectId,
    this.weekStart = 0,
    this.timezone = '',
    this.language = '',
    this.quickAddMagicMode = QuickAddMagicMode.vikunja,
    this.quickAddDefaultReminders = const [],
    this.filterIdUsedOnOverview,
    this.minimumPriority = 0,
    this.commentSortOrder = CommentSortOrder.oldestFirst,
    this.dateDisplay,
    this.timeFormat,
    this.colorSchema = ColorSchema.auto,
    this.defaultViewKind,
  });

  static const defaultOverdueTasksRemindersTime = ClockTime(9, 0);

  /// The same as the user's top-level `name`; empty shows the username.
  final String name;

  /// Emails from the server, unlike the app's own notifications.
  final bool emailRemindersEnabled;
  final bool discoverableByName;
  final bool discoverableByEmail;

  /// A daily email listing the undone overdue tasks, at
  /// [overdueTasksRemindersTime] in [timezone].
  final bool overdueTasksRemindersEnabled;
  final ClockTime overdueTasksRemindersTime;

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

  /// `frontend_settings.filter_id_used_on_overview`: the pseudo project id
  /// (-2 or lower) of the saved filter the Overview shows; null when unset.
  final int? filterIdUsedOnOverview;

  /// `frontend_settings.minimum_priority`; 0 when unset.
  final int minimumPriority;

  final CommentSortOrder commentSortOrder;

  /// Null when never set.
  final DateDisplay? dateDisplay;

  /// Null when never set.
  final TimeFormat? timeFormat;
  final ColorSchema colorSchema;

  /// `frontend_settings.default_view`; null for `first` (the default): the
  /// first view by position.
  final ProjectViewKind? defaultViewKind;

  /// The lowest priority a task row shows; the web reads an unset value
  /// as medium.
  int get effectiveMinimumPriority => minimumPriority > 0 ? minimumPriority : 2;

  /// [defaultProjectId], [filterIdUsedOnOverview], [dateDisplay],
  /// [timeFormat] and [defaultViewKind] take null to unset them; leaving one
  /// out keeps it.
  UserSettings copyWith({
    String? name,
    bool? emailRemindersEnabled,
    bool? discoverableByName,
    bool? discoverableByEmail,
    bool? overdueTasksRemindersEnabled,
    ClockTime? overdueTasksRemindersTime,
    Object? defaultProjectId = _unset,
    int? weekStart,
    String? timezone,
    String? language,
    QuickAddMagicMode? quickAddMagicMode,
    List<Duration>? quickAddDefaultReminders,
    Object? filterIdUsedOnOverview = _unset,
    int? minimumPriority,
    CommentSortOrder? commentSortOrder,
    Object? dateDisplay = _unset,
    Object? timeFormat = _unset,
    ColorSchema? colorSchema,
    Object? defaultViewKind = _unset,
  }) => UserSettings(
    name: name ?? this.name,
    emailRemindersEnabled: emailRemindersEnabled ?? this.emailRemindersEnabled,
    discoverableByName: discoverableByName ?? this.discoverableByName,
    discoverableByEmail: discoverableByEmail ?? this.discoverableByEmail,
    overdueTasksRemindersEnabled:
        overdueTasksRemindersEnabled ?? this.overdueTasksRemindersEnabled,
    overdueTasksRemindersTime:
        overdueTasksRemindersTime ?? this.overdueTasksRemindersTime,
    defaultProjectId: _or(defaultProjectId, this.defaultProjectId),
    weekStart: weekStart ?? this.weekStart,
    timezone: timezone ?? this.timezone,
    language: language ?? this.language,
    quickAddMagicMode: quickAddMagicMode ?? this.quickAddMagicMode,
    quickAddDefaultReminders:
        quickAddDefaultReminders ?? this.quickAddDefaultReminders,
    filterIdUsedOnOverview: _or(
      filterIdUsedOnOverview,
      this.filterIdUsedOnOverview,
    ),
    minimumPriority: minimumPriority ?? this.minimumPriority,
    commentSortOrder: commentSortOrder ?? this.commentSortOrder,
    dateDisplay: _or(dateDisplay, this.dateDisplay),
    timeFormat: _or(timeFormat, this.timeFormat),
    colorSchema: colorSchema ?? this.colorSchema,
    defaultViewKind: _or(defaultViewKind, this.defaultViewKind),
  );

  static T? _or<T>(Object? given, T? current) =>
      identical(given, _unset) ? current : given as T?;

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
      other.name == name &&
      other.emailRemindersEnabled == emailRemindersEnabled &&
      other.discoverableByName == discoverableByName &&
      other.discoverableByEmail == discoverableByEmail &&
      other.overdueTasksRemindersEnabled == overdueTasksRemindersEnabled &&
      other.overdueTasksRemindersTime == overdueTasksRemindersTime &&
      other.defaultProjectId == defaultProjectId &&
      other.weekStart == weekStart &&
      other.timezone == timezone &&
      other.language == language &&
      other.quickAddMagicMode == quickAddMagicMode &&
      _sameDurations(
        other.quickAddDefaultReminders,
        quickAddDefaultReminders,
      ) &&
      other.filterIdUsedOnOverview == filterIdUsedOnOverview &&
      other.minimumPriority == minimumPriority &&
      other.commentSortOrder == commentSortOrder &&
      other.dateDisplay == dateDisplay &&
      other.timeFormat == timeFormat &&
      other.colorSchema == colorSchema &&
      other.defaultViewKind == defaultViewKind;

  @override
  int get hashCode => Object.hashAll([
    name,
    emailRemindersEnabled,
    discoverableByName,
    discoverableByEmail,
    overdueTasksRemindersEnabled,
    overdueTasksRemindersTime,
    defaultProjectId,
    weekStart,
    timezone,
    language,
    quickAddMagicMode,
    Object.hashAll(quickAddDefaultReminders),
    filterIdUsedOnOverview,
    minimumPriority,
    commentSortOrder,
    dateDisplay,
    timeFormat,
    colorSchema,
    defaultViewKind,
  ]);

  static bool _sameDurations(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
