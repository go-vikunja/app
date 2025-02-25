import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/service/services.dart';

import 'dart:developer';

import '../components/AddDialog.dart';
import '../components/SentryModal.dart';
import '../components/TaskTile.dart';
import '../components/pagestatus.dart';
import '../models/task.dart';

class HomeScreenWidget extends StatefulWidget {
  HomeScreenWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    throw UnimplementedError();
  }
}

class LandingPage extends HomeScreenWidget {
  LandingPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => LandingPageState();
}

class LandingPageState extends State<LandingPage> {
  int? defaultList;
  bool onlyDueDate = true;
  bool showToday = true;
  List<Task> _tasks = [];
  PageStatus landingPageStatus = PageStatus.built;
  static const platform = const MethodChannel('vikunja');

  Future<void> _updateDefaultList() async {
    return VikunjaGlobal.of(context).newUserService?.getCurrentUser().then(
          (value) => setState(() {
            defaultList = value?.settings?.default_project_id;
          }),
        );
  }

  void handleMethod(List<String> method) {
    switch (method[0]) {
      case "open_add_task":
        _addItemDialog(context);
        break;
      case "open_add_task_with_text":
        print("open_add_task_with_text: ${method[1]}");
        _addItemDialog(context, prefilledTitle: method[1]);
        break;
    }
  }

