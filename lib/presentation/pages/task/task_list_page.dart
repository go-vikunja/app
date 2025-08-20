import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/widgets/AddDialog.dart';
import 'package:vikunja_app/presentation/widgets/task_tile.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  TaskListPageState createState() => TaskListPageState();
}

class TaskListPageState extends ConsumerState<TaskListPage> {
  static const platform = const MethodChannel('vikunja');

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

    //TODO workaround until notification are migrated to riverpod
    pageModel.whenData((data) {
      VikunjaGlobal.of(context)
          .notifications
          .scheduleDueNotifications(ref.read(taskRepositoryProvider));
    });

    return pageModel.when(
      data: (model) {
        return Scaffold(
          appBar: _buildAppBar(model.onlyDueDate),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(taskPageControllerProvider.notifier).reload();
            },
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: 8.0),
              children: ListTile.divideTiles(
                      context: context, tiles: _listTasks(context, model.tasks))
                  .toList(),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _addItemDialog(context, model.defaultProjectId);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
      error: (err, _) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  AppBar _buildAppBar(bool onlyDueDate) {
    return AppBar(
      title: Text("Vikunja"),
      actions: [
        PopupMenuButton(itemBuilder: (BuildContext context) {
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
                    )
                  ],
                ),
              ),
            )
          ];
        }),
      ],
    );
  }

  void _onlyDueDateChanged(BuildContext context, bool newValue) {
    Navigator.pop(context);
    ref
        .read(taskPageControllerProvider.notifier)
        .setLandingPageOnlyDueDateTasks(newValue);
  }

  _addItemDialog(BuildContext context, int defaultProjectId,
      {String? prefilledTitle}) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        prefilledTitle: prefilledTitle,
        onAddTask: (title, dueDate) =>
            _addTask(title, dueDate, defaultProjectId, context),
        decoration: InputDecoration(
          labelText: 'Task Name',
          hintText: 'eg. Milk',
        ),
      ),
    );
  }

  Future<void> _addTask(String title, DateTime? dueDate, int defaultProjectId,
      BuildContext context) async {
    final globalState = VikunjaGlobal.of(context);
    if (globalState.currentUser == null) {
      return;
    }

    var task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: globalState.currentUser!,
      projectId: defaultProjectId,
    );

    ref
        .read(taskPageControllerProvider.notifier)
        .addTask(defaultProjectId, task);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('The task was added successfully!'),
    ));

    ref.read(taskPageControllerProvider.notifier).reload();
  }

  List<Widget> _listTasks(BuildContext context, List<Task> tasks) {
    return tasks
        .map(
          (task) => TaskTile(
            key: Key(task.id.toString()),
            task: task,
            onEdit: () {},
            showInfo: true,
          ),
        )
        .toList();
  }

  //TODO should we move that up the widget tree - It's not really specific to that page
  void scheduleIntent() async {
    ref.read(userRepositoryProvider).getCurrentUser().then((user) async {
      var defaultProject = user.settings?.default_project_id;

      if (defaultProject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a default project in the settings'),
          ),
        );
      } else {
        platform.setMethodCallHandler((call) async {
          _addItemDialog(context, defaultProject);
          return Future.value();
        });
      }
    });
  }
}
