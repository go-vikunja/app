import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';

/// One task in a list. Read-only: the done indicator is only an indicator.
class TaskRow extends StatelessWidget {
  const new({
    required this.task,
    required this.now,
    this.projectTitle,
    this.onTap,
    super.key,
  });

  final Task task;
  final DateTime now;

  /// Omitted in a project's own list.
  final String? projectTitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = task.isOverdue(now);
    final due = task.dueDate;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final details = [task.displayIdentifier, ?projectTitle].join(' · ');
    final showsChips =
        PriorityChip.shows(task.priority) || task.labels.isNotEmpty;

    return MergeSemantics(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          task.done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: task.done ? colors.primary : colors.onSurfaceVariant,
          semanticLabel: task.done ? l10n.taskDone : l10n.taskNotDone,
        ),
        title: Text(
          task.title,
          style: task.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: colors.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                Text(details, style: detailStyle),
                if (due != null)
                  _DueText(
                    due: due,
                    now: now,
                    overdue: overdue,
                    style: detailStyle,
                  ),
              ],
            ),
            if (showsChips)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (PriorityChip.shows(task.priority))
                      PriorityChip(priority: task.priority),
                    for (final label in task.labels) LabelChip(label: label),
                  ],
                ),
              ),
          ],
        ),
        trailing: task.isFavorite
            ? Icon(
                Icons.star,
                color: colors.tertiary,
                semanticLabel: l10n.favouriteLabel,
              )
            : null,
      ),
    );
  }
}

class _DueText extends StatelessWidget {
  const new({
    required this.due,
    required this.now,
    required this.overdue,
    required this.style,
  });

  final DateTime due;
  final DateTime now;
  final bool overdue;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final when = formatRelativeTime(l10n, due, now: now);
    return Text(
      when,
      style: overdue
          ? style?.copyWith(color: colors.error, fontWeight: FontWeight.w600)
          : style,
      semanticsLabel: overdue
          ? l10n.taskOverdueSemantics(when)
          : l10n.taskDueSemantics(when),
    );
  }
}
