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
  List<Task> _tasks = [];
  List<Task> _loadingTasks = [];
  bool _loading = true;
  int _currentPage = 1;

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
                            )
                    )
                ),
            ),
          ],
        ),
        body: !taskState.isLoading
            ? RefreshIndicator(
                child: taskState.tasks.length > 0
                    ? ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        // children: ListTile.divideTiles(context: context, tiles: _listTasks()).toList(),
                        itemBuilder: (context, i) {
                          if (i.isOdd) return Divider();

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
                              ? TaskTile(
                                  task: taskState.tasks[index],
                                )
                              : null;
                        })
                    : Center(child: Text('This list is empty.')),
                onRefresh: _loadList,
              )
            : Center(child: CircularProgressIndicator()),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addItemDialog(context), child: Icon(Icons.add),
          ),
        ));
  }

  List<Widget> _listTasks() {
    var tasks = (_tasks?.map(_buildTile) ?? []).toList();
    tasks.addAll(_loadingTasks.map(_buildLoadingTile));
    return tasks;
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
            ))
            .then((newTask) => setState(() {
                  // FIXME: This is ugly. We should use a redux to not have to do these kind of things.
                  //  This is enough for now (it works™) but we should definitly fix it later.
                  _list.tasks.asMap().forEach((i, t) {
                    if (newTask.id == t.id) {
                      _list.tasks[i] = newTask;
                    }
                  });
                }));
      },
    );
  }

  TaskTile _buildLoadingTile(Task task) {
    return TaskTile(
      task: task,
      loading: true,
    );
  }

  void _loadTasksForPage(int page) {
    Provider.of<ListProvider>(context, listen: false).loadTasks(
      context: context,
      listId: _list.id,
      page: page,
    );
  }

  // Future<void> _loadTasksForPage(int page) {
  //   return VikunjaGlobal.of(context).taskService.getAll(_list.id, {
  //     "sort_by": ["done", "id"],
  //     "order_by": ["asc", "desc"],
  //     "page": [page.toString()]
  //   }).then((tasks) {
  //     setState(() {
  //       _loading = false;
  //       _tasks.addAll(tasks);
  //     });
  //   });
  // }

  Future<void> _loadList() {
    return VikunjaGlobal.of(context)
        .listService
        .get(widget.taskList.id)
        .then((list) {
      setState(() {
        _loading = true;
        _list = list;
      });
      _loadTasksForPage(_currentPage);
    });
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
        _tasks.add(task);
      });
    }).then((_) {
      _loadList();
      setState(() => _loadingTasks.remove(newTask));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully!'),
      ));
    });
  }

  Future<Task> _updateTask(Task task, bool checked) {
    // TODO use copyFrom
    return VikunjaGlobal.of(context).taskService.update(Task(
          id: task.id,
          done: checked,
        ));
  }
}
