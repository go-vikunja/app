import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/global.dart';

import 'dart:developer';

import '../components/AddDialog.dart';
import '../components/TaskTile.dart';
import '../components/pagestatus.dart';
import '../models/task.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => LandingPageState();
}


class LandingPageState extends State<LandingPage>
    with AfterLayoutMixin<LandingPage> {
  int? defaultList;
  List<Task> _list = [];
  PageStatus landingPageStatus = PageStatus.built;
  static const platform = const MethodChannel('vikunja');

  Future<void> _updateDefaultList() async {
    return VikunjaGlobal.of(context).listService.getDefaultList().then(
        (value) => setState(
            () => defaultList = value == null ? null : int.tryParse(value)));
  }

  @override
  void initState() {
    Future.delayed(
        Duration.zero,
        () => _updateDefaultList().then((value) {
              try {
                platform.invokeMethod("isQuickTile", "").then((value) =>
                    {if (value is bool && value) _addItemDialog(context)});
              } catch (e) {
                log(e.toString());
              }
            }));
    super.initState();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    try {
      // This is needed when app is already open and quicktile is clicked
      platform.setMethodCallHandler((call) {
        switch (call.method) {
          case "open_add_task":
            _addItemDialog(context);
            break;
        }
        return Future.value();
      });
    } catch (e) {
      log(e.toString());
    }
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
      case PageStatus.success:
        body = ListView(
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 8.0),
          children:
              ListTile.divideTiles(context: context, tiles: _listTasks(context))
                  .toList(),
        );
        break;
    }
    return new Scaffold(
        body:
            RefreshIndicator(onRefresh: () => _loadList(context), child: body),
        floatingActionButton: Builder(
            builder: (context) => FloatingActionButton(
                  onPressed: () {
                    _addItemDialog(context);
                  },
                  child: const Icon(Icons.add),
                )));
  }

  _addItemDialog(BuildContext context) {
    if (defaultList == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a default list in the settings'),
      ));
    } else {
      showDialog(
          context: context,
          builder: (_) => AddDialog(
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
        listId: defaultList!,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('The task was added successfully!'),
    ));
    _loadList(context).then((value) => setState(() {}));
  }

  List<Widget> _listTasks(BuildContext context) {
    var tasks = (_list.map((task) => _buildTile(task, context))).toList();
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
    log("reloading list");
    _list = [];
    landingPageStatus = PageStatus.loading;
    // FIXME: loads and reschedules tasks each time list is updated
    VikunjaGlobal.of(context).notifications.scheduleDueNotifications(VikunjaGlobal.of(context).taskService);
    return VikunjaGlobal.of(context)
        .taskService
        .getByOptions(VikunjaGlobal.of(context).taskServiceOptions)
        .then<Future<void>?>((taskList) {
      if (taskList != null && taskList.isEmpty) {
        landingPageStatus = PageStatus.error;
        return null;
      }
      return VikunjaGlobal.of(context).listService.getAll().then((lists) {
        //taskList.forEach((task) {task.list = lists.firstWhere((element) => element.id == task.list_id);});
        setState(() {
          if (taskList != null) {
            _list = taskList;
            landingPageStatus = PageStatus.success;
          } else {
            landingPageStatus = PageStatus.error;
          }
        });
        return null;
      });
    });
  }
}
