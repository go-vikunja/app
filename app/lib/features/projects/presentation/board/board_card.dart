import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_summary.dart';

/// A task on a kanban board with the web card's content: one semantics node
/// that reads it like the task row, taps open the task, and [actions] move
/// it for screen readers. No done control and no star, as on the web.
class BoardCard extends ConsumerWidget {
  const new({
    required this.task,
    required this.now,
    required this.minimumPriority,
    this.pending = false,
    this.onTap,
    this.actions = const {},
    super.key,
  });

  final Task task;
  final DateTime now;

  /// `UserSettings.effectiveMinimumPriority`.
  final int minimumPriority;

  /// A change of the task still waits to be sent.
  final bool pending;
  final VoidCallback? onTap;
  final Map<CustomSemanticsAction, VoidCallback> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = TaskSummary.of(
      task,
      now: now,
      minimumPriority: minimumPriority,
      formatter: MomentFormatter.watch(context, ref),
    );
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final dueStyle = summary.overdue
        ? detailStyle?.copyWith(
            color: colors.error,
            fontWeight: FontWeight.w600,
          )
        : detailStyle;
    final iconColor = colors.onSurfaceVariant;
    final dueText = summary.dueText;
    final taskColor = summary.taskColor;

    final topRow = [
      if (task.done) const _DoneBadge(),
      if (summary.details.isNotEmpty) Text(summary.details, style: detailStyle),
      if (dueText != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event,
              size: 14,
              color: summary.overdue ? colors.error : iconColor,
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(dueText, style: dueStyle)),
          ],
        ),
    ];
    final footer = [
      for (final label in summary.labels) LabelChip(label: label),
      if (summary.showsPriority) PriorityChip(priority: task.priority),
      if (summary.described) Icon(Icons.notes, size: 16, color: iconColor),
      if (task.repeats) Icon(Icons.repeat, size: 16, color: iconColor),
      if (pending) Icon(Icons.cloud_off_outlined, size: 16, color: iconColor),
      if (task.assignees.isNotEmpty) AssigneeAvatars(users: task.assignees),
      if (!summary.checklist.isEmpty)
        ChecklistSummary(statistics: summary.checklist, style: detailStyle),
    ];
    final title = Text(task.title, style: theme.textTheme.bodyLarge);

    return Semantics(
      container: true,
      label: summary.semanticsLabel(l10n, pending: pending),
      onTap: onTap,
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topRow.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: topRow,
                      ),
                    ),
                  if (taskColor == null)
                    title
                  else
                    Row(
                      children: [
                        ColorDot(color: taskColor),
                        const SizedBox(width: 6),
                        Expanded(child: title),
                      ],
                    ),
                  if (summary.percent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TaskProgressBar(percentDone: task.percentDone),
                    ),
                  if (footer.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: footer,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's small "Done" tag on a done card.
class _DoneBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.l10n.taskDoneSemantics,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
