import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/TaskTile.dart';
import 'package:vikunja_app/components/SliverBucketList.dart';
import 'package:vikunja_app/components/SliverBucketPersistentHeader.dart';
import 'package:vikunja_app/components/BucketLimitDialog.dart';
import 'package:vikunja_app/components/BucketTaskCard.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/bucket.dart';
import 'package:vikunja_app/pages/list/list_edit.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';
import 'package:vikunja_app/utils/calculate_item_position.dart';

enum BucketMenu {limit, done, delete}

class BucketProps {
  final ScrollController controller = ScrollController();
  final TextEditingController titleController = TextEditingController();
  bool scrollable = false;
  bool portrait = true;
  int bucketLength = 0;
  Size? taskDropSize;
}

class ListPage extends StatefulWidget {
  final TaskList taskList;

  //ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));
  ListPage({required this.taskList}) : super(key: Key(Random().nextInt(100000).toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _keyboardController = KeyboardVisibilityController();
  int _viewIndex = 0;
  TaskList? _list;
  List<Task> _loadingTasks = [];
  int _currentPage = 1;
  bool _loading = true;
  bool displayDoneTasks = false;
  ListProvider? taskState;
  PageController? _pageController;
  Map<int, BucketProps> _bucketProps = {};
  int? _draggedBucketIndex;
  Duration _lastTaskDragUpdateAction = Duration.zero;

  @override
  void initState() {
    _list = widget.taskList;
    _keyboardController.onChange.listen((visible) {
      if (!visible && mounted) FocusScope.of(context).unfocus();
    });
    super.initState();
    Future.delayed(Duration.zero, (){
      _loadList();
    });
  }

  @override
  Widget build(BuildContext context) {
    taskState = Provider.of<ListProvider>(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_list?.title ?? ""),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListEditPage(
                      list: _list!,
                    ),
                  )).whenComplete(() => _loadList()),
            ),
          ],
        ),
        // TODO: it brakes the flow with _loadingTasks and conflicts with the provider
        body: !taskState!.isLoading
            ? RefreshIndicator(
                child: taskState!.tasks.length > 0 || taskState!.buckets.length > 0
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
      itemCount: taskState!.tasks.length * 2,
      itemBuilder: (context, i) {
        if (i.isOdd) return Divider();

        if (_loadingTasks.isNotEmpty) {
          final loadingTask = _loadingTasks.removeLast();
          return _buildLoadingTile(loadingTask);
        }

        final index = i ~/ 2;

        if (taskState!.maxPages == _currentPage &&
            index == taskState!.tasks.length)
          throw Exception("Check itemCount attribute");

        if (index >= taskState!.tasks.length &&
            _currentPage < taskState!.maxPages) {
          _currentPage++;
          _loadTasksForPage(_currentPage);
        }
        return _buildTile(taskState!.tasks[index]);

      }
    );
  }

  Widget _kanbanView(BuildContext context) {
    final deviceData = MediaQuery.of(context);
    final portrait = deviceData.orientation == Orientation.portrait;
    final bucketFraction = portrait ?  0.8 : 0.4;
    final bucketWidth = deviceData.size.width * bucketFraction;

    if (_pageController == null) _pageController = PageController(viewportFraction: bucketFraction);
    else if (_pageController!.viewportFraction != bucketFraction)
      _pageController = PageController(viewportFraction: bucketFraction);

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      scrollController: _pageController,
      physics: PageScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: taskState?.buckets.length ?? 0,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (index > (taskState!.buckets.length)) throw Exception("Check itemCount attribute");
        return ReorderableDelayedDragStartListener(
          key: ValueKey<int>(index),
          index: index,
          enabled: taskState!.buckets.length > 1 && !taskState!.taskDragging,
          child: SizedBox(
            width: bucketWidth,
            child: _buildBucketTile(taskState!.buckets[index], portrait),
          ),
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
        width: deviceData.size.width * (1 - bucketFraction) * (portrait ? 1 : 2),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(
              top: portrait ? 14 : 5,
            ),
            child: RotatedBox(
              quarterTurns: portrait ? 1 : 0,
              child: ElevatedButton.icon(
                onPressed: () => _addBucketDialog(context),
                label: Text('Create Bucket'),
                icon: Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
      onReorderStart: (oldIndex) {
        FocusScope.of(context).unfocus();
        setState(() => _draggedBucketIndex = oldIndex);
      },
      onReorder: (_, __) {},
      onReorderEnd: (newIndex) async {
        bool indexUpdated = false;
        if (newIndex > _draggedBucketIndex!) {
          newIndex -= 1;
          indexUpdated = true;
        }

        final movedBucket = taskState!.buckets.removeAt(_draggedBucketIndex!);
        if (newIndex >= taskState!.buckets.length) {
          taskState!.buckets.add(movedBucket);
        } else {
          taskState!.buckets.insert(newIndex, movedBucket);
        }

        taskState!.buckets[newIndex].position = calculateItemPosition(
          positionBefore: newIndex != 0
              ? taskState!.buckets[newIndex - 1].position : null,
          positionAfter: newIndex < taskState!.buckets.length - 1
              ? taskState!.buckets[newIndex + 1].position : null,
        );
        await _updateBucket(context, taskState!.buckets[newIndex]);

        // make sure the first 2 buckets don't have 0 position
        if (newIndex == 0 && taskState!.buckets.length > 1 && taskState!.buckets[1].position == 0) {
          taskState!.buckets[1].position = calculateItemPosition(
            positionBefore: taskState!.buckets[0].position,
            positionAfter: 1 < taskState!.buckets.length - 1
                ? taskState!.buckets[2].position : null,
          );
          _updateBucket(context, taskState!.buckets[1]);
        }

        if (indexUpdated && portrait) _pageController!.animateToPage(
          newIndex - 1,
          duration: Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );

        setState(() => _draggedBucketIndex = null);
      },
    );
  }

  Widget _buildTile(Task task) {
    return ListenableProvider.value(
      value: taskState,
      child: TaskTile(
        task: task,
        loading: false,
        onEdit: () {},
        onMarkedAsDone: (done) {
          Provider.of<ListProvider>(context, listen: false).updateTask(
            context: context,
            task: task.copyWith(done: done),
          );
        },
      ),
    );
  }

  Widget _buildBucketTile(Bucket bucket, bool portrait) {
    final theme = Theme.of(context);
    const bucketTitleHeight = 56.0;
    final addTaskButton = ElevatedButton.icon(
      icon: Icon(Icons.add),
      label: Text('Add Task'),
      onPressed: bucket.limit == 0 || bucket.tasks.length < bucket.limit
          ? () {
              FocusScope.of(context).unfocus();
              _addItemDialog(context, bucket);
            }
          : null,
    );

    if (_bucketProps[bucket.id] == null)
      _bucketProps[bucket.id] = BucketProps();
    if (_bucketProps[bucket.id]!.bucketLength != (bucket.tasks.length)
        || _bucketProps[bucket.id]!.portrait != portrait)
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_bucketProps[bucket.id]!.controller.hasClients) setState(() {
          _bucketProps[bucket.id]!.bucketLength = bucket.tasks.length;
          _bucketProps[bucket.id]!.scrollable = _bucketProps[bucket.id]!.controller.position.maxScrollExtent > 0;
          _bucketProps[bucket.id]!.portrait = portrait;
        });
      });
    if (_bucketProps[bucket.id]!.titleController.text.isEmpty)
      _bucketProps[bucket.id]!.titleController.text = bucket.title;

    return Stack(
      children: <Widget>[
        CustomScrollView(
          controller: _bucketProps[bucket.id]!.controller,
          slivers: <Widget>[
            SliverBucketPersistentHeader(
              minExtent: bucketTitleHeight,
              maxExtent: bucketTitleHeight,
              child: Material(
                color: theme.scaffoldBackgroundColor,
                child: ListTile(
                  minLeadingWidth: 15,
                  horizontalTitleGap: 4,
                  contentPadding: const EdgeInsets.only(left: 16, right: 10),
                  leading: bucket.isDoneBucket ? Icon(
                    Icons.done_all,
                    color: Colors.green,
                  ) : null,
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _bucketProps[bucket.id]!.titleController,
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
                      if (bucket.limit != 0) Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(
                          '${bucket.tasks.length}/${bucket.limit}',
                          style: (theme.textTheme.titleMedium ?? TextStyle(fontSize: 16)).copyWith(
                            color: bucket.limit != 0 && bucket.tasks.length >= bucket.limit
                                ? Colors.red : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.drag_handle),
                      PopupMenuButton<BucketMenu>(
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
                        itemBuilder: (context) {
                          final bool enableDelete = taskState!.buckets.length > 1;
                          return <PopupMenuEntry<BucketMenu>>[
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
                              enabled: enableDelete,
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.delete,
                                    color: enableDelete ? Colors.red : null,
                                  ),
                                  Text(
                                    'Delete',
                                    style: enableDelete ? TextStyle(color: Colors.red) : null,
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: ListenableProvider.value(
                value: taskState,
                child: SliverBucketList(
                  bucket: bucket,
                  onTaskDragUpdate: (details) { // scroll when dragging a task
                    if (details.sourceTimeStamp! - _lastTaskDragUpdateAction > const Duration(milliseconds: 600)) {
                      final screenSize = MediaQuery.of(context).size;
                      const scrollDuration = Duration(milliseconds: 250);
                      const scrollCurve = Curves.easeInOut;
                      final updateAction = () => setState(() => _lastTaskDragUpdateAction = details.sourceTimeStamp!);
                      if (details.globalPosition.dx < screenSize.width * 0.1) { // scroll left
                        if (_pageController!.position.extentBefore != 0)
                          _pageController!.previousPage(duration: scrollDuration, curve: scrollCurve);
                        updateAction();
                      } else if (details.globalPosition.dx > screenSize.width * 0.9) { // scroll right
                        if (_pageController!.position.extentAfter != 0)
                          _pageController!.nextPage(duration: scrollDuration, curve: scrollCurve);
                        updateAction();
                      } else {
                        final viewingBucket = taskState!.buckets[_pageController!.page!.floor()];
                        final bucketController = _bucketProps[viewingBucket.id]!.controller;
                        if (details.globalPosition.dy < screenSize.height * 0.2) { // scroll up
                          if (bucketController.position.extentBefore != 0)
                            bucketController.animateTo(bucketController.offset - 80,
                                duration: scrollDuration, curve: scrollCurve);
                          updateAction();
                        } else if (details.globalPosition.dy > screenSize.height * 0.8) { // scroll down
                          if (bucketController.position.extentAfter != 0)
                            bucketController.animateTo(bucketController.offset + 80,
                                duration: scrollDuration, curve: scrollCurve);
                          updateAction();
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            SliverVisibility(
              visible: !_bucketProps[bucket.id]!.scrollable,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        if (_bucketProps[bucket.id]!.taskDropSize != null) DottedBorder(
                          color: Colors.grey,
                          child: SizedBox.fromSize(size: _bucketProps[bucket.id]!.taskDropSize),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: addTaskButton,
                        ),
                      ],
                    ),
                    // DragTarget to drop tasks in empty buckets
                    if (bucket.tasks.length == 0) DragTarget<TaskData>(
                      onWillAccept: (data) {
                        setState(() => _bucketProps[bucket.id]!.taskDropSize = data?.size);
                        return true;
                      },
                      onAccept: (data) {
                        Provider.of<ListProvider>(context, listen: false).moveTaskToBucket(
                          context: context,
                          task: data.task,
                          newBucketId: bucket.id,
                          index: 0,
                        ).then((_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('\'${data.task.title}\' was moved to \'${bucket.title}\' successfully!'),
                        )));
                        setState(() => _bucketProps[bucket.id]!.taskDropSize = null);
                      },
                      onLeave: (_) => setState(() => _bucketProps[bucket.id]!.taskDropSize = null),
                      builder: (_, __, ___) => SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_bucketProps[bucket.id]!.scrollable) Align(
          alignment: Alignment.bottomCenter,
          child: addTaskButton,
        ),
      ],
    );
  }

  Future<void> updateDisplayDoneTasks() {
    return VikunjaGlobal.of(context).listService.getDisplayDoneTasks(_list!.id)
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
            taskState: taskState!,
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
          while (_currentPage < taskState!.maxPages) {
            _currentPage++;
            await _loadBucketsForPage(_currentPage);
          }
          break;
        default:
          _loadTasksForPage(1);
      }
    });
  }

  Future<void> _loadTasksForPage(int page) {
    return Provider.of<ListProvider>(context, listen: false).loadTasks(
      context: context,
      listId: _list!.id,
      page: page,
      displayDoneTasks: displayDoneTasks
    );
  }

  Future<void> _loadBucketsForPage(int page) {
    return Provider.of<ListProvider>(context, listen: false).loadBuckets(
      context: context,
      listId: _list!.id,
      page: page
    );
  }

  Future<void> _addItemDialog(BuildContext context, [Bucket? bucket]) {
    return showDialog(
      context: context,
      builder: (_) => AddDialog(
        onAdd: (title) => _addItem(title, context, bucket),
        decoration: InputDecoration(
          labelText: (bucket != null ? '\'${bucket.title}\': ' : '') + 'New Task Name',
          hintText: 'eg. Milk',
        ),
      ),
    );
  }

  Future<void> _addItem(String title, BuildContext context, [Bucket? bucket]) async {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    final newTask = Task(
      title: title,
      createdBy: currentUser,
      done: false,
      bucketId: bucket?.id,
      listId: _list!.id,
    );
    setState(() => _loadingTasks.add(newTask));
    return Provider.of<ListProvider>(context, listen: false)
        .addTask(
      context: context,
      newTask: newTask,
      listId: _list!.id,
    )
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully' + (bucket != null ? ' to \'${bucket.title}\'' : '') + '!'),
      ));
      setState(() {
        _loadingTasks.remove(newTask);
      });
    });
  }

  Future<void> _addBucketDialog(BuildContext context) {
    FocusScope.of(context).unfocus();
    return showDialog(
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

  Future<void> _addBucket(String title, BuildContext context) async {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    await Provider.of<ListProvider>(context, listen: false).addBucket(
      context: context,
      newBucket: Bucket(
        title: title,
        createdBy: currentUser,
        listId: _list!.id,
        limit: 0,
      ),
      listId: _list!.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('The bucket was added successfully!'),
    ));
    setState(() {});
  }

  Future<void> _updateBucket(BuildContext context, Bucket bucket) {
    return Provider.of<ListProvider>(context, listen: false).updateBucket(
      context: context,
      bucket: bucket,
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('\'${bucket.title}\' bucket updated successfully!'),
      ));
      setState(() {});
    });
  }

  Future<void> _deleteBucket(BuildContext context, Bucket bucket) async {
    await Provider.of<ListProvider>(context, listen: false).deleteBucket(
      context: context,
      listId: bucket.listId,
      bucketId: bucket.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: <Widget>[
          Text('\'${bucket.title}\' was deleted.'),
          Icon(Icons.delete),
        ],
      ),
    ));

    _onViewTapped(1);
  }
}
