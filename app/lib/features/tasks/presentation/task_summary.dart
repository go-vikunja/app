import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// One of a table row's dates, as the row shows it and screen readers hear
/// it.
typedef TableDate = ({TableColumn column, String text, String spoken});

/// What a task row or a board card shows of a task, the web row's content,
/// and the one label that reads all of it to screen readers. In a table
/// view's row, the web table's chosen columns instead.
@immutable
final class TaskSummary {
  const new _({
    required this.task,
    required this.projectTitle,
    required this.dueText,
    required this.dueTone,
    required this.spokenDue,
    required this.overdue,
    required this.showsPriority,
    required this.labels,
    required this.showsAssignees,
    required this.showsCommentCount,
    required this.described,
    required this.repeats,
    required this.checklist,
    required this.percent,
    required this.showsPercent,
    required this.showsDoneBadge,
    required this.tableDates,
    required this.createdBy,
    required this.taskColor,
  });

  /// [projectTitle] for a task from another project than the list's, or
  /// in a table view for every task, shown while [columns] has the project.
  factory of(
    Task task, {
    required DateTime now,
    required int minimumPriority,
    required MomentFormatter formatter,
    String? projectTitle,
    Set<TableColumn>? columns,
  }) {
    bool shows(TableColumn column) => columns?.contains(column) ?? true;
    final inTable = columns != null;
    final project = shows(TableColumn.project) ? projectTitle : null;
    final percent = (task.percentDone * 100).round();
    final due = inTable ? null : task.dueDate;
    final dueText = due == null ? null : formatter.relative(due, now: now);
    TableDate? dated(TableColumn column, DateTime? date) {
      if (date == null || !shows(column)) return null;
      final text = formatter.relative(date, now: now);
      return (
        column: column,
        text: text,
        spoken: formatter.semanticsLabel(date) ?? text,
      );
    }

    return TaskSummary._(
      task: task,
      projectTitle: project,
      dueText: dueText,
      dueTone: DueTone.of(task, now: now),
      spokenDue: due == null ? null : formatter.semanticsLabel(due) ?? dueText,
      overdue: task.isOverdue(now),
      // The web table shows every priority, Unset and done tasks' too.
      showsPriority: inTable
          ? shows(TableColumn.priority)
          : PriorityFlag.showsOnRow(task, minimumPriority: minimumPriority),
      labels: shows(TableColumn.labels) ? rowLabels(task.labels) : const [],
      showsAssignees: shows(TableColumn.assignees) && task.assignees.isNotEmpty,
      showsCommentCount:
          shows(TableColumn.commentCount) && task.commentCount > 0,
      described: !inTable && hasDescription(task),
      repeats: !inTable && task.repeats,
      checklist: inTable
          ? const ChecklistStatistics()
          : checklistStatistics(task.description),
      percent: percent,
      showsPercent: inTable ? shows(TableColumn.percentDone) : percent > 0,
      showsDoneBadge: inTable && shows(TableColumn.done) && task.done,
      tableDates: inTable
          ? [
              ?dated(TableColumn.dueDate, task.dueDate),
              ?dated(TableColumn.startDate, task.startDate),
              ?dated(TableColumn.endDate, task.endDate),
              // The server clears it when a task is reopened.
              ?dated(TableColumn.doneAt, task.done ? task.doneAt : null),
              ?dated(TableColumn.created, task.created),
              ?dated(TableColumn.updated, task.updated),
            ]
          : const [],
      createdBy: inTable && shows(TableColumn.createdBy)
          ? task.createdBy
          : null,
      taskColor: parseHexColor(task.hexColor),
    );
  }

  final Task task;

  /// For a task from another project than the list's; in a table, for
  /// every task while the project column shows.
  final String? projectTitle;

  /// The list row's due date; a table's is among [tableDates].
  final String? dueText;
  final DueTone dueTone;
  final String? spokenDue;
  final bool overdue;
  final bool showsPriority;
  final List<Label> labels;
  final bool showsAssignees;
  final bool showsCommentCount;
  final bool described;
  final bool repeats;
  final ChecklistStatistics checklist;

  /// Rounded to a whole percent.
  final int percent;

  /// The list row's bar from 1 % on; a table's figure, 0 % too.
  final bool showsPercent;
  final bool showsDoneBadge;

  /// A table row's dates in the web's column order, the unset ones left
  /// out.
  final List<TableDate> tableDates;
  final User? createdBy;
  final Color? taskColor;

  /// [parentTitle] for a subtask nested under it.
  String semanticsLabel(
    AppLocalizations l10n, {
    String? parentTitle,
    bool pending = false,
  }) => [
    task.title,
    if (parentTitle != null) l10n.taskSubtaskOfSemantics(parentTitle),
    if (task.done) l10n.taskDoneSemantics,
    ?projectTitle,
    if (spokenDue case final due? when overdue)
      l10n.taskOverdueSemantics(due)
    else if (spokenDue case final due?)
      l10n.taskDueSemantics(due),
    if (showsPriority)
      l10n.prioritySemantics(priorityLabel(l10n, task.priority)),
    for (final label in labels) l10n.labelSemantics(label.title),
    if (showsAssignees)
      l10n.taskAssigneesSemantics(
        task.assignees.map((user) => user.displayName).join(', '),
      ),
    if (described) l10n.taskHasDescription,
    if (repeats) l10n.taskRepeats,
    if (!checklist.isEmpty) ChecklistSummary.text(l10n, checklist),
    if (showsCommentCount && task.isUnread)
      l10n.taskCommentCountUnread(task.commentCount)
    else if (showsCommentCount)
      l10n.taskCommentCount(task.commentCount),
    for (final date in tableDates)
      if (date.column.index < TableColumn.percentDone.index)
        tableDateSemantics(l10n, date),
    if (showsPercent) l10n.taskPercentDone(percent),
    for (final date in tableDates)
      if (date.column.index > TableColumn.percentDone.index)
        tableDateSemantics(l10n, date),
    if (createdBy case final user?)
      l10n.projectTableCreatedBySemantics(user.displayName),
    if (pending) l10n.taskNotYetSynced,
  ].join('\n');

  static String tableDateSemantics(AppLocalizations l10n, TableDate date) =>
      switch (date.column) {
        TableColumn.startDate => l10n.projectTableStartsSemantics(date.spoken),
        TableColumn.endDate => l10n.projectTableEndsSemantics(date.spoken),
        TableColumn.doneAt => l10n.taskDetailDoneWhen(date.spoken),
        TableColumn.created => l10n.taskDetailCreated(date.spoken),
        TableColumn.updated => l10n.taskDetailUpdated(date.spoken),
        _ => l10n.taskDueSemantics(date.spoken),
      };
}

/// The thin bar of a task's percent done.
class TaskProgressBar extends StatelessWidget {
  const new({required this.percentDone, super.key});

  final double percentDone;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: percentDone.clamp(0, 1),
    minHeight: 4,
    borderRadius: BorderRadius.circular(2),
  );
}
