import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';

/// One task in a list: the done control, the texts that open the detail
/// sheet, and the favourite star. The controls are indicators only without
/// their callbacks.
class TaskRow extends StatelessWidget {
  const new({
    required this.task,
    required this.now,
    this.projectTitle,
    this.pending = false,
    this.onTap,
    this.onDoneChanged,
    this.onFavoriteChanged,
    super.key,
  });

  final Task task;
  final DateTime now;

  /// Omitted in a project's own list.
  final String? projectTitle;

  /// A change of the task still waits to be sent.
  final bool pending;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onDoneChanged;
  final ValueChanged<bool>? onFavoriteChanged;

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

    return ListTile(
      onTap: onTap,
      leading: _DoneControl(done: task.done, onChanged: onDoneChanged),
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(details, style: detailStyle),
              if (due != null)
                _DueText(
                  due: due,
                  now: now,
                  overdue: overdue,
                  style: detailStyle,
                ),
              if (pending)
                Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                  semanticLabel: l10n.taskNotYetSynced,
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
      trailing: FavouriteButton(
        isFavorite: task.isFavorite,
        onChanged: onFavoriteChanged,
      ),
    );
  }
}

class _DoneControl extends StatelessWidget {
  const new({required this.done, required this.onChanged});

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
