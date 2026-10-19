import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// What a task row or a board card shows of a task, the web row's content,
/// and the one label that reads all of it to screen readers.
@immutable
final class TaskSummary {
  const new _({
    required this.task,
    required this.details,
    required this.dueText,
    required this.spokenDue,
    required this.overdue,
    required this.showsPriority,
    required this.labels,
    required this.described,
    required this.checklist,
    required this.percent,
    required this.taskColor,
  });

  /// [projectTitle] for a task from another project than the list's.
  factory of(
    Task task, {
    required DateTime now,
    required int minimumPriority,
    required MomentFormatter formatter,
    String? projectTitle,
  }) {
    final due = task.dueDate;
    final dueText = due == null ? null : formatter.relative(due, now: now);
    return TaskSummary._(
      task: task,
      // A task not yet sent has no identifier until the server assigns one.
      details: [
        if (task.id > 0) task.displayIdentifier,
        ?projectTitle,
      ].join(' · '),
      dueText: dueText,
      spokenDue: due == null ? null : formatter.semanticsLabel(due) ?? dueText,
      overdue: task.isOverdue(now),
      showsPriority: PriorityChip.showsOnRow(
        task,
        minimumPriority: minimumPriority,
      ),
      labels: rowLabels(task.labels),
      described: hasDescription(task),
      checklist: checklistStatistics(task.description),
      percent: (task.percentDone * 100).round(),
      taskColor: parseHexColor(task.hexColor),
    );
  }

  final Task task;

  /// The identifier and the project of a task from elsewhere, joined.
  final String details;
  final String? dueText;
  final String? spokenDue;
  final bool overdue;
  final bool showsPriority;
  final List<Label> labels;
  final bool described;
  final ChecklistStatistics checklist;
  final int percent;
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
    if (details.isNotEmpty) details,
    if (spokenDue case final due? when overdue)
      l10n.taskOverdueSemantics(due)
    else if (spokenDue case final due?)
      l10n.taskDueSemantics(due),
    if (showsPriority)
      l10n.prioritySemantics(priorityLabel(l10n, task.priority)),
    for (final label in labels) l10n.labelSemantics(label.title),
    if (task.assignees.isNotEmpty)
      l10n.taskAssigneesSemantics(
        task.assignees.map((user) => user.displayName).join(', '),
      ),
    if (described) l10n.taskHasDescription,
    if (task.repeats) l10n.taskRepeats,
    if (!checklist.isEmpty) ChecklistSummary.text(l10n, checklist),
    if (percent > 0) l10n.taskPercentDone(percent),
    if (pending) l10n.taskNotYetSynced,
  ].join('\n');
}

/// The thin bar of a task's percent done.
class TaskProgressBar extends StatelessWidget {
  const new({required this.percentDone, super.key});

  final double percentDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LinearProgressIndicator(
      value: percentDone.clamp(0, 1),
      minHeight: 4,
      borderRadius: BorderRadius.circular(2),
      color: colors.onSurfaceVariant,
      backgroundColor: colors.surfaceContainerHighest,
    );
  }
}
