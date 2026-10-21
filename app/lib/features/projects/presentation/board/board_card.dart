import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/avatar_stack.dart';
import 'package:vikunja_mobile/features/common/presentation/identifier_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
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
    final mutedSmall = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    Widget metaIcon(IconData icon) =>
        Icon(icon, size: 14, color: colors.onSurfaceVariant);
    final identifier = summary.identifier;
    final taskColor = summary.taskColor;

    final meta = [
      if (task.done) const _DoneBadge(),
      if (identifier != null)
        IdentifierText(identifier, style: const TextStyle(fontSize: 11)),
      if (summary.showsPriority) PriorityFlag(priority: task.priority),
      if (summary.dueText case final due?)
        DueBadge(text: due, tone: summary.dueTone),
      if (!summary.checklist.isEmpty)
        _ChecklistCount(statistics: summary.checklist, style: mutedSmall),
      if (summary.described) metaIcon(Icons.notes),
      if (task.repeats) metaIcon(Icons.repeat),
      if (pending) metaIcon(Icons.cloud_off_outlined),
    ];
    final title = Text(task.title, style: theme.textTheme.bodyMedium);

    return Semantics(
      container: true,
      label: summary.semanticsLabel(l10n, pending: pending),
      onTap: onTap,
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          // A dark surface is darker than the column, and no shadow shows
          // there to lift the card.
          color: theme.brightness == Brightness.dark
              ? colors.surfaceContainerHigh
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (taskColor == null)
                    title
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text.rich(
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: ColorDot(color: taskColor),
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: title),
                      ],
                    ),
                  if (summary.labels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final label in summary.labels)
                            LabelPill(label: label),
                        ],
                      ),
                    ),
                  if (summary.percent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TaskProgressBar(percentDone: task.percentDone),
                    ),
                  if (meta.isNotEmpty || task.assignees.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: meta,
                            ),
                          ),
                          if (task.assignees.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            AvatarStack(users: task.assignees),
                          ],
                        ],
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

/// The description's checkboxes, "1/3" after a checkbox icon, as in the
/// task row.
class _ChecklistCount extends StatelessWidget {
  const new({required this.statistics, required this.style});

  final ChecklistStatistics statistics;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        statistics.allDone ? Icons.check_box : Icons.check_box_outlined,
        size: 14,
        color: style?.color,
      ),
      const SizedBox(width: 2),
      Flexible(
        child: Text('${statistics.checked}/${statistics.total}', style: style),
      ),
    ],
  );
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          context.l10n.taskDoneSemantics,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
