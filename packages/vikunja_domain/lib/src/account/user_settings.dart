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
      other.commentSortOrder == commentSortOrder;

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
  );

  static bool _sameDurations(List<Duration> a, List<Duration> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
