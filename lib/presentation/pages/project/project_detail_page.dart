import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  ProjectPageState createState() => ProjectPageState();
}

class ProjectPageState extends ConsumerState<ProjectDetailPage> {
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    var projectController = ref.watch(
      projectControllerProvider(widget.project),
    );

    return projectController.when(
      data: (data) {
        return Scaffold(
          appBar: _buildAppBar(context, data.project, data.displayDoneTask),
          body: RefreshIndicator(
            onRefresh: () {
              return ref
                  .read(projectControllerProvider(widget.project).notifier)
                  .loadForView(data.project, _viewIndex);
            },
            child: getBody(data.project),
          ),
          floatingActionButton: _buildFab(data.project),
          bottomNavigationBar: _buildBottomNavigation(data.project),
        );
      },
      error: (err, _) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget getBody(Project project) {
    if (project.views.isEmpty) {
      return Text("No views");
    }

    switch (project.views[_viewIndex].viewKind) {
      case ViewKind.list:
        return ProjectTaskList(project);
      case ViewKind.kanban:
        return KanbanWidget(project: project);
      default:
        return Text("Not implemented");
    }
  }

  AppBar _buildAppBar(
    BuildContext context,
    Project project,
    bool displayDoneTask,
  ) {
    return AppBar(
      title: Text(project.title),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectEditPage(
                project: project,
                displayDoneTask: displayDoneTask,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Builder? _buildFab(Project project) {
    if (project.views.isEmpty ||
        project.views[_viewIndex].viewKind == ViewKind.kanban ||
        project.id < 0) {
      return null;
    }

    return Builder(
      builder: (context) => FloatingActionButton(
        onPressed: () => _addITaskDialog(context, project),
        child: Icon(Icons.add),
      ),
    );
  }

  BottomNavigationBar? _buildBottomNavigation(Project project) {
    if (project.views.length >= 2) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: project.views
            .map(
              (view) => BottomNavigationBarItem(
                icon: view.icon,
                label: view.title,
                tooltip: view.title,
              ),
            )
            .toList(),
        currentIndex: _viewIndex,
        onTap: _onViewTapped,
      );
    }

    return null;
  }

  Future<void> _addITaskDialog(BuildContext context, Project project) {
    return showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) => _addItem(context, project, title),
      ),
    );
  }

  Future<void> _addItem(
    BuildContext context,
    Project project,
    String title,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    final task = Task(
      title: title,
      createdBy: currentUser,
      done: false,
      projectId: project.id,
    );

    await ref
        .read(projectControllerProvider(widget.project).notifier)
        .addTask(project, task);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('The task was added successfully!')));
  }

  void _onViewTapped(int index) {
    setState(() {
      _viewIndex = index;

      ref
          .read(projectControllerProvider(widget.project).notifier)
          .loadForView(widget.project, _viewIndex);
    });
  }
}
