import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/widgets/BucketLimitDialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_delete_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_feedback.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_header.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/change_title_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_task_list.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

class BucketColumn extends ConsumerStatefulWidget {
  final Project project;
  final bool isDoneColumn;
  final bool isDefaultColumn;
  final Bucket bucket;
  final List<Bucket> buckets;
  final int bucketIndex;
  final void Function({
    required Project project,
    required List<Bucket> buckets,
    required int fromBucketId,
    required int fromIndex,
    required int toBucketId,
    required int toIndex,
  }) onMoveTask;

  final VoidCallback onAnyDragStarted;
  final VoidCallback onAnyDragEnded;
  final void Function(Offset globalPos) onAnyDragUpdate;

  const BucketColumn({
    super.key,
    required this.project,
    required this.isDoneColumn,
    required this.isDefaultColumn,
    required this.bucket,
    required this.buckets,
    required this.bucketIndex,
    required this.onMoveTask,
    required this.onAnyDragStarted,
    required this.onAnyDragEnded,
    required this.onAnyDragUpdate,
  });

  @override
  ConsumerState<BucketColumn> createState() => _BucketColumnState();
}

class _BucketColumnState extends ConsumerState<BucketColumn> {
  bool _isTaskHovering = false;
  bool _isHeaderDragging = false;
  bool _isCollapsed = false;

  void _safeSet(void Function() fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final columnBody = Column(
      children: [
        LongPressDraggable<BucketDrag>(
          data: BucketDrag(
              bucketId: widget.bucket.id, fromIndex: widget.bucketIndex),
          feedback: BucketFeedback(bucket: widget.bucket),
          onDragStarted: () {
            _safeSet(() => _isHeaderDragging = true);
            widget.onAnyDragStarted();
          },
          onDragUpdate: (d) => widget.onAnyDragUpdate(d.globalPosition),
          onDragCompleted: () {
            _safeSet(() => _isHeaderDragging = false);
            widget.onAnyDragEnded();
          },
          onDraggableCanceled: (_, __) {
            _safeSet(() => _isHeaderDragging = false);
            widget.onAnyDragEnded();
          },
          onDragEnd: (_) {
            _safeSet(() => _isHeaderDragging = false);
            widget.onAnyDragEnded();
          },
          child: _buildBucketHeader(context),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DragTarget<TaskDrag>(
            onMove: (_) => _safeSet(() => _isTaskHovering = true),
            onLeave: (_) => _safeSet(() => _isTaskHovering = false),
            onAcceptWithDetails: (details) {
              widget.onAnyDragEnded(); // stop horizontal auto-scroll
              widget.onMoveTask(
                project: widget.project,
                buckets: widget.buckets,
                fromBucketId: details.data.fromBucketId,
                fromIndex: details.data.fromIndex,
                toBucketId: widget.bucket.id,
                toIndex: -1,
              );
              _safeSet(() => _isTaskHovering = false);
            },
            builder: (context, candidate, rejected) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isTaskHovering
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: TaskList(
                  project: widget.project,
                  bucket: widget.bucket,
                  buckets: widget.buckets,
                  onMoveTask: widget.onMoveTask,
                  onAnyDragStarted: widget.onAnyDragStarted,
                  onAnyDragEnded: widget.onAnyDragEnded,
                  onAnyDragUpdate: widget.onAnyDragUpdate,
                ),
              );
            },
          ),
        ),
      ],
    );

    if (_isCollapsed) {
      return _buildCollapsedColumn();
    } else {
      return Opacity(
        opacity: _isHeaderDragging ? 0.35 : 1.0,
        child: SizedBox(
          width: KanbanWidgetState.bucketWidth,
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            elevation: 0.5,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: columnBody),
          ),
        ),
      );
    }
  }

  Column _buildCollapsedColumn() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: RotatedBox(
              quarterTurns: 1,
              child: InkWell(
                child: Text(widget.bucket.title),
                onTap: () {
                  setState(() {
                    _isCollapsed = false;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  BucketHeader _buildBucketHeader(BuildContext context) {
    return BucketHeader(
      widget.bucket,
      widget.isDoneColumn,
      widget.isDefaultColumn,
      (action) async {
        switch (action) {
          case HeaderAction.changeTitle:
            await _showChangeTitleDialog(context);
            break;
          case HeaderAction.setLimit:
            await _showSetLimitDialog(context);
            break;
          case HeaderAction.doneColumn:
            ref
                .read(projectControllerProvider(widget.project).notifier)
                .updateDoneBucket(
                    widget.project, widget.bucket.id, widget.isDoneColumn);
            break;
          case HeaderAction.defaultColumn:
            ref
                .read(projectControllerProvider(widget.project).notifier)
                .selectDefaultBucket(
                    widget.project, widget.bucket.id, widget.isDefaultColumn);
            break;
          case HeaderAction.collapseColumn:
            setState(() {
              _isCollapsed = true;
            });
            break;
          case HeaderAction.deleteColumn:
            _showDeleteColumnDialog(context);
            break;
          case HeaderAction.addTask:
            _addItemDialog(context);
            break;
        }
      },
    );
  }

  Future<void> _showChangeTitleDialog(BuildContext context) async {
    var result = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return ChangeTitleDialog(
          bucket: widget.bucket,
        );
      },
    );

    if (result != null) {
      widget.bucket.title = result;
      ref
          .read(projectControllerProvider(widget.project).notifier)
          .updateBucket(bucket: widget.bucket, project: widget.project);
    }
  }

  Future<void> _showSetLimitDialog(BuildContext context) async {
    var result = await showDialog<int?>(
      context: context,
      builder: (BuildContext context) {
        return BucketLimitDialog(
          bucket: widget.bucket,
        );
      },
    );

    if (result != null) {
      widget.bucket.limit = result;
      ref
          .read(projectControllerProvider(widget.project).notifier)
          .updateBucket(bucket: widget.bucket, project: widget.project);
    }
  }

  void _showDeleteColumnDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskDeleteDialog(
          onConfirm: () {
            ref
                .read(projectControllerProvider(widget.project).notifier)
                .deleteBucket(bucket: widget.bucket, project: widget.project);
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _addItemDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) => _addItem(title, context),
      ),
    );
  }

  Future<void> _addItem(String title, BuildContext context) async {
    //TODO injection
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    final newTask = Task(
      title: title,
      bucketId: widget.bucket.id,
      createdBy: currentUser,
      done: false,
      projectId: widget.project.id,
    );

    await ref
        .read(projectControllerProvider(widget.project).notifier)
        .addTask(widget.project, newTask);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was added successfully!'),
      ));
    }
  }
}
