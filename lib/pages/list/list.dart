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
  List<Task> _loadingTasks = [];
  bool _loading = true;

  @override
  void initState() {
    _list = TaskList(
        id: widget.taskList.id, title: widget.taskList.title, tasks: []);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadList();
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
                            ))).whenComplete(() {_loadList(); setState(() {});})
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
    var tasks = (_list?.tasks?.map(_buildTile) ?? []).toList();
    tasks.addAll(_loadingTasks.map(_buildLoadingTile));
    return tasks;
  }

  TaskTile _buildTile(Task task) {
    return TaskTile(task: task, loading: false);
  }

  TaskTile _buildLoadingTile(Task task) {
    return TaskTile(
      task: task,
      loading: true,
    );
  }

  Future<void> _loadList() {
    return VikunjaGlobal.of(context)
        .listService
        .get(widget.taskList.id)
        .then((list) {
      setState(() {
        _loading = false;
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
        id: null, title: name, owner: globalState.currentUser, done: false);
    setState(() => _loadingTasks.add(newTask));
    globalState.taskService.add(_list.id, newTask).then((task) {
      setState(() {
        _list.tasks.add(task);
      });
    }).then((_) {
      _loadList();
      setState(() => _loadingTasks.remove(newTask));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully!'),
      ));
    });
  }
}
