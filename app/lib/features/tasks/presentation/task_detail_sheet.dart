import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/delete_task_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_format.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

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

enum _SheetAction { delete }

/// Follows the local row of [task] while it is open, so a done toggle here,
/// the server's answer to it (a repeating task's next occurrence) and the
/// id a queued create gets show; [task] itself is the fallback once the row
/// is gone.
class TaskDetailSheet extends ConsumerWidget {
  const new({
    required this.task,
    required this.scrollController,
    this.project,
    super.key,
  });

  final Task task;
  final Project? project;
  final ScrollController scrollController;

  Future<void> _delete(
    BuildContext context,
    TaskRepository repository,
    Task task,
  ) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteTask(context, title: task.title);
    if (!confirmed || !context.mounted) return;
    await repository.deleteTask(task.id);
    if (!context.mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.taskDeleted)));
  }

  /// The edit page replaces the sheet, so its "Saved" lands on the list.
  void _edit(BuildContext context, Task task) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(AppRoutes.taskEdit(task.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final repository = ref.watch(taskRepositoryProvider);
    final task = ref.watch(taskByIdProvider(this.task.id)).value ?? this.task;
    final pending =
        ref
            .watch(pendingTaskIdsProvider)
            .unwrapPrevious()
            .value
            ?.contains(task.id) ??
        false;
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
                  // One node: the heading, its tap and the hint together.
                  child: MergeSemantics(
                    child: Semantics(
                      header: true,
                      button: repository != null,
                      hint: repository == null ? null : l10n.taskEdit,
                      child: InkWell(
                        onTap: repository == null
                            ? null
                            : () => _edit(context, task),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            task.title,
                            style: task.done
                                ? theme.textTheme.titleLarge?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: colors.onSurfaceVariant,
                                  )
                                : theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: repository == null
                      ? null
                      : () => _edit(context, task),
                  tooltip: l10n.taskEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                FavouriteButton(
                  isFavorite: task.isFavorite,
                  onChanged: repository == null
                      ? null
                      : (favorite) => unawaited(
                          writeTaskFavorite(
                            repository,
                            task,
                            favorite: favorite,
                          ),
                        ),
                ),
                PopupMenuButton<_SheetAction>(
                  tooltip: l10n.moreActions,
                  enabled: repository != null,
                  onSelected: (action) => switch (action) {
                    _SheetAction.delete => unawaited(
                      _delete(context, repository!, task),
                    ),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _SheetAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: colors.error),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              l10n.taskDelete,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.taskDetailClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            // A task not yet sent has no identifier until the server
            // assigns one.
            if (task.id > 0 || project != null)
              Text(
                switch ((task.id > 0, project)) {
                  (true, final project?) => l10n.taskDetailIdentifierInProject(
                    task.displayIdentifier,
                    project.title,
                  ),
                  (true, null) => task.displayIdentifier,
                  (false, _) => project!.title,
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            CheckboxListTile.adaptive(
              value: task.done,
              onChanged: repository == null
                  ? null
                  : (done) => unawaited(
                      writeTaskDone(repository, task, done: done ?? false),
                    ),
              title: Text(l10n.taskDone),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (pending || PriorityChip.shows(task.priority)) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (PriorityChip.shows(task.priority))
                    PriorityChip(priority: task.priority),
                  if (pending) const _PendingChip(),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (task.dueDate case final dueDate?)
              _Property(
                icon: Icons.event,
                label: l10n.taskDetailDueDate,
                value: formatMoment(context, dueDate),
              ),
            if (task.startDate case final startDate?)
              _Property(
                icon: Icons.play_arrow_outlined,
                label: l10n.taskDetailStartDate,
                value: formatMoment(context, startDate),
              ),
            if (task.endDate case final endDate?)
              _Property(
                icon: Icons.stop_outlined,
                label: l10n.taskDetailEndDate,
                value: formatMoment(context, endDate),
              ),
            if (task.doneAt case final doneAt? when task.done)
              _Property(
                icon: Icons.check,
                label: l10n.taskDetailDoneAt,
                value: formatMoment(context, doneAt),
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
                      formatAbsolute: (moment) => formatMoment(context, moment),
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

class _PendingChip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
      label: Text(l10n.taskNotYetSynced),
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
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      InitialsAvatar(name: user.displayName),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          user.displayName,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
  );
}
