import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/tasks/application/html_to_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// Shows what the list already knows about [task]; no network call.
Future<void> showTaskDetail(
  BuildContext context, {
  required Task task,
  Project? project,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<void>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => TaskDetailSheet(
          task: task,
          project: project,
          scrollController: scrollController,
        ),
      );
    case _:
      return showModalBottomSheet<void>(
        context: context,
        // Over the tab bar, not inside the tab's own navigator.
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) => TaskDetailSheet(
            task: task,
            project: project,
            scrollController: scrollController,
          ),
        ),
      );
  }
}

class TaskDetailSheet extends StatelessWidget {
  const new({
    required this.task,
    required this.scrollController,
    this.project,
    super.key,
  });

  final Task task;
  final Project? project;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final materialL10n = MaterialLocalizations.of(context);
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    String formatMoment(DateTime moment) {
      final local = moment.toLocal();
      final time = materialL10n.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: use24Hour,
      );
      return '${materialL10n.formatShortDate(local)} $time';
    }

    final description = htmlToPlainText(task.description);
    final repeat = formatRepeat(l10n, task);
    final percent = (task.percentDone * 100).round();

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(task.title, style: theme.textTheme.titleLarge),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.taskDetailClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              switch (project) {
                final project? => l10n.taskDetailIdentifierInProject(
                  task.displayIdentifier,
                  project.title,
                ),
                null => task.displayIdentifier,
              },
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(done: task.done),
                if (task.isFavorite)
                  Icon(
                    Icons.star,
                    color: colors.tertiary,
                    semanticLabel: l10n.favouriteLabel,
                  ),
                if (PriorityChip.shows(task.priority))
                  PriorityChip(priority: task.priority),
              ],
            ),
            const SizedBox(height: 8),
            if (task.dueDate case final dueDate?)
              _Property(
                icon: Icons.event,
                label: l10n.taskDetailDueDate,
                value: formatMoment(dueDate),
              ),
            if (task.startDate case final startDate?)
              _Property(
                icon: Icons.play_arrow_outlined,
                label: l10n.taskDetailStartDate,
                value: formatMoment(startDate),
              ),
            if (task.endDate case final endDate?)
              _Property(
                icon: Icons.stop_outlined,
                label: l10n.taskDetailEndDate,
                value: formatMoment(endDate),
              ),
            if (task.doneAt case final doneAt? when task.done)
              _Property(
                icon: Icons.check,
                label: l10n.taskDetailDoneAt,
                value: formatMoment(doneAt),
              ),
            if (task.priority != TaskPriority.unset)
              _Property(
                icon: Icons.flag_outlined,
                label: l10n.taskDetailPriority,
                value: priorityLabel(l10n, task.priority),
              ),
            if (percent > 0)
              _Property(
                icon: Icons.percent,
                label: l10n.taskDetailProgress,
                value: l10n.taskPercentDone(percent),
              ),
            if (repeat != null)
              _Property(
                icon: Icons.repeat,
                label: l10n.taskDetailRepeat,
                value: repeat,
              ),
            if (task.reminders.isNotEmpty)
              _Property(
                icon: Icons.alarm,
                label: l10n.taskDetailReminders,
                value: [
                  for (final reminder in task.reminders)
                    formatReminder(
                      l10n,
                      reminder,
                      formatAbsolute: formatMoment,
                    ),
                ].join('\n'),
              ),
            if (task.labels.isNotEmpty)
              _PropertyBlock(
                icon: Icons.label_outline,
                label: l10n.taskDetailLabels,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in task.labels) LabelChip(label: label),
                  ],
                ),
              ),
            if (task.assignees.isNotEmpty)
              _PropertyBlock(
                icon: Icons.people_outline,
                label: l10n.taskDetailAssignees,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final user in task.assignees) _Assignee(user: user),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                l10n.taskDetailDescription,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (description.isEmpty)
              Text(
                l10n.taskDetailNoDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              SelectableText(description, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const new({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? colors.primary : colors.onSurfaceVariant,
      ),
      label: Text(done ? l10n.taskDetailStatusDone : l10n.taskDetailStatusOpen),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Property extends StatelessWidget {
  const new({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _PropertyBlock(
    icon: icon,
    label: label,
    child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _PropertyBlock extends StatelessWidget {
  const new({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Assignee extends StatelessWidget {
  const new({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 14,
            backgroundColor: colors.secondaryContainer,
            child: Text(
              initialsOf(user.displayName),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(user.displayName, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
