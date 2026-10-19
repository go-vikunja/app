import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// One task in a list, with the web row's content: the done control, the
/// texts that open the detail sheet (one semantics node that reads them
/// all), and the favourite star. The controls are indicators only without
/// their callbacks.
class TaskRow extends ConsumerWidget {
  const new({
    required this.task,
    required this.now,
    required this.minimumPriority,
    this.projectTitle,
    this.projectColor,
    this.depth = 0,
    this.parentTitle,
    this.pending = false,
    this.onTap,
    this.onDoneChanged,
    this.onFavoriteChanged,
    super.key,
  });

  final Task task;
  final DateTime now;

  /// `UserSettings.effectiveMinimumPriority`.
  final int minimumPriority;

  /// For a task from another project than the list's.
  final String? projectTitle;
  final Color? projectColor;

  /// As a subtask: indented under its parent, 4 levels at most.
  final int depth;

  /// The title of the row a subtask is nested under, for screen readers:
  /// the indent alone does not reach them.
  final String? parentTitle;

  /// A change of the task still waits to be sent.
  final bool pending;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onDoneChanged;
  final ValueChanged<bool>? onFavoriteChanged;

  static const _indentPerLevel = 22.0;
  static const _maxIndentedLevels = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final overdue = task.isOverdue(now);
    final due = task.dueDate;
    final dueText = due == null ? null : formatter.relative(due, now: now);
    final spokenDue = due == null
        ? null
        : formatter.semanticsLabel(due) ?? dueText;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    // A task not yet sent has no identifier until the server assigns one.
    final details = [
      if (task.id > 0) task.displayIdentifier,
      ?projectTitle,
    ].join(' · ');
    final showsPriority = PriorityChip.showsOnRow(
      task,
      minimumPriority: minimumPriority,
    );
    final labels = rowLabels(task.labels);
    final described = hasDescription(task);
    final checklist = checklistStatistics(task.description);
    final percent = (task.percentDone * 100).round();
    final taskColor = parseHexColor(task.hexColor);
    final showsChips =
        showsPriority || labels.isNotEmpty || task.assignees.isNotEmpty;

    final semanticsLabel = [
      task.title,
      if (parentTitle case final parent? when depth > 0)
        l10n.taskSubtaskOfSemantics(parent),
      if (task.done) l10n.taskDoneSemantics,
      if (details.isNotEmpty) details,
      if (spokenDue != null && overdue)
        l10n.taskOverdueSemantics(spokenDue)
      else if (spokenDue != null)
        l10n.taskDueSemantics(spokenDue),
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

    final title = Text(
      task.title,
      style: task.done
          ? TextStyle(
              decoration: TextDecoration.lineThrough,
              color: colors.onSurfaceVariant,
            )
          : null,
    );

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.only(
        start: 16 + _indentPerLevel * math.min(depth, _maxIndentedLevels),
        end: 24,
      ),
      leading: TaskDoneControl(done: task.done, onChanged: onDoneChanged),
      title: Semantics(
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: taskColor == null
              ? title
              : Row(
                  children: [
                    ColorDot(color: taskColor),
                    const SizedBox(width: 6),
                    Flexible(child: title),
                  ],
                ),
        ),
      ),
      subtitle: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (details.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (projectColor case final color?
                          when projectTitle != null) ...[
                        ColorDot(color: color),
                        const SizedBox(width: 4),
                      ],
                      Flexible(child: Text(details, style: detailStyle)),
                    ],
                  ),
                if (dueText != null)
                  Text(
                    dueText,
                    style: overdue
                        ? detailStyle?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          )
                        : detailStyle,
                  ),
                if (described)
                  Icon(Icons.notes, size: 16, color: colors.onSurfaceVariant),
                if (task.repeats)
                  Icon(Icons.repeat, size: 16, color: colors.onSurfaceVariant),
                if (!checklist.isEmpty)
                  ChecklistSummary(statistics: checklist, style: detailStyle),
                if (pending)
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
            if (showsChips)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showsPriority) PriorityChip(priority: task.priority),
                    for (final label in labels) LabelChip(label: label),
                    if (task.assignees.isNotEmpty)
                      AssigneeAvatars(users: task.assignees),
                  ],
                ),
              ),
            if (percent > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: task.percentDone.clamp(0, 1),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: colors.onSurfaceVariant,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
          ],
        ),
      ),
      trailing: FavouriteButton(
        isFavorite: task.isFavorite,
        onChanged: onFavoriteChanged,
      ),
    );
  }
}

/// The round done toggle of a task row; an indicator only without
/// [onChanged].
class TaskDoneControl extends StatelessWidget {
  const new({required this.done, required this.onChanged, super.key});

  final bool done;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onChanged == null ? null : () => onChanged!(!done),
      tooltip: done ? l10n.taskMarkNotDone : l10n.taskMarkDone,
      isSelected: done,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          key: ValueKey(done),
          color: done ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
