import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';

class ListPage extends StatefulWidget {
  final TaskList taskList;

  ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  TaskList _list;
  bool _loading = true;
  bool displayDoneTasks;
  int listId;

  @override
  void initState() {
    _list = TaskList(
        id: widget.taskList.id, title: widget.taskList.title, tasks: []);
    listId = _list.id;
    Future.delayed(Duration.zero, (){
      VikunjaGlobal.of(context).listService.getDisplayDoneTasks(listId)
          .then((value) => setState((){displayDoneTasks = value == "1";}));
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _loadList();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: new Text(_list.title),
          actions: <Widget>[
            IconButton(
                icon: Icon(Icons.edit),
                onPressed: ()  =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ListEditPage(
                              list: _list,
                            ))).whenComplete(() {
                              setState(() {this._loading = true;});
                              VikunjaGlobal.of(context).listService.getDisplayDoneTasks(listId).then((value) {
                                displayDoneTasks = value == "1";
                                _loadList();
                                setState(() => this._loading = false);
                              });
                            })
                )
          ],
        ),
        body: !this._loading
            ? RefreshIndicator(
                child: _list.tasks.length > 0
                    ? ListView(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        children: ListTile.divideTiles(
                                context: context, tiles: _listTasks())
                            .toList(),
                      )
                    : Center(child: Text('This list is empty.')),
                onRefresh: _loadList,
              )
            : Center(child: CircularProgressIndicator()),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addItemDialog(context), child: Icon(Icons.add)),
        ));
  }

  List<Widget> _listTasks() {
    var tasks = (_list.tasks.map(_buildTile) ?? []).toList();
    //tasks.addAll(_loadingTasks.map(_buildLoadingTile));
    return tasks;
  }

  TaskTile _buildTile(Task task) {
    // key: UniqueKey() seems like a weird workaround to fix the loading issue
    // is there a better way?
    return TaskTile(key: UniqueKey(), task: task,onEdit: () => _loadList());
  }

  Future<void> _loadList() {
    return VikunjaGlobal.of(context)
        .listService
        .get(widget.taskList.id)
        .then((list) {
      setState(() {
        _loading = false;
        if(displayDoneTasks != null && !displayDoneTasks)
          list.tasks.removeWhere((element) => element.done);
        _list = list;
      });
    });
  }

  _addItemDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
            onAdd: (name) => _addItem(name, context),
            decoration: new InputDecoration(
                labelText: 'Task Name', hintText: 'eg. Milk')));
  }

  _addItem(String name, BuildContext context) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
        id: null, title: name, owner: globalState.currentUser, done: false, loading: true);
    setState(() => _list.tasks.add(newTask));
    globalState.taskService.add(_list.id, newTask).then((_) {
      _loadList().then((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('The task was added successfully!'),
        ));
      });
    });
  }
}
