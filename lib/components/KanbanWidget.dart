import 'dart:ui';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../global.dart';
import '../models/bucket.dart';
import '../models/project.dart';
import '../models/view.dart';
import '../pages/project/project_task_list.dart';
import '../stores/project_store.dart';
import '../utils/calculate_item_position.dart';
import 'AddDialog.dart';
import 'BucketLimitDialog.dart';
import 'BucketTaskCard.dart';
import 'SliverBucketList.dart';
import 'SliverBucketPersistentHeader.dart';

class KanbanClass {
  PageController? _pageController;
  ProjectProvider? taskState;
  int? _draggedBucketIndex;
  BuildContext context;
  Function _onViewTapped, _addItemDialog, notify;
  Duration _lastTaskDragUpdateAction = Duration.zero;

  Project _project;
  ProjectView _view;

  set view(ProjectView view) {
    _view = view;
  }

  Map<int, BucketProps> _bucketProps = {};

  KanbanClass(this.context, this.notify, this._onViewTapped,
      this._addItemDialog, this._project, this._view) {
    taskState = Provider.of<ProjectProvider>(context);
  }

  Widget kanbanView() {
    final deviceData = MediaQuery.of(context);
    final portrait = deviceData.orientation == Orientation.portrait;
    final bucketFraction = portrait ? 0.8 : 0.4;
    final bucketWidth = deviceData.size.width * bucketFraction;

    if (_pageController == null ||
        _pageController!.viewportFraction != bucketFraction)
      _pageController = PageController(viewportFraction: bucketFraction);

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      scrollController: _pageController,
      physics: PageScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: taskState?.buckets.length ?? 0,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (index > (taskState!.buckets.length))
          throw Exception("Check itemCount attribute");
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
              scale: lerpDouble(
                  1.0, 0.75, Curves.easeInOut.transform(animation.value)),
              child: child,
            );
          },
        );
      },
      footer: _draggedBucketIndex != null
          ? null
          : SizedBox(
              width: deviceData.size.width *
                  (1 - bucketFraction) *
                  (portrait ? 1 : 2),
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
        _draggedBucketIndex = oldIndex;
        notify();
        // setState(() => _draggedBucketIndex = oldIndex);
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
          positionBefore:
              newIndex != 0 ? taskState!.buckets[newIndex - 1].position : null,
          positionAfter: newIndex < taskState!.buckets.length - 1
              ? taskState!.buckets[newIndex + 1].position
              : null,
        );
        await _updateBucket(context, taskState!.buckets[newIndex]);

        // make sure the first 2 buckets don't have 0 position
        if (newIndex == 0 &&
            taskState!.buckets.length > 1 &&
            taskState!.buckets[1].position == 0) {
          taskState!.buckets[1].position = calculateItemPosition(
            positionBefore: taskState!.buckets[0].position,
            positionAfter: 1 < taskState!.buckets.length - 1
                ? taskState!.buckets[2].position
                : null,
          );
          _updateBucket(context, taskState!.buckets[1]);
        }

        if (indexUpdated && portrait)
          _pageController!.animateToPage(
            newIndex - 1,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeInOut,
          );
        _draggedBucketIndex = null;
        notify();
        // setState(() => _draggedBucketIndex = null);
      },
    );
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
            ));
  }

  Future<void> _setDoneBucket(BuildContext context, int bucketId) async {
    //setState(() {});
    _view = (await VikunjaGlobal.of(context)
        .projectViewService
        .update(_view.copyWith(doneBucketId: bucketId)))!;
    notify();
  }

  Future<void> _addBucket(String title, BuildContext context) async {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    await Provider.of<ProjectProvider>(context, listen: false).addBucket(
      context: context,
      newBucket: Bucket(
        title: title,
        createdBy: currentUser,
        projectViewId: _view.id,
        limit: 0,
      ),
      listId: _project.id,
      viewId: _view.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('The bucket was added successfully!'),
    ));
    notify();
    //setState(() {});
  }

  Future<void> _updateBucket(BuildContext context, Bucket bucket) {
    return Provider.of<ProjectProvider>(context, listen: false)
        .updateBucket(
            context: context,
            bucket: bucket,
            listId: _project.id,
            viewId: _view.id)
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('\'${bucket.title}\' bucket updated successfully!'),
      ));
      notify();
      //setState(() {});
    });
  }

  Future<void> _deleteBucket(BuildContext context, Bucket bucket) async {
    await Provider.of<ProjectProvider>(context, listen: false).deleteBucket(
      context: context,
      listId: _project.id,
      viewId: _view.id,
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
    if (_bucketProps[bucket.id]!.bucketLength != (bucket.tasks.length) ||
        _bucketProps[bucket.id]!.portrait != portrait)
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_bucketProps[bucket.id]!.controller.hasClients)
          //setState(() {
          _bucketProps[bucket.id]!.bucketLength = bucket.tasks.length;
        _bucketProps[bucket.id]!.scrollable =
            _bucketProps[bucket.id]!.controller.position.maxScrollExtent > 0;
        _bucketProps[bucket.id]!.portrait = portrait;
        //});
        notify();
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
                  leading: bucket.id == _view.doneBucketId
                      ? Icon(
                          Icons.done_all,
                          color: Colors.green,
                        )
                      : null,
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
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
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
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Text(
                            '${bucket.tasks.length}/${bucket.limit}',
                            style: (theme.textTheme.titleMedium ??
                                    TextStyle(fontSize: 16))
                                .copyWith(
                              color: bucket.limit != 0 &&
                                      bucket.tasks.length >= bucket.limit
                                  ? Colors.red
                                  : null,
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
                              showDialog<int>(
                                context: context,
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
                              _project =
                                  _project.copyWith(doneBucketId: bucket.id);
                              _setDoneBucket(context, bucket.id);
                              notify();
                              //_updateBucket(context, bucket);
                              break;
                            case BucketMenu.delete:
                              _deleteBucket(context, bucket);
                          }
                        },
                        itemBuilder: (context) {
                          final bool enableDelete =
                              taskState!.buckets.length > 1;
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
                                      color: bucket.id == _view.doneBucketId
                                          ? Colors.green
                                          : null,
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
                                    style: enableDelete
                                        ? TextStyle(color: Colors.red)
                                        : null,
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
                  onTaskDragUpdate: (details) {
                    // scroll when dragging a task
                    if (details.sourceTimeStamp! - _lastTaskDragUpdateAction >
                        const Duration(milliseconds: 600)) {
                      final screenSize = MediaQuery.of(context).size;
                      const scrollDuration = Duration(milliseconds: 250);
                      const scrollCurve = Curves.easeInOut;
                      final updateAction = () {
                        //setState(() =>
                        _lastTaskDragUpdateAction = details.sourceTimeStamp!;
                        notify();
                      }; //);

                      if (details.globalPosition.dx < screenSize.width * 0.1) {
                        // scroll left
                        if (_pageController!.position.extentBefore != 0)
                          _pageController!.previousPage(
                              duration: scrollDuration, curve: scrollCurve);
                        updateAction();
                      } else if (details.globalPosition.dx >
                          screenSize.width * 0.9) {
                        // scroll right
                        if (_pageController!.position.extentAfter != 0)
                          _pageController!.nextPage(
                              duration: scrollDuration, curve: scrollCurve);
                        updateAction();
                      } else {
                        final viewingBucket =
                            taskState!.buckets[_pageController!.page!.floor()];
                        final bucketController =
                            _bucketProps[viewingBucket.id]!.controller;
                        if (details.globalPosition.dy <
                            screenSize.height * 0.2) {
                          // scroll up
                          if (bucketController.position.extentBefore != 0)
                            bucketController.animateTo(
                                bucketController.offset - 80,
                                duration: scrollDuration,
                                curve: scrollCurve);
                          updateAction();
                        } else if (details.globalPosition.dy >
                            screenSize.height * 0.8) {
                          // scroll down
                          if (bucketController.position.extentAfter != 0)
                            bucketController.animateTo(
                                bucketController.offset + 80,
                                duration: scrollDuration,
                                curve: scrollCurve);
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
                        if (_bucketProps[bucket.id]!.taskDropSize != null)
                          DottedBorder(
                            color: Colors.grey,
                            child: SizedBox.fromSize(
                                size: _bucketProps[bucket.id]!.taskDropSize),
                          ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: addTaskButton,
                        ),
                      ],
                    ),
                    // DragTarget to drop tasks in empty buckets
                    if (bucket.tasks.length == 0)
                      DragTarget<TaskData>(
                        onWillAcceptWithDetails: (data) {
                          /*setState(() =>*/ _bucketProps[bucket.id]!
                              .taskDropSize = data.data.size; //);
                          notify();
                          return true;
                        },
                        onAcceptWithDetails: (data) {
                          Provider.of<ProjectProvider>(context, listen: false)
                              .moveTaskToBucket(
                                context: context,
                                task: data.data.task,
                                newBucketId: bucket.id,
                                index: 0,
                              )
                              .then((_) => ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        '\'${data.data.task.title}\' was moved to \'${bucket.title}\' successfully!'),
                                  )));

                          //setState(() =>
                          _bucketProps[bucket.id]!.taskDropSize = null; //);
                          notify();
                        },
                        onLeave: (_) {
                          //setState(() =>
                          _bucketProps[bucket.id]!.taskDropSize = null; //)
                          notify();
                        },
                        builder: (_, __, ___) => SizedBox.expand(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_bucketProps[bucket.id]!.scrollable)
          Align(
            alignment: Alignment.bottomCenter,
            child: addTaskButton,
          ),
      ],
    );
  }

  Future<void> loadBucketsForPage(int page) {
    print(_view.id);
    return Provider.of<ProjectProvider>(context, listen: false).loadBuckets(
        context: context, listId: _project.id, viewId: _view.id, page: page);
  }
}