  void scheduleIntent() async {
    try {
      // This is needed when app is already open and quicktile is clicked
      List<String>? method = (await platform.invokeMethod("isQuickTile", ""))
          .map<String>((val) => val.toString())
          .toList();

      if (method != null) {
        handleMethod(method);
      }
    } catch (e) {
      log(e.toString());
    }
    platform.setMethodCallHandler((call) async {
      handleMethod([call.method.toString(), call.arguments.toString()]);
      return Future.value();
    });
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      _updateDefaultList().then((_) {
        scheduleIntent();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (landingPageStatus) {
      case PageStatus.built:
        _loadList(context);
        body = new Stack(children: [
          ListView(),
          Center(
            child: CircularProgressIndicator(),
          )
        ]);
        break;
      case PageStatus.loading:
        body = new Stack(children: [
          ListView(),
          Center(
            child: CircularProgressIndicator(),
          )
        ]);
        break;
      case PageStatus.error:
        body = new Stack(children: [
          ListView(),
          Center(child: Text("There was an error loading this view"))
        ]);
        break;
      case PageStatus.empty:
        body = new Stack(
            children: [ListView(), Center(child: Text("This view is empty"))]);
        break;
      case PageStatus.success:
        showSentryModal(context, VikunjaGlobal.of(context));
        body = ListView(
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.symmetric(vertical: 8.0),
          children:
              ListTile.divideTiles(context: context, tiles: _listTasks(context))
                  .toList(),
        );
        break;
    }
    return new Scaffold(
      body: RefreshIndicator(onRefresh: () => _loadList(context), child: body),
      floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
                onPressed: () {
                  _addItemDialog(context);
                },
                child: const Icon(Icons.add),
              )),
      appBar: AppBar(
        title: Text("Vikunja"),
        actions: [
          PopupMenuButton(itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(
                  child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        bool newval = !onlyDueDate;
                        VikunjaGlobal.of(context)
                            .settingsManager
                            .setLandingPageOnlyDueDateTasks(newval)
                            .then((value) {
                          setState(() {
                            onlyDueDate = newval;
                            _loadList(context);
                          });
                        });
                      },
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("Only show tasks with due date"),
                            Checkbox(
                              value: onlyDueDate,
                              onChanged: (bool? value) {},
                            )
                          ]))),
              PopupMenuItem(
                  child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        bool newvaltoday = !showToday;
                        VikunjaGlobal.of(context)
                            .settingsManager
                            .setLandingPageTodayTasks(newvaltoday)
                            .then((value) {
                          setState(() {
                            showToday = newvaltoday;
                            _loadList(context);
                          });
                        });
                      },
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("Only show tasks for today"),
                            Checkbox(
                              value: showToday,
                              onChanged: (bool? value) {},
                            )
                          ])))
            ];
          }),
        ],
      ),
    );
  }

  _addItemDialog(BuildContext context, {String? prefilledTitle}) {
    if (defaultList == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a default list in the settings'),
      ));
    } else {
      showDialog(
          context: context,
          builder: (_) => AddDialog(
              prefilledTitle: prefilledTitle,
              onAddTask: (title, dueDate) => _addTask(title, dueDate, context),
              decoration: new InputDecoration(
                  labelText: 'Task Name', hintText: 'eg. Milk')));
    }
  }

  Future<void> _addTask(
      String title, DateTime? dueDate, BuildContext context) async {
    final globalState = VikunjaGlobal.of(context);
    if (globalState.currentUser == null) {
      return;
    }

    await globalState.taskService.add(
      defaultList!,
      Task(
        title: title,
        dueDate: dueDate,
        createdBy: globalState.currentUser!,
        projectId: defaultList!,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('The task was added successfully!'),
    ));
    _loadList(context).then((value) => setState(() {}));
  }

  List<Widget> _listTasks(BuildContext context) {
    var tasks = (_tasks.map((task) => _buildTile(task, context))).toList();
    //tasks.addAll(_loadingTasks.map(_buildLoadingTile));
    return tasks;
  }

  TaskTile _buildTile(Task task, BuildContext context) {
    // key: UniqueKey() seems like a weird workaround to fix the loading issue
    // is there a better way?
    return TaskTile(
      key: UniqueKey(),
      task: task,
      onEdit: () => _loadList(context),
      showInfo: true,
    );
  }

  Future<void> _loadList(BuildContext context) {
    _tasks = [];
    landingPageStatus = PageStatus.loading;
    // FIXME: loads and reschedules tasks each time list is updated
    VikunjaGlobal.of(context)
        .notifications
        .scheduleDueNotifications(VikunjaGlobal.of(context).taskService);
    return VikunjaGlobal.of(context)
        .settingsManager
        .getLandingPageTasks()
        .then((showOnlyDueDateTasks) {
      VikunjaGlobalState global = VikunjaGlobal.of(context);
      Map<String, dynamic>? frontend_settings =
          global.currentUser?.settings?.frontend_settings;
      int? filterId = 0;
      if (frontend_settings != null) {
        if (frontend_settings["filter_id_used_on_overview"] != null)
          filterId = frontend_settings["filter_id_used_on_overview"];
      }
      // in case user set a filter id for the landing page in the settings
      if (filterId != null && filterId != 0) {
        return global.taskService.getAllByProject(filterId, {
          "sort_by": ["due_date", "id"],
          "order_by": ["asc", "desc"],
        }).then<Future<void>?>((response) => _handleTaskList(response?.body));
        ;
      }
      List<String> filterStrings = ["done = false"];
      if (showOnlyDueDateTasks['landing-page-due-date-tasks'] == true) {
        filterStrings.add("due_date > 0001-01-01 00:00");
      }
      if (showOnlyDueDateTasks['landing-page-today-tasks'] == true) {
        filterStrings.add("due_date < now/d+1d");
      }
      return global.taskService.getByFilterString(filterStrings.join(" && "), {
        "sort_by": ["due_date", "id"],
        "order_by": ["asc", "desc"],
        "filter_include_nulls": ["false"],
      }).then<Future<void>?>((taskList) => _handleTaskList(taskList));
    }); //.onError((error, stackTrace) {print("error");});
  }

  Future<void> _handleTaskList(List<Task>? taskList) {
    if (taskList != null && taskList.isEmpty) {
      setState(() {
        landingPageStatus = PageStatus.empty;
      });
      return Future.value();
    }
    //taskList.forEach((task) {task.list = lists.firstWhere((element) => element.id == task.list_id);});
    setState(() {
      if (taskList != null) {
        _tasks = taskList;
        landingPageStatus = PageStatus.success;
      } else {
        landingPageStatus = PageStatus.error;
      }
    });
    return Future.value();
  }
}
