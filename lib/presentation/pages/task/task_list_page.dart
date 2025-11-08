import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';
import 'package:vikunja_app/presentation/widgets/task_tile.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  TaskListPageState createState() => TaskListPageState();
}

class TaskListPageState extends ConsumerState<TaskListPage> {
  static const platform = MethodChannel('vikunja');

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      scheduleIntent();
    });
  }

  @override
  Widget build(BuildContext context) {
    var pageModel = ref.watch(taskPageControllerProvider);

    //TODO find a better place for that
    ref
        .read(notificationProvider)
        ?.scheduleDueNotifications(ref.read(taskRepositoryProvider));

    return pageModel.when(
      data: (model) {
        updateWidget();
        return Scaffold(
          appBar: _buildAppBar(model.onlyDueDate),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(taskPageControllerProvider.notifier).reload();
            },
            child: _buildList(model, context),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (model.defaultProjectId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please select a default project in the settings',
                    ),
                  ),
                );
              } else {
                _addItemDialog(context, model.defaultProjectId);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
      error: (err, _) => VikunjaErrorWidget(error: err),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildList(TaskPageModel model, BuildContext context) {
    if (model.tasks.isEmpty) {
      return EmptyView(Icons.list, "No tasks");
    } else {
      return ListView(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        children: ListTile.divideTiles(
          context: context,
          tiles: _listTasks(context, model.tasks),
        ).toList(),
      );
    }
  }

  AppBar _buildAppBar(bool onlyDueDate) {
    return AppBar(
      title: Text("Vikunja"),
      actions: [
        PopupMenuButton(
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                child: InkWell(
                  onTap: () {
                    _onlyDueDateChanged(context, !onlyDueDate);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("Only show tasks with due date"),
                      Checkbox(
                        value: onlyDueDate,
                        onChanged: (bool? value) {
                          _onlyDueDateChanged(context, !onlyDueDate);
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

  void _onlyDueDateChanged(BuildContext context, bool newValue) {
    Navigator.pop(context);
    ref
        .read(taskPageControllerProvider.notifier)
        .setLandingPageOnlyDueDateTasks(newValue);
  }

  void _addItemDialog(BuildContext context, int defaultProjectId) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addTask(title, dueDate, defaultProjectId, context),
      ),
    );
  }

  Future<void> _addTask(
    String title,
    DateTime? dueDate,
    int defaultProjectId,
    BuildContext context,
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

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The task was added successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding the task!')));
    }
  }

  List<Widget> _listTasks(BuildContext context, List<Task> tasks) {
    return tasks
        .map(
          (task) => TaskTile(
            key: Key(task.id.toString()),
            task: task,
            onTap: () {
              _showTaskBottomSheet(context, task);
            },
            onEdit: () => _onEdit(context, task),
            onCheckedChanged: (value) async {
              var success = await ref
                  .read(taskPageControllerProvider.notifier)
                  .markAsDone(task);
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error marking task as done')),
                );
              }
            },
            showInfo: true,
          ),
        )
        .toList();
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

  //TODO should we move that up the widget tree - It's not really specific to that page
  void scheduleIntent() async {
    var response = await ref.read(userRepositoryProvider).getCurrentUser();
    if (response.isSuccessful) {
      var defaultProjectId = response
          .toSuccess()
          .body
          .settings
          ?.default_project_id;

      platform.setMethodCallHandler((call) async {
        if (defaultProjectId == null || defaultProjectId == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select a default project in the settings'),
            ),
          );
        } else {
          _addItemDialog(context, defaultProjectId);
          return Future.value();
        }
      });
    }
  }
}
