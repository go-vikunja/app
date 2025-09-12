import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';
import 'package:vikunja_app/presentation/widgets/task_tile.dart';

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
          children.add(_buildSectionHeader("Projects"));
          children.addAll(_buildProjectList(context));
        }
        if (pageModel.tasks.isNotEmpty) {
          children.add(_buildSectionHeader("Tasks"));
          children.add(Divider());
          children.addAll(_buildTaskList(ref, pageModel.tasks));
        }

        if (children.isNotEmpty) {
          return ListView(children: children);
        } else {
          return _buildEmptyView(context);
        }
      },
      error: (err, _) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Center _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list, size: 96),
          Text("No tasks", style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
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
    return project.subprojects
        .map(
          (subproject) => ListTile(
            leading: Icon(Icons.list),
            onTap: () {
              _navigateToDetail(context, subproject);
            },
            title: Text(
              subproject.title,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildTaskList(WidgetRef ref, List<Task> tasks) {
    return List.generate(tasks.length * 2, (i) {
      if (i.isOdd) return Divider();

      final index = i ~/ 2;

      return _buildTile(ref, tasks[index]);
    });
  }

  Widget _buildTile(WidgetRef ref, Task task) {
    return TaskTile(
      key: Key(task.id.toString()),
      task: task,
      onTap: () => _showTaskBottomSheet(ref.context, task),
      onEdit: () => _onEdit(ref.context, task),
      onCheckedChanged: (value) {
        task.done = value;
        ref.read(projectControllerProvider(project).notifier).updateTask(task);
      },
      showInfo: true,
    );
  }

  void _showTaskBottomSheet(BuildContext context, Task task) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (BuildContext context) {
        return TaskBottomSheet(
          task: task,
          onEdit: () => _onEdit(context, task),
        );
      },
    );
  }

  void _onEdit(BuildContext context, Task task) {
    Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (buildContext) => TaskEditPage(task: task)),
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
