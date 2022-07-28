import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/components/SliverBucketList.dart';
import 'package:vikunja_app/components/SliverBucketPersistentHeader.dart';
import 'package:vikunja_app/components/BucketLimitDialog.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';

enum BucketMenu {limit, done, delete}

class BucketProps {
  final ValueKey<int> key;
  bool scrollable = false;
  final ScrollController controller = ScrollController();
  final TextEditingController titleController = TextEditingController();
  BucketProps(this.key);
}

class ListPage extends StatefulWidget {
  final TaskList taskList;

  //ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));
  ListPage({this.taskList}) : super(key: Key(Random().nextInt(100000).toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _globalKey = GlobalKey();
  int _viewIndex = 0;
  TaskList _list;
  List<Task> _loadingTasks = [];
  int _currentPage = 1;
  bool _loading = true;
  bool displayDoneTasks;
  ListProvider taskState;
  PageController _pageController;
  Map<int, BucketProps> _bucketProps = {};
  int _draggedBucketIndex;

  @override
  void initState() {
    _list = TaskList(
      id: widget.taskList.id,
      title: widget.taskList.title,
      tasks: [],
    );
    super.initState();
    Future.delayed(Duration.zero, (){
      _loadList();
    });
  }

  @override
  Widget build(BuildContext context) {
    taskState = Provider.of<ListProvider>(context);
    KeyboardVisibilityController().onChange.listen((visible) {
      if (!visible) try {
        FocusScope.of(_globalKey.currentContext ?? context).unfocus();
      } catch (e) {}
    });
    return GestureDetector(
      key: _globalKey,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                  )).whenComplete(() => _loadList()),
            ),
          ],
        ),
        // TODO: it brakes the flow with _loadingTasks and conflicts with the provider
        body: !taskState.isLoading
            ? RefreshIndicator(
                child: taskState.tasks.length > 0 || taskState.buckets.length > 0
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
                            switch (_viewIndex) {
                              case 0:
                                return _listView(context);
                              case 1:
                                return _kanbanView(context);
                              default:
                                return _listView(context);
                            }
                          }(),
                        ),
                      )
                    : Center(child: Text('This list is empty.')),
                onRefresh: _loadList,
              )
            : Center(child: CircularProgressIndicator()),
        floatingActionButton: _viewIndex == 1 ? null : Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addItemDialog(context), child: Icon(Icons.add)),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
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
          ],
          currentIndex: _viewIndex,
          onTap: _onViewTapped,
        ),
      ),
    );
  }

  void _onViewTapped(int index) {
    _loadList().then((_) {
      _currentPage = 1;
      setState(() {
        _viewIndex = index;
      });
    });
  }

  ListView _listView(BuildContext context) {
    return ListView.builder(
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
            index == taskState.tasks.length)
          return null;

        if (index >= taskState.tasks.length &&
            _currentPage < taskState.maxPages) {
          _currentPage++;
          _loadTasksForPage(_currentPage);
        }
        return index < taskState.tasks.length
            ? _buildTile(taskState.tasks[index])
            : null;
      }
    );
  }

  Widget _kanbanView(BuildContext context) {
    final deviceData = MediaQuery.of(context);
    final bucketWidth = deviceData.size.width
        * (deviceData.orientation == Orientation.portrait ?  0.8 : 0.4);
    if (_pageController == null) _pageController = PageController(viewportFraction: 0.8);
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      scrollController: _pageController,
      physics: PageScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: taskState.buckets.length,
      itemExtent: bucketWidth,
      cacheExtent: bucketWidth,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (index > taskState.buckets.length) return null;
        return ReorderableDelayedDragStartListener(
          key: ValueKey<int>(index),
          index: index,
          enabled: taskState.buckets.length > 1,
          child: _buildBucketTile(taskState.buckets[index]),
        );
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            return Transform.scale(
              scale: lerpDouble(1.0, 0.75, Curves.easeInOut.transform(animation.value)),
              child: child,
            );
          },
        );
      },
      footer: _draggedBucketIndex != null ? null : SizedBox(
        width: bucketWidth,
        child: Column(
          children: [
            ListTile(
              title: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _addBucketDialog(context),
                  label: Text('Create Bucket'),
                  //style: ButtonStyle(alignment: Alignment.centerLeft),
                  icon: Icon(Icons.add),
                ),
              ),
            ),
            Spacer(),
          ],
        ),
      ),
      onReorderStart: (oldIndex) => setState(() => _draggedBucketIndex = oldIndex),
      onReorder: (oldIndex, newIndex) {},
      onReorderEnd: (newIndex) => setState(() {
        bool indexUpdated = false;
        if (newIndex > _draggedBucketIndex) {
          newIndex -= 1;
          indexUpdated = true;
        }
        taskState.buckets.insert(newIndex, taskState.buckets.removeAt(_draggedBucketIndex));
        if (newIndex == 0) {
          taskState.buckets[0].position = 0;
          _updateBucket(context, taskState.buckets[0]);
          newIndex = 1;
        }
        taskState.buckets[newIndex].position = newIndex == taskState.buckets.length - 1
            ? taskState.buckets[newIndex - 1].position + 1
            : (taskState.buckets[newIndex - 1].position
                + taskState.buckets[newIndex + 1].position) / 2.0;
        _updateBucket(context, taskState.buckets[newIndex]);
        _draggedBucketIndex = null;
        if (indexUpdated)
          _pageController.jumpToPage((newIndex
              / (deviceData.orientation == Orientation.portrait ? 1 : 2)).floor());
      }),
    );
  }

  TaskTile _buildTile(Task task) {
    return TaskTile(
      task: task,
      loading: false,
      onEdit: () {
        /*Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskEditPage(
                  task: task,
                ),
          ),
        );*/
      },
      onMarkedAsDone: (done) {
        Provider.of<ListProvider>(context, listen: false).updateTask(
          context: context,
          id: task.id,
          done: done,
        );
      },
    );
  }

  Widget _buildBucketTile(Bucket bucket) {
    final theme = Theme.of(context);
    final addTaskButton = ElevatedButton.icon(
      icon: Icon(Icons.add),
      label: Text('Add Task'),
      onPressed: (bucket.tasks?.length ?? -1) < bucket.limit
          ? () => _addItemDialog(context, bucket)
          : null,
    );

    if (_bucketProps[bucket.id] == null) {
      _bucketProps[bucket.id] = BucketProps(ValueKey<int>(bucket.id));
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _bucketProps[bucket.id].scrollable = _bucketProps[bucket.id].controller.position.maxScrollExtent > 0;
        });
      });
    }
    if (_bucketProps[bucket.id].titleController.text.isEmpty)
      _bucketProps[bucket.id].titleController.text = bucket.title;

    return Stack(
      key: _bucketProps[bucket.id].key,
      children: <Widget>[
        CustomScrollView(
          controller: _bucketProps[bucket.id].controller,
          slivers: <Widget>[
            SliverBucketPersistentHeader(
              minExtent: 56,
              maxExtent: 56,
              child: Material(
                color: theme.scaffoldBackgroundColor,
                child: ListTile(
                  minLeadingWidth: 15,
                  horizontalTitleGap: 4,
                  leading: bucket.isDoneBucket ? Icon(
                    Icons.done_all,
                    color: Colors.green,
                  ) : null,
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _bucketProps[bucket.id].titleController,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Bucket Title',
                          ),
                          style: theme.textTheme.titleLarge,
                          onSubmitted: (title) {
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                  'Bucket title cannot be empty!',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ));
                              return;
                            }
                            bucket.title = title;
                            _updateBucket(context, bucket);
                          },
                        ),
                      ),
                      if (bucket.limit != 0)
                        Text(
                          '${bucket.tasks?.length ?? 0}/${bucket.limit}',
                          style: theme.textTheme.titleMedium.copyWith(
                            color: (bucket.tasks?.length ?? -1) >= bucket.limit
                                ? Colors.red : null,
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<BucketMenu>(
                    child: Icon(Icons.more_vert),
                    onSelected: (item) {
                      switch (item) {
                        case BucketMenu.limit:
                          showDialog<int>(context: context,
                            builder: (_) => BucketLimitDialog(
                              bucket: bucket,
                            ),
                          ).then((limit) {
                            if (limit != null) {
                              bucket.limit = limit;
                              _updateBucket(context, bucket);
                            }
                          });
                          break;
                        case BucketMenu.done:
                          bucket.isDoneBucket = !bucket.isDoneBucket;
                          _updateBucket(context, bucket);
                          break;
                        case BucketMenu.delete:
                          _deleteBucket(context, bucket);
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<BucketMenu>>[
                      PopupMenuItem<BucketMenu>(
                        value: BucketMenu.limit,
                        child: Text('Limit: ${bucket.limit}'),
                      ),
                      PopupMenuItem<BucketMenu>(
                        value: BucketMenu.done,
                        child: Row(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all,
                                color: bucket.isDoneBucket ? Colors.green : null,
                              ),
                            ),
                            Text('Done Bucket'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<BucketMenu>(
                        value: BucketMenu.delete,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverBucketList(
                bucket: bucket,
              ),
            ),
            SliverVisibility(
              visible: !_bucketProps[bucket.id].scrollable,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: addTaskButton,
                ),
              ),
            ),
          ],
        ),
        if (_bucketProps[bucket.id].scrollable) Align(
          alignment: Alignment.bottomCenter,
          child: addTaskButton,
        ),
      ],
    );
  }

  Future<void> updateDisplayDoneTasks() {
    return VikunjaGlobal.of(context).listService.getDisplayDoneTasks(_list.id)
        .then((value) {displayDoneTasks = value == "1";});
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
    updateDisplayDoneTasks().then((value) async {
      switch (_viewIndex) {
        case 0:
          _loadTasksForPage(1);
          break;
        case 1:
          await _loadBucketsForPage(1);
          // load all buckets to get length for RecordableListView
          while (_currentPage < taskState.maxPages) {
            _currentPage++;
            await _loadBucketsForPage(_currentPage);
          }
          break;
        default:
          _loadTasksForPage(1);
      }
    });
  }

  void _loadTasksForPage(int page) {
    Provider.of<ListProvider>(context, listen: false).loadTasks(
      context: context,
      listId: _list.id,
      page: page,
      displayDoneTasks: displayDoneTasks ?? false
    );
  }

  Future<void> _loadBucketsForPage(int page) {
    return Provider.of<ListProvider>(context, listen: false).loadBuckets(
      context: context,
      listId: _list.id,
      page: page
    );
  }

  _addItemDialog(BuildContext context, [Bucket bucket]) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addItem(title, context, bucket),
        decoration: InputDecoration(
          labelText: (bucket != null ? '${bucket.title}: ' : '') + 'New Task Name',
          hintText: 'eg. Milk',
        ),
      ),
    );
  }

  _addItem(String title, BuildContext context, [Bucket bucket]) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
      id: null,
      title: title,
      createdBy: globalState.currentUser,
      done: false,
      bucketId: bucket?.id,
    );
    setState(() => _loadingTasks.add(newTask));
    Provider.of<ListProvider>(context, listen: false)
        .addTask(
      context: context,
      newTask: newTask,
      listId: _list.id,
    )
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully' + (bucket != null ? ' to ${bucket.title}' : '') + '!'),
      ));
      setState(() {
        _loadingTasks.remove(newTask);
      });
    });
  }

  _addBucketDialog(BuildContext context) {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addBucket(title, context),
        decoration: InputDecoration(
          labelText: 'New Bucket Name',
          hintText: 'eg. To Do',
        ),
      )
    );
  }

  _addBucket(String title, BuildContext context) {
    Provider.of<ListProvider>(context, listen: false).addBucket(
      context: context,
      newBucket: Bucket(
        id: null,
        title: title,
        createdBy: VikunjaGlobal.of(context).currentUser,
        listId: _list.id,
      ),
      listId: _list.id,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The bucket was added successfully!'),
      ));
      setState(() {});
    });
  }

  _updateBucket(BuildContext context, Bucket bucket) async {
    await Provider.of<ListProvider>(context, listen: false).updateBucket(
      context: context,
      bucket: bucket,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${bucket.title} bucket updated successfully!'),
      ));
      setState(() {});
    });
  }

  _deleteBucket(BuildContext context, Bucket bucket) {
    if ((bucket.tasks?.length ?? 0) > 0) {
      int defaultBucketId = taskState.buckets[0]?.id ?? 100;
      taskState.buckets.forEach((b) {
        if (b.id < defaultBucketId)
          defaultBucketId = b.id;
      });
      final defaultBucketIndex = taskState.buckets.indexWhere((b) => b.id == defaultBucketId);
      bucket.tasks.forEach((task) {
        taskState.buckets[defaultBucketIndex].tasks.add(task.copyWith(
          bucketId: defaultBucketId,
          kanbanPosition: taskState.buckets[defaultBucketIndex].tasks.last.kanbanPosition + 1.0,
        ));
      });
    }
    Provider.of<ListProvider>(context, listen: false).deleteBucket(
      context: context,
      listId: bucket.listId,
      bucketId: bucket.id,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: <Widget>[
            Text('${bucket.title} was deleted.'),
            Icon(Icons.delete),
          ],
        ),
      ));
      setState(() {});
    });
  }
}
