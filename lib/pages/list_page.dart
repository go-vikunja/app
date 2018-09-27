import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';

class ListPage extends StatefulWidget {
  final TaskList taskList;

  ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  TaskList _items;
  List<Task> _loadingTasks = [];
  bool _loading = true;

  @override
  void initState() {
    _items = TaskList(
        id: widget.taskList.id, title: widget.taskList.title, tasks: []);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: new Text(_items.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => {/* TODO add edit list functionality */},
          )
        ],
      ),
      body: !this._loading
          ? RefreshIndicator(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                children:
                    ListTile.divideTiles(context: context, tiles: _listTasks())
                        .toList(),
              ),
              onRefresh: _updateList,
            )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _addItemDialog(), child: Icon(Icons.add)),
    );
  }

  List<Widget> _listTasks() {
    var tasks = (_items?.tasks?.map(_buildTile) ?? []).toList();
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

  Future<void> _updateList() {
    return VikunjaGlobal.of(context)
        .listService
        .get(widget.taskList.id)
        .then((tasks) {
      setState(() {
        _loading = false;
        _items = tasks;
      });
    });
  }

  _addItemDialog() {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
            onAdd: _addItem,
            decoration: new InputDecoration(
                labelText: 'List Item', hintText: 'eg. Milk')));
  }

  _addItem(String name) {
    var globalState = VikunjaGlobal.of(context);
    var newTask =
        Task(id: null, text: name, owner: globalState.currentUser, done: false);
    setState(() => _loadingTasks.add(newTask));
    globalState.taskService.add(_items.id, newTask).then((task) {
      setState(() {
        _items.tasks.add(task);
      });
    }).then((_) => _updateList()
        .then((_) => setState(() => _loadingTasks.remove(newTask))));
  }
}
