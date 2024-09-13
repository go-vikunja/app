import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/KanbanWidget.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/pages/project/project_edit.dart';
import 'package:vikunja_app/pages/project/task_edit.dart';

import '../../components/pagestatus.dart';
import '../../models/project.dart';
import '../../stores/project_store.dart';

enum BucketMenu { limit, done, delete }

class BucketProps {
  final ScrollController controller = ScrollController();
  final TextEditingController titleController = TextEditingController();
  bool scrollable = false;
  bool portrait = true;
  int bucketLength = 0;
  Size? taskDropSize;
}

class ListPage extends StatefulWidget {
  final Project project;

  //ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));
  ListPage({required this.project})
      : super(key: Key(Random().nextInt(100000).toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _keyboardController = KeyboardVisibilityController();
  int _viewIndex = 0;
  late Project _project;
  List<Task> _loadingTasks = [];
  int _currentPage = 1;
  bool displayDoneTasks = false;
  late ProjectProvider taskState;
  late KanbanClass _kanban;

  @override
  void initState() {
    _project = widget.project;
    _keyboardController.onChange.listen((visible) {
      if (!visible && mounted) FocusScope.of(context).unfocus();
    });
    super.initState();
  }

  void nullSetState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    taskState = Provider.of<ProjectProvider>(context);
    _kanban = KanbanClass(context, nullSetState, _onViewTapped, _addItemDialog,
        _project, _project.views[_viewIndex]);

    Widget body;

    switch (taskState.pageStatus) {
      case PageStatus.built:
        Future.delayed(Duration.zero, _loadList);
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
        body = taskState.tasks.length > 0 ||
                taskState.buckets.length > 0 ||
                _project.subprojects!.length > 0
            ? ListenableProvider.value(
                value: taskState,
                child: Theme(
                  data: (ThemeData base) {
                    return base.copyWith(
                      chipTheme: base.chipTheme.copyWith(
                        labelPadding: EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                      ),
                    );
                  }(Theme.of(context)),
                  child: () {
                    switch (_project.views[_viewIndex].viewKind) {
                      case "list":
                        return _listView(context);
                      case "kanban":
                        return _kanban.kanbanView();
                      default:
                        return Text("Not implemented");
                    }
                  }(),
                ),
              )
            : Stack(children: [
                ListView(),
                Center(child: Text('This list is empty.'))
              ]);
        break;
      case PageStatus.empty:
        body = new Stack(
            children: [ListView(), Center(child: Text("This view is empty"))]);
        break;
    }

    return new Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectEditPage(
                    project: _project,
                  ),
                )).whenComplete(() => _loadList()),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: () => _loadList(), child: body),
      floatingActionButton: _project.views[_viewIndex].viewKind == "kanban" || _project.id < 0
          ? null
          : Builder(
              builder: (context) => FloatingActionButton(
                  onPressed: () => _addItemDialog(context),
                  child: Icon(Icons.add)),
            ),
      bottomNavigationBar: _project.views.length >= 2
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: _project.views
                  .map((view) => BottomNavigationBarItem(
                        icon: view.icon,
                        label: view.title,
                        tooltip: view.title,
                      ))
                  .toList(),
/*
          ;const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'List',
            tooltip: 'List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_kanban),
            label: 'Kanban',
            tooltip: 'Kanban',
          ),
        ], */
              currentIndex: _viewIndex,
              onTap: _onViewTapped,
            )
          : null,
    );
  }

  Widget buildSubProjectSelector() {
    return Container(
      height: 80,
      padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...?widget.project.subprojects?.map((elem) => InkWell(
              onTap: () {
                openList(context, elem);
              },
              child: Container(
                  alignment: Alignment.center,
                  height: 20,
                  width: 100,
                  child: Text(
                    elem.title,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  )))),
        ],
      ),
    );
  }

  void _onViewTapped(int index) {
    _kanban.view = _project.views[index];
    _loadList().then((_) {
      _currentPage = 1;
      setState(() {
        _viewIndex = index;
      });
    });
  }

  Widget _listView(BuildContext context) {
    List<Widget> children = [];
    if (widget.project.subprojects?.length != 0) {
      children.add(Padding(
        child: Text(
          "Projects",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
      ));
      children.add(buildSubProjectSelector());
    }
    if (taskState.tasks.length != 0) {
      children.add(Padding(
        child: Text(
          "Tasks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
      ));
      children.add(Divider());
      children.add(Expanded(
          child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              itemCount: taskState.tasks.length * 2,
              itemBuilder: (context, i) {
                if (i.isOdd) return Divider();

                if (_loadingTasks.isNotEmpty) {
                  final loadingTask = _loadingTasks.removeLast();
                  return _buildLoadingTile(loadingTask);
                }

                final index = i ~/ 2;

                if (taskState.maxPages == _currentPage &&
                    index == taskState.tasks.length)
                  throw Exception("Check itemCount attribute");

                if (index >= taskState.tasks.length &&
                    _currentPage < taskState.maxPages) {
                  _currentPage++;
                  _loadTasksForPage(_currentPage);
                }
                return _buildTile(taskState.tasks[index]);
              })));
    }

    return Column(children: children);
  }

  Widget _buildTile(Task task) {
    return ListenableProvider.value(
      value: taskState,
      child: TaskTile(
        task: task,
        loading: false,
        onEdit: () {},
        onMarkedAsDone: (done) {
          Provider.of<ProjectProvider>(context, listen: false).updateTask(
            context: context,
            task: task.copyWith(done: done),
          );
        },
      ),
    );
  }

  Future<void> updateDisplayDoneTasks() {
    return VikunjaGlobal.of(context)
        .projectService
        .getDisplayDoneTasks(_project.id)
        .then((value) {
      displayDoneTasks = value == "1";
    });
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
            taskState: taskState,
          ),
        ),
      ),
    );
  }

  Future<void> _loadList() async {
    taskState.pageStatus = (PageStatus.loading);

    updateDisplayDoneTasks().then((value) async {
      switch (_project.views[_viewIndex].viewKind) {
        case "list":
          _loadTasksForPage(1);
          break;
        case "kanban":
          await _kanban.loadBucketsForPage(1);
          // load all buckets to get length for RecordableListView
          while (_currentPage < taskState.maxPages) {
            _currentPage++;
            await _kanban.loadBucketsForPage(_currentPage);
          }
          break;
        default:
          _loadTasksForPage(1);
      }
    });
  }

  Future<void> _loadTasksForPage(int page) {
    return Provider.of<ProjectProvider>(context, listen: false).loadTasks(
        context: context,
        listId: _project.id,
        page: page,
        displayDoneTasks: displayDoneTasks);
  }

  Future<void> _addItemDialog(BuildContext context,
      [Bucket? bucket, String? taskName]) {
    return showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addItem(title, context, bucket),
        decoration: InputDecoration(
          labelText:
              (bucket != null ? '\'${bucket.title}\': ' : '') + 'New Task Name',
          hintText: 'eg. Milk',
        ),
      ),
    );
  }

  Future<void> _addItem(String title, BuildContext context,
      [Bucket? bucket]) async {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    final newTask = Task(
      title: title,
      createdBy: currentUser,
      done: false,
      bucketId: bucket?.id,
      projectId: _project.id,
    );
    setState(() => _loadingTasks.add(newTask));
    return Provider.of<ProjectProvider>(context, listen: false)
        .addTask(
      context: context,
      newTask: newTask,
      listId: _project.id,
    )
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully' +
            (bucket != null ? ' to \'${bucket.title}\'' : '') +
            '!'),
      ));
      setState(() {
        _loadingTasks.remove(newTask);
        _loadList();
      });
    });
  }
}

openList(BuildContext context, Project project) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider<ProjectProvider>(
      create: (_) => new ProjectProvider(),
      child: ListPage(
        project: project,
      ),
    ),
    // ListPage(taskList: list)
  ));
}
