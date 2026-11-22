import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_app_bar.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/due_sections_list.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/bulk_task_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

/// The open tasks with one label, grouped by due date like a saved
/// filter's list: what `done = false && labels in <id>` finds in a saved
/// filter's scope, from the local database. A label found by the search
/// opens it. A label created here stays open when its create is answered.
class LabelTasksScreen extends ConsumerStatefulWidget {
  const new({required this.labelId, super.key});

  final int labelId;

  @override
  ConsumerState<LabelTasksScreen> createState() => _LabelTasksScreenState();
}

class _LabelTasksScreenState extends ConsumerState<LabelTasksScreen>
    with
        RefreshableList<LabelTasksScreen>,
        TaskListActions<LabelTasksScreen>,
        TaskSelectionActions<LabelTasksScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  Future<void>? startRefresh() =>
      ref.read(taskRepositoryProvider)?.refreshOpenTasks();

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    endSelection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final found = ref.watch(labelByIdProvider(widget.labelId));
    final label = found.value;
    final tasks = ref.watch(labelTasksProvider(widget.labelId));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectsById = {for (final project in projects) project.id: project};
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final title = label?.title ?? '';
    final selectable = [
      for (final task in tasks.value ?? const <Task>[])
        if (taskChangeable(task, projectsById)) task,
    ];
    final selectableIds = {for (final task in selectable) task.id};

    return selectionBackHandler(
      child: Scaffold(
        appBar: selecting
            ? selectionBar(selectable)
            : ReadableAppBar(
                maxWidth: ReadableWidth.list,
                title: ScreenTitle(title),
                actions: [
                  RefreshButton(onPressed: refreshing ? null : refresh),
                ],
              ),
        bottomNavigationBar: selecting ? selectionActionBar(selectable) : null,
        body: found.hasValue && label == null
            ? CenteredScrollView(
                maxWidth: ReadableWidth.list,
                child: EmptyState(
                  icon: Icons.label_off_outlined,
                  title: l10n.labelTasksGoneTitle,
                  body: l10n.labelTasksGoneBody,
                ),
              )
            : buildRefreshable(
                tasks,
                loadingLabel: l10n.projectTasksLoading,
                maxWidth: ReadableWidth.list,
                builder: (value, notice) => DueSectionsList(
                  sections: groupTasksByDueDate(withLeavingTasks(value), now),
                  projectsById: projectsById,
                  pendingIds: pendingIds,
                  now: now,
                  minimumPriority: minimumPriority,
                  header: notice,
                  emptyState: EmptyState(
                    icon: Icons.label_outline,
                    title: l10n.labelTasksEmptyTitle,
                    body: l10n.labelTasksEmptyBody(title),
                  ),
                  onDoneChanged: (task, {required done}) =>
                      unawaited(setTaskDone(task, done: done)),
                  onFavoriteChanged: (task, {required favorite}) =>
                      unawaited(setTaskFavorite(task, favorite: favorite)),
                  onDueDate: (task) => unawaited(changeTaskDueDate(task)),
                  onSelect: startSelection,
                  selection: (task) => rowSelection(
                    task,
                    changeable: selectableIds.contains(task.id),
                  ),
                  onReschedule: selecting
                      ? null
                      : (tasks) => unawaited(
                          rescheduleTasks(
                            context,
                            ref,
                            tasks,
                            title: l10n.overdueRescheduleTitle(tasks.length),
                          ),
                        ),
                  changeable: (task) => taskChangeable(task, projectsById),
                ),
              ),
      ),
    );
  }
}
