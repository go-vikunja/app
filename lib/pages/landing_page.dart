import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';

import '../components/AddDialog.dart';
import '../components/TaskTile.dart';
import '../models/task.dart';
import '../managers/notifications.dart';
import '../main.dart';

class LandingPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LandingPageState();

}

class LandingPageState extends State<LandingPage> {
  int defaultList;
  List<Task> _list;

  @override
  void initState() {
    Future.delayed(Duration.zero, () =>
    VikunjaGlobal.of(context).listService.getDefaultList().then((value) => setState(() => defaultList = value == null ? null : int.tryParse(value))));
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    if(_list == null)
      _loadList(context);
    VikunjaGlobal.of(context).scheduleDueNotifications();
    return new Scaffold(
        body: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              padding: EdgeInsets.only(top: 32.0),
              child: new Text(
                // VikunjaGlobal.of(context).taskServiceOptions.getOptions()
                // TaskServiceOptionSortBy.id.name
                'Welcome to Vikunja',
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            //new Text('Please select a namespace by tapping the  ☰  icon.',
            //    style: Theme.of(context).textTheme.subtitle1),
            _list != null ? new Expanded(child: ListView(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: 8.0),
              children: ListTile.divideTiles(
                  context: context, tiles: _listTasks(context)).toList(),
            )) : new Center(child: CircularProgressIndicator())
          ],
        ),
        floatingActionButton: Builder(
            builder: (context) =>
                defaultList == null ?
                FloatingActionButton(
                    backgroundColor: Colors.grey,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Please select a default list in the settings'),
                    ));},
                    child: const Icon(Icons.add))
                    :
                    FloatingActionButton(
                      onPressed: () {
                        _addItemDialog(context);
                      },
                      child: const Icon(Icons.add),
                    ),
        ));
  }
  _addItemDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
            onAddTask: (task) => _addTask(task, context),
            decoration: new InputDecoration(
                labelText: 'Task Name', hintText: 'eg. Milk')));
  }

  _addTask(Task task, BuildContext context) {
    var globalState = VikunjaGlobal.of(context);
    globalState.taskService.add(defaultList, task).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('The task was added successfully!'),
        ));
        _loadList(context).then((value) => setState((){}));
    });
  }


  List<Widget> _listTasks(BuildContext context) {
    var tasks = (_list.map((task) => _buildTile(task, context)) ?? []).toList();
    //tasks.addAll(_loadingTasks.map(_buildLoadingTile));
    return tasks;
  }

  TaskTile _buildTile(Task task, BuildContext context) {
    // key: UniqueKey() seems like a weird workaround to fix the loading issue
    // is there a better way?
    return TaskTile(key: UniqueKey(), task: task,onEdit: () => _loadList(context), showInfo: true,);
  }

  Future<void> _loadList(BuildContext context) {
    _list = [];
    return VikunjaGlobal.of(context)
        .taskService
        .getByOptions(VikunjaGlobal.of(context).taskServiceOptions)
        .then((taskList) {
          VikunjaGlobal.of(context)
          .listService
          .getAll()
          .then((lists) {
            //taskList.forEach((task) {task.list = lists.firstWhere((element) => element.id == task.list_id);});
            setState(() {
              _list = taskList;
            });
          });
        });
  }


}
