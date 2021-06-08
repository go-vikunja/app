import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';

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
      id: widget.taskList.id,
      title: widget.taskList.title,
      tasks: [],
    );
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadList();
  }

  @override
  Widget build(BuildContext context) {
    var tasks = (_list?.tasks?.map(_buildTile) ?? []).toList();
    tasks.addAll(_loadingTasks.map(_buildLoadingTile));

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListEditPage(
                  list: _list,
                ),
              )
            ),
          ),
        ],
      ),
      body: !this._loading
          ? RefreshIndicator(
            onRefresh: _loadList,
            child: _list.tasks.length > 0
              ? ListView(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  children: ListTile.divideTiles(
                    context: context,
                    tiles: tasks,
                  ).toList(),
              )
              : Center(child: Text('This list is empty.')),
          )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
            onPressed: () => _addItemDialog(context),
            child: Icon(Icons.add),
        ),
      ),
    );
  }

  TaskTile _buildTile(Task task) {
    return TaskTile(
      task: task,
      loading: false,
      onEdit: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskEditPage(
            task: task,
          ),
        ),
      ),
      onMarkedAsDone: (done) {
        VikunjaGlobal.of(context)
            .taskService
            .update(Task(
              id: task.id,
              done: done,
            )
        ).then((newTask) => setState(() {
            // FIXME: This is ugly. We should use a redux to not have to do these kind of things.
            //  This is enough for now (it works™) but we should definitly fix it later.
            _list.tasks.asMap().forEach((i, t) {
              if (newTask.id == t.id) {
                _list.tasks[i] = newTask;
              }
            });
          })
        );
      },
    );
  }

  TaskTile _buildLoadingTile(Task task) {
    return TaskTile(
      task: task,
      loading: true,
      onEdit: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskEditPage(
            task: task,
          ),
        ),
      ),
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
                labelText: 'Task Name',
                hintText: 'eg. Milk',
            )
        )
    );
  }

  _addItem(String title, BuildContext context) {
    // FIXME: Use provider
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
      id: null,
      title: title,
      createdBy: globalState.currentUser,
      done: false,
    );
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