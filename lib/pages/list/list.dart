import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';


class ListPage extends StatefulWidget {
  final TaskList taskList;

  ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  TaskList _list;
  List<Task> _loadingTasks = [];
  int _currentPage = 1;

  @override
  void initState() {
    _list = TaskList(
      id: widget.taskList.id,
      title: widget.taskList.title,
      tasks: [],
    );
    Future.microtask(() => _loadList());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final taskState = Provider.of<ListProvider>(context);
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
        // TODO: it brakes the flow with _loadingTasks and conflicts with the provider
        body: !taskState.isLoading
            ? RefreshIndicator(
                child: taskState.tasks.length > 0
                  ? ListenableProvider.value(
                      value: taskState,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        itemBuilder: (context, i) {
                          if (i.isOdd) return Divider();

                          if (_loadingTasks.isNotEmpty) {
                            final loadingTask = _loadingTasks.removeLast();
                            return _buildLoadingTile(loadingTask);
                          }

                          final index = i ~/ 2;

                          // This handles the case if there are no more elements in the list left which can be provided by the api
                          if (taskState.maxPages == _currentPage &&
                              index == taskState.tasks.length - 1) return null;

                          if (index >= taskState.tasks.length &&
                              _currentPage < taskState.maxPages) {
                            _currentPage++;
                            _loadTasksForPage(_currentPage);
                          }
                          return index < taskState.tasks.length
                              ? _buildTile(taskState.tasks[index])
                              : null;
                        }
                    ),
                  )
                  : Center(child: Text('This list is empty.')),
                onRefresh: _loadList,
            )
            : Center(child: CircularProgressIndicator()),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addItemDialog(context), child: Icon(Icons.add)),
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
        Provider.of<ListProvider>(context, listen: false).updateTask(
          context: context,
          id: task.id,
          done: done,
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

  Future<void> _loadList() async {
    _loadTasksForPage(1);
  }

  void _loadTasksForPage(int page) {
    Provider.of<ListProvider>(context, listen: false).loadTasks(
      context: context,
      listId: _list.id,
      page: page,
    );
  }

  _addItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addItem(title, context),
        decoration: InputDecoration(
            labelText: 'Task Name',
            hintText: 'eg. Milk',
        ),
      ),
    );
  }

  _addItem(String title, BuildContext context) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
      id: null,
      title: title,
      createdBy: globalState.currentUser,
      done: false,
    );
    setState(() => _loadingTasks.add(newTask));
    Provider.of<ListProvider>(context, listen: false)
        .addTask(
          context: context,
          newTask: newTask,
          listId: _list.id,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully!'),
      ));
    });
  }
}