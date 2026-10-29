import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

/// The server's default names are translated, any other title shown as
/// is, like the web's view tabs.
String viewTitle(AppLocalizations l10n, ProjectView view) =>
    switch (view.title) {
      'List' => l10n.projectViewList,
      'Gantt' => l10n.projectViewGantt,
      'Table' => l10n.projectViewTable,
      'Kanban' => l10n.projectViewKanban,
      final title => title,
    };

String sortLabel(AppLocalizations l10n, TaskListSort sort) => switch (sort) {
  TaskListSort.manual => l10n.sortManual,
  TaskListSort.titleAsc => l10n.sortTitleAsc,
  TaskListSort.titleDesc => l10n.sortTitleDesc,
  TaskListSort.priorityDesc => l10n.sortPriorityDesc,
  TaskListSort.priorityAsc => l10n.sortPriorityAsc,
  TaskListSort.dueDateAsc => l10n.sortDueDateAsc,
  TaskListSort.dueDateDesc => l10n.sortDueDateDesc,
  TaskListSort.startDateAsc => l10n.sortStartDateAsc,
  TaskListSort.startDateDesc => l10n.sortStartDateDesc,
  TaskListSort.endDateAsc => l10n.sortEndDateAsc,
  TaskListSort.endDateDesc => l10n.sortEndDateDesc,
  TaskListSort.percentDoneDesc => l10n.sortPercentDoneDesc,
  TaskListSort.percentDoneAsc => l10n.sortPercentDoneAsc,
  TaskListSort.createdDesc => l10n.sortCreatedDesc,
  TaskListSort.createdAsc => l10n.sortCreatedAsc,
  TaskListSort.updatedDesc => l10n.sortUpdatedDesc,
  TaskListSort.updatedAsc => l10n.sortUpdatedAsc,
};

/// The web's sort popup order: "Manually" first, the rest by label.
List<TaskListSort> sortsInMenuOrder(AppLocalizations l10n) => [
  TaskListSort.manual,
  ...orderedByLabel([
    for (final sort in TaskListSort.values)
      if (sort != TaskListSort.manual) sort,
  ], (sort) => sortLabel(l10n, sort)),
];

List<T> orderedByLabel<T>(Iterable<T> items, String Function(T item) label) {
  final labelled = [for (final item in items) (item, label(item))]
    ..sort((a, b) {
      final byTitle = compareTitles(a.$2, b.$2);
      return byTitle != 0 ? byTitle : a.$2.compareTo(b.$2);
    });
  return [for (final (item, _) in labelled) item];
}

String tableSortLabel(AppLocalizations l10n, TableSort sort) =>
    switch ((sort.field, sort.descending)) {
      (TableSortField.taskIndex, true) => l10n.projectTableSortNumberDesc,
      (TableSortField.taskIndex, false) => l10n.projectTableSortNumberAsc,
      (TableSortField.done, false) => l10n.projectTableSortDoneAsc,
      (TableSortField.done, true) => l10n.projectTableSortDoneDesc,
      (TableSortField.title, false) => l10n.sortTitleAsc,
      (TableSortField.title, true) => l10n.sortTitleDesc,
      (TableSortField.priority, true) => l10n.sortPriorityDesc,
      (TableSortField.priority, false) => l10n.sortPriorityAsc,
      (TableSortField.dueDate, false) => l10n.sortDueDateAsc,
      (TableSortField.dueDate, true) => l10n.sortDueDateDesc,
      (TableSortField.startDate, false) => l10n.sortStartDateAsc,
      (TableSortField.startDate, true) => l10n.sortStartDateDesc,
      (TableSortField.endDate, false) => l10n.sortEndDateAsc,
      (TableSortField.endDate, true) => l10n.sortEndDateDesc,
      (TableSortField.percentDone, true) => l10n.sortPercentDoneDesc,
      (TableSortField.percentDone, false) => l10n.sortPercentDoneAsc,
      (TableSortField.doneAt, true) => l10n.projectTableSortDoneAtDesc,
      (TableSortField.doneAt, false) => l10n.projectTableSortDoneAtAsc,
      (TableSortField.created, true) => l10n.sortCreatedDesc,
      (TableSortField.created, false) => l10n.sortCreatedAsc,
      (TableSortField.updated, true) => l10n.sortUpdatedDesc,
      (TableSortField.updated, false) => l10n.sortUpdatedAsc,
    };

/// The web table's sortable columns in its order, each in the direction
/// most often wanted first, the default first of all.
final List<TableSort> tableSortsInMenuOrder = [
  for (final field in TableSortField.values)
    for (final descending in switch (field) {
      TableSortField.taskIndex ||
      TableSortField.priority ||
      TableSortField.percentDone ||
      TableSortField.doneAt ||
      TableSortField.created ||
      TableSortField.updated => const [true, false],
      _ => const [false, true],
    })
      TableSort(field, descending: descending),
];

/// What the server matches the view against: its filter, else its search.
String describeViewFilter(ViewFilter? filter) => switch (filter) {
  null => '',
  ViewFilter(filter: final text) when text.trim().isNotEmpty => text.trim(),
  ViewFilter(:final search) => search.trim(),
};
