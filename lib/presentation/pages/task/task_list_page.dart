
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/hierarchical_display_provider.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_tree_item.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var pageModel = ref.watch(taskPageControllerProvider);

    return pageModel.when(
      data: (model) {
        return Scaffold(
          appBar: _buildAppBar(ref, context, model.onlyDueDate),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(taskPageControllerProvider.notifier).reload();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels ==
                    scrollInfo.metrics.maxScrollExtent) {
                  ref.read(taskPageControllerProvider.notifier).loadNextPage();
                }
                return false;
              },
              child: _buildList(ref, context, model),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (model.defaultProjectId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.selectDefaultProject)),
                );
              } else {
                _addItemDialog(ref, context, model.defaultProjectId);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
      error: (err, _) => VikunjaErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(taskPageControllerProvider),
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildList(WidgetRef ref, BuildContext context, TaskPageModel model) {
    if (model.tasks.isEmpty) {
      return EmptyView(Icons.list, AppLocalizations.of(context).noTasks);
    }

    final hierarchical =
        ref.watch(hierarchicalDisplayProvider).valueOrNull ?? false;

    if (!hierarchical) {
      return _buildFlatList(context, model);
    }
    return _buildHierarchicalList(ref, context, model);
  }

  Widget _buildFlatList(BuildContext context, TaskPageModel model) {
    final tasks = model.tasks;
    final itemCount = tasks.length + (model.isLoadingNextPage ? 1 : 0);
    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Divider(height: 8),
      itemBuilder: (context, index) {
        if (index == tasks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SpinKitThreeBounce(
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            ),
          );
        }
        // Use TaskTreeItem with empty subtaskMap so it renders as a flat item
        // but retains all tap/edit/mark-done interactions.
        return TaskTreeItem(
          key: Key('flat_${tasks[index].id}'),
          task: tasks[index],
          depth: 0,
          subtaskMap: const {},
        );
      },
    );
  }

  Widget _buildHierarchicalList(
    WidgetRef ref,
    BuildContext context,
    TaskPageModel model,
  ) {
    // Build subtask map from each parent's .subtasks list so that a task
    // with multiple parents appears under all of them.
    final taskById = {for (final t in model.tasks) t.id: t};
    final Map<int, List<Task>> subtaskMap = {};
    final subtaskIds = <int>{};
    for (final task in model.tasks) {
      if (task.subtasks.isNotEmpty) {
        subtaskMap[task.id] =
            task.subtasks.map((s) => taskById[s.id] ?? s).toList();
        for (final s in task.subtasks) {
          subtaskIds.add(s.id);
        }
      }
    }

    final topLevelTasks =
        model.tasks.where((t) => !subtaskIds.contains(t.id)).toList();

    Future<bool> reorderSubtask(Task movedTask, double newPosition) async {
      final res = await ref
          .read(taskRepositoryProvider)
          .update(movedTask.copyWith(position: newPosition));
      return res.isSuccessful;
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorder: (_, __) {},
      itemCount: topLevelTasks.length + (model.isLoadingNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == topLevelTasks.length) {
          return Padding(
            key: const Key('loading_indicator'),
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SpinKitThreeBounce(
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            ),
          );
        }
        final task = topLevelTasks[index];
        return Column(
          key: Key('top_${task.id}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskTreeItem(
              key: Key('tree_${task.id}'),
              task: task,
              depth: 0,
              subtaskMap: subtaskMap,
              onSubtaskReorder: reorderSubtask,
            ),
            if (index < topLevelTasks.length - 1) const Divider(height: 8),
          ],
        );
      },
    );
  }

  AppBar _buildAppBar(WidgetRef ref, BuildContext context, bool onlyDueDate) {
    return AppBar(
      title: Text("Vikunja"),
      actions: [
        PopupMenuButton(
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                child: InkWell(
                  onTap: () {
                    _onlyDueDateChanged(ref, context, !onlyDueDate);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.of(context).onlyShowTasksWithDueDate,
                      ),
                      Checkbox(
                        value: onlyDueDate,
                        onChanged: (bool? value) {
                          _onlyDueDateChanged(ref, context, !onlyDueDate);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  void _onlyDueDateChanged(WidgetRef ref, BuildContext context, bool newValue) {
    Navigator.pop(context);
    ref
        .read(taskPageControllerProvider.notifier)
        .setLandingPageOnlyDueDateTasks(newValue);
  }

  void _addItemDialog(
    WidgetRef ref,
    BuildContext context,
    int defaultProjectId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addTask(ref, title, dueDate, defaultProjectId),
      ),
    );
  }

  Future<void> _addTask(
    WidgetRef ref,
    String title,
    DateTime? dueDate,
    int defaultProjectId,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    var task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: currentUser,
      projectId: defaultProjectId,
    );

    var success = await ref
        .read(taskPageControllerProvider.notifier)
        .addTask(defaultProjectId, task);

    if (ref.context.mounted) {
      if (success) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref.context).taskAddedSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref.context).taskAddError),
          ),
        );
      }
    }
  }

}
