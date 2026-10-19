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
    this.filterIdUsedOnOverview,
    this.minimumPriority = 0,
    this.commentSortOrder = CommentSortOrder.oldestFirst,
    this.dateDisplay,
    this.timeFormat,
    this.colorSchema = ColorSchema.auto,
    this.defaultViewKind,
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

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
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
  int get hashCode => Object.hash(
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
  );

  static bool _sameDurations(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
