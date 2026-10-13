import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// The server's default name is translated, any other title shown as is,
/// like the web's view tabs.
String viewTitle(AppLocalizations l10n, ProjectView view) =>
    view.title == 'List' ? l10n.projectViewList : view.title;

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
  ...[
    for (final sort in TaskListSort.values)
      if (sort != TaskListSort.manual) sort,
  ]..sort(
    (a, b) => sortLabel(
      l10n,
      a,
    ).toLowerCase().compareTo(sortLabel(l10n, b).toLowerCase()),
  ),
];

/// What the server matches the view against: its filter, else its search.
String describeViewFilter(ViewFilter? filter) => switch (filter) {
  null => '',
  ViewFilter(filter: final text) when text.trim().isNotEmpty => text.trim(),
  ViewFilter(:final search) => search.trim(),
};
