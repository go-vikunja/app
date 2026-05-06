import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/hierarchical_display_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/task_tree_item.dart';

class ProjectTaskList extends ConsumerWidget {
  final Project project;

  const ProjectTaskList(this.project, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectController = ref.watch(projectControllerProvider(project));

    return projectController.when(
      data: (pageModel) {
        List<Widget> children = [];
        if (project.subprojects.isNotEmpty) {
          if (pageModel.tasks.isNotEmpty) {
            children.add(
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  AppLocalizations.of(context).projectSection,
                ),
              ),
            );
            children.add(SliverToBoxAdapter(child: Divider()));
          }
          children.addAll(_buildProjectList(context));
        }
        if (pageModel.tasks.isNotEmpty) {
          if (project.subprojects.isNotEmpty) {
            children.add(
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  AppLocalizations.of(context).tasksSection,
                ),
              ),
            );
            children.add(SliverToBoxAdapter(child: Divider()));
          }
          final hierarchical =
              ref.watch(hierarchicalDisplayProvider).valueOrNull ?? false;
          children.add(_buildTaskList(
            ref,
            pageModel.tasks,
            hierarchical,
          ));
        }

        if (pageModel.isLoadingNextPage) {
          children.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SpinKitThreeBounce(
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
                ),
              ),
            ),
          );
        }

        if (children.isNotEmpty) {
          return CustomScrollView(slivers: children);
        } else {
          return EmptyView(
            Icons.list,
            AppLocalizations.of(context).noTasksOrSubproject,
          );
        }
      },
      error: (err, _) => VikunjaErrorWidget(error: err),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  List<Widget> _buildProjectList(BuildContext context) {
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final subproject = project.subprojects.toList()[index];
          return ListTile(
            leading: Icon(Icons.list),
            onTap: () => _navigateToDetail(context, subproject),
            title: Text(
              subproject.title,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          );
        }, childCount: project.subprojects.length),
      ),
    ];
  }

  Widget _buildTaskList(
    WidgetRef ref,
    List<Task> tasks,
    bool hierarchical,
  ) {
    // Flat mode: show all tasks as individual draggable items.
    if (!hierarchical) {
      return SliverReorderableList(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Material(
            key: Key('flat_${task.id}'),
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaskTreeItem(
                  key: Key('flat_tree_${task.id}'),
                  task: task,
                  depth: 0,
                  subtaskMap: const {},
                  dragIndex: index,
                ),
                if (index < tasks.length - 1) const Divider(height: 1),
              ],
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          // Flat reorder: persist position via view endpoint.
          if (newIndex > oldIndex) newIndex--;
          final list = List<Task>.from(tasks);
          final moved = list.removeAt(oldIndex);
          list.insert(newIndex, moved);
          final viewId = project.views
              .where((v) => v.viewKind == ViewKind.list)
              .map((v) => v.id)
              .firstOrNull;
          if (viewId == null) return;
          final before = newIndex == 0 ? null : list[newIndex - 1].position;
          final after = newIndex >= list.length - 1
              ? null
              : list[newIndex + 1].position;
          final newPos = calculateItemPosition(
            positionBefore: before,
            positionAfter: after,
          );
          ref
              .read(bucketRepositoryProvider)
              .updateTaskPosition(moved.id, viewId, newPos);
        },
      );
    }

    // Build subtask map from each parent's .subtasks list so that a task
    // with multiple parents appears under all of them.
    final taskById = {for (final t in tasks) t.id: t};
    final Map<int, List<Task>> subtaskMap = {};
    final subtaskIds = <int>{};
    for (final task in tasks) {
      if (task.subtasks.isNotEmpty) {
        subtaskMap[task.id] =
            task.subtasks.map((s) => taskById[s.id] ?? s).toList();
        for (final s in task.subtasks) {
          subtaskIds.add(s.id);
        }
      }
    }

    // Only top-level tasks appear in the reorderable list.
    final topLevel =
        tasks.where((t) => !subtaskIds.contains(t.id)).toList();

    // Get the list-view ID needed to persist task positions.
    final int? viewId = project.views
        .where((v) => v.viewKind == ViewKind.list)
        .map((v) => v.id)
        .firstOrNull;

    Future<bool> reorderSubtask(Task movedTask, double newPosition) async {
      if (viewId == null) return false;
      final res = await ref
          .read(bucketRepositoryProvider)
          .updateTaskPosition(movedTask.id, viewId, newPosition);
      return res.isSuccessful;
    }

    return SliverReorderableList(
      itemBuilder: (context, index) {
        final task = topLevel[index];
        return Material(
          key: Key('task_${task.id}'),
          color: Colors.transparent,
          child: Column(
            children: [
              TaskTreeItem(
                key: Key('tree_${task.id}'),
                task: task,
                depth: 0,
                subtaskMap: subtaskMap,
                dragIndex: index,
                onSubtaskReorder: viewId != null ? reorderSubtask : null,
              ),
              if (index < topLevel.length - 1) const Divider(height: 1),
            ],
          ),
        );
      },
      itemCount: topLevel.length,
      onReorder: (oldIndex, newIndexRaw) {
        int newIndex = newIndexRaw;
        if (newIndex > oldIndex) newIndex -= 1;
        if (newIndex < -1) newIndex = -1;

        final taskList = List<Task>.from(topLevel);
        final moved = taskList.removeAt(oldIndex);
        final insertIndex =
            newIndex == -1 ? 0 : newIndex.clamp(0, taskList.length);
        taskList.insert(insertIndex, moved);

        final before =
            insertIndex == 0 ? null : taskList[insertIndex - 1].position;
        final after = insertIndex == taskList.length - 1
            ? null
            : taskList[insertIndex + 1].position;
        final newPos = calculateItemPosition(
          positionBefore: before,
          positionAfter: after,
        );

        // Rebuild the full task list preserving subtasks: reordered top-level
        // items first, then any subtasks that were in the original task list.
        final subtasks =
            tasks.where((t) => subtaskIds.contains(t.id)).toList();
        final fullOrderedTasks = [...taskList, ...subtasks];

        ref
            .read(projectControllerProvider(project).notifier)
            .reorderTasks(
              project: project,
              newOrderedTasks: fullOrderedTasks,
              movedTaskId: moved.id,
              newPosition: newPos,
            )
            .then((success) {
          if (!success && ref.context.mounted) {
            ScaffoldMessenger.of(ref.context).showSnackBar(
              const SnackBar(content: Text('Failed to reorder task')),
            );
          }
        });
      },
    );
  }

  void _navigateToDetail(BuildContext context, Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ProjectDetailPage(
            key: Key(project.id.toString()),
            project: project,
          );
        },
      ),
    );
  }
}
