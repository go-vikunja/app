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
}

/// [viewId] 0 stands for a project without a list view.
String listKeyFor({required int projectId, required int viewId}) =>
    viewId == 0 ? 'project:$projectId' : 'view:$viewId';

@immutable
final class ViewPreferences {
  const new({this.sort = TaskListSort.manual, this.showDone = false});

  final TaskListSort sort;
  final bool showDone;

  ViewPreferences copyWith({TaskListSort? sort, bool? showDone}) =>
      ViewPreferences(
        sort: sort ?? this.sort,
        showDone: showDone ?? this.showDone,
      );

  @override
  bool operator ==(Object other) =>
      other is ViewPreferences &&
      other.sort == sort &&
      other.showDone == showDone;

  @override
  int get hashCode => Object.hash(sort, showDone);
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
