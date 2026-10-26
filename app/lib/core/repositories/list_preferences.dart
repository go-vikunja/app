import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// How the user last left each list, per account: the web keeps the same
/// per view in its local storage.
abstract interface class ListPreferences {
  /// [listKey] comes from [listKeyFor].
  Stream<ViewPreferences> watchView(String listKey);
  Future<void> saveView(String listKey, ViewPreferences preferences);

  /// The list view last shown for the project, if any.
  Future<int?> lastViewOf(int projectId);
  Future<void> rememberView(int projectId, int viewId);

  Stream<UpcomingPreferences> watchUpcoming();
  Future<void> saveUpcoming(UpcomingPreferences preferences);

  /// The Projects tab: whether archived projects show and which projects
  /// are collapsed.
  Stream<ProjectTreePreferences> watchProjectTree();
  Future<void> saveProjectTree(ProjectTreePreferences preferences);

  /// The columns every table view shows, one choice for the account like
  /// the web's `tableViewColumns`; [TableColumn.defaults] until chosen.
  Stream<Set<TableColumn>> watchTableColumns();

  /// An empty [columns] stands for the defaults: one column at least stays.
  Future<void> saveTableColumns(Set<TableColumn> columns);
}

@immutable
final class ProjectTreePreferences {
  const new({this.showArchived = false, this.collapsed = const {}});

  final bool showArchived;

  /// Ids of the projects whose subprojects are hidden; open by default.
  final Set<int> collapsed;

  ProjectTreePreferences copyWith({bool? showArchived, Set<int>? collapsed}) =>
      ProjectTreePreferences(
        showArchived: showArchived ?? this.showArchived,
        collapsed: collapsed ?? this.collapsed,
      );

  @override
  bool operator ==(Object other) =>
      other is ProjectTreePreferences &&
      other.showArchived == showArchived &&
      setEquals(other.collapsed, collapsed);

  @override
  int get hashCode =>
      Object.hash(showArchived, Object.hashAllUnordered(collapsed));
}

/// [viewId] 0 stands for a project without a list view.
String listKeyFor({required int projectId, required int viewId}) =>
    viewId == 0 ? 'project:$projectId' : 'view:$viewId';

/// How the user left one view: [sort] and [showDone] for a list view (and
/// [showDone] for a table view), [tableSort] for a table view, [timeline]
/// for a Gantt view.
@immutable
final class ViewPreferences {
  const new({
    this.sort = TaskListSort.manual,
    this.showDone = false,
    this.tableSort = TableSort.defaultSort,
    this.timeline = const TimelinePreferences(),
  });

  final TaskListSort sort;
  final bool showDone;
  final TableSort tableSort;
  final TimelinePreferences timeline;

  ViewPreferences copyWith({
    TaskListSort? sort,
    bool? showDone,
    TableSort? tableSort,
    TimelinePreferences? timeline,
  }) => ViewPreferences(
    sort: sort ?? this.sort,
    showDone: showDone ?? this.showDone,
    tableSort: tableSort ?? this.tableSort,
    timeline: timeline ?? this.timeline,
  );

  @override
  bool operator ==(Object other) =>
      other is ViewPreferences &&
      other.sort == sort &&
      other.showDone == showDone &&
      other.tableSort == tableSort &&
      other.timeline == timeline;

  @override
  int get hashCode => Object.hash(sort, showDone, tableSort, timeline);
}

/// A Gantt view's timeline as the user left it.
@immutable
final class TimelinePreferences {
  const new({
    this.customRange,
    this.withoutDates = false,
    this.dayWidth = defaultDayWidth,
  });

  static const defaultDayWidth = 36.0;
  static const minDayWidth = 20.0;
  static const maxDayWidth = 72.0;

  /// Null for the web's default range, which moves with today.
  final GanttRange? customRange;

  /// "Show tasks without dates": the request's include-nulls.
  final bool withoutDates;

  /// Logical pixels per day column, from [minDayWidth] to [maxDayWidth].
  final double dayWidth;

  GanttRange range(DateTime today) => customRange ?? defaultGanttRange(today);

  TimelinePreferences copyWith({
    GanttRange? customRange,
    bool defaultRange = false,
    bool? withoutDates,
    double? dayWidth,
  }) => TimelinePreferences(
    customRange: defaultRange ? null : customRange ?? this.customRange,
    withoutDates: withoutDates ?? this.withoutDates,
    dayWidth: dayWidth ?? this.dayWidth,
  );

  @override
  bool operator ==(Object other) =>
      other is TimelinePreferences &&
      other.customRange == customRange &&
      other.withoutDates == withoutDates &&
      other.dayWidth == dayWidth;

  @override
  int get hashCode => Object.hash(customRange, withoutDates, dayWidth);
}

@immutable
final class UpcomingPreferences {
  const new({
    this.preset = DateRangePreset.next7Days,
    this.customFrom,
    this.customTo,
    this.showOverdue = true,
    this.showWithoutDueDate = false,
  });

  /// Null for a custom range from [customFrom] through [customTo] (local
  /// dates, both days included).
  final DateRangePreset? preset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool showOverdue;
  final bool showWithoutDueDate;

  /// A custom range runs from [customFrom]'s midnight to the midnight after
  /// [customTo]; a custom range missing either end falls back to the
  /// default preset.
  DateRange range(DateTime now) {
    final from = customFrom;
    final to = customTo;
    final preset = this.preset;
    if (preset != null || from == null || to == null) {
      return (preset ?? DateRangePreset.next7Days).resolve(now);
    }
    return DateRange(
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day + 1),
    );
  }

  UpcomingPreferences copyWith({
    DateRangePreset? preset,
    bool clearPreset = false,
    DateTime? customFrom,
    DateTime? customTo,
    bool? showOverdue,
    bool? showWithoutDueDate,
  }) => UpcomingPreferences(
    preset: clearPreset ? null : preset ?? this.preset,
    customFrom: customFrom ?? this.customFrom,
    customTo: customTo ?? this.customTo,
    showOverdue: showOverdue ?? this.showOverdue,
    showWithoutDueDate: showWithoutDueDate ?? this.showWithoutDueDate,
  );

  @override
  bool operator ==(Object other) =>
      other is UpcomingPreferences &&
      other.preset == preset &&
      other.customFrom == customFrom &&
      other.customTo == customTo &&
      other.showOverdue == showOverdue &&
      other.showWithoutDueDate == showWithoutDueDate;

  @override
  int get hashCode => Object.hash(
    preset,
    customFrom,
    customTo,
    showOverdue,
    showWithoutDueDate,
  );
}
