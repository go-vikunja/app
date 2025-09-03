import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_task_item.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/task_drag_target.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/task_feedback.dart';

class TaskList extends StatefulWidget {
  final Project project;
  final Bucket bucket;
  final List<Bucket> buckets;
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

  const TaskList({
    super.key,
    required this.project,
    required this.bucket,
    required this.buckets,
    required this.onMoveTask,
    required this.onAnyDragStarted,
    required this.onAnyDragEnded,
    required this.onAnyDragUpdate,
  });

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  bool _dragActive = false;
  Offset? _lastGlobalDragPos;
  Timer? _autoScrollTimer;

  static const double _edgePx = 56; // top/bottom edge zone
  static const double _maxStep = 22;
  static const Duration _tick = Duration(milliseconds: 16);

  void _startAutoScroll() {
    if (_dragActive) return;
    _dragActive = true;
    _autoScrollTimer ??= Timer.periodic(_tick, (_) => _autoScrollStep());
  }

  void _stopAutoScroll() {
    _dragActive = false;
    _lastGlobalDragPos = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onDragUpdate(Offset globalPos) {
    _lastGlobalDragPos = globalPos;
  }

  void _autoScrollStep() {
    if (!_dragActive ||
        _lastGlobalDragPos == null ||
        !_scrollController.hasClients) return;

    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final local = box.globalToLocal(_lastGlobalDragPos!);
    final size = box.size;

    if (local.dx < -80 ||
        local.dx > size.width + 80 ||
        local.dy < -80 ||
        local.dy > size.height + 80) {
      return;
    }

    double dy = 0;
    if (local.dy <= _edgePx) {
      final t = (1 - (local.dy / _edgePx)).clamp(0.0, 1.0);
      dy = -_maxStep * t;
    } else if (local.dy >= size.height - _edgePx) {
      final t =
          ((local.dy - (size.height - _edgePx)) / _edgePx).clamp(0.0, 1.0);
      dy = _maxStep * t;
    }

    if (dy.abs() > 0.1) {
      final next = (_scrollController.position.pixels + dy).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent);
      if (next != _scrollController.position.pixels) {
        _scrollController.jumpTo(next);
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.bucket.tasks;

    return Scrollbar(
      controller: _scrollController,
      child: Container(
        key: _listKey,
        child: ListView(
          controller: _scrollController,
          primary: false,
          shrinkWrap: false,
          physics: const ClampingScrollPhysics(),
          children: [
            TaskDragTarget(
              onAccept: (drag) => widget.onMoveTask(
                project: widget.project,
                buckets: widget.buckets,
                fromBucketId: drag.fromBucketId,
                fromIndex: drag.fromIndex,
                toBucketId: widget.bucket.id,
                toIndex: 0,
              ),
              stopAutoScroll: () {
                _stopAutoScroll();
                widget.onAnyDragEnded();
              },
            ),
            for (int i = 0; i < tasks.length; i++) ...[
              LongPressDraggable<TaskDrag>(
                data: TaskDrag(
                    taskId: tasks[i].id,
                    fromBucketId: widget.bucket.id,
                    fromIndex: i),
                feedback: TaskFeedback(title: tasks[i].title),
                onDragStarted: () {
                  widget.onAnyDragStarted(); // horizontal
                  _startAutoScroll(); // vertical
                },
                onDragUpdate: (details) {
                  widget.onAnyDragUpdate(details.globalPosition);
                  _onDragUpdate(details.globalPosition);
                },
                onDragCompleted: () {
                  _stopAutoScroll();
                  widget.onAnyDragEnded();
                },
                onDraggableCanceled: (_, __) {
                  _stopAutoScroll();
                  widget.onAnyDragEnded();
                },
                onDragEnd: (_) {
                  _stopAutoScroll();
                  widget.onAnyDragEnded();
                },
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: TaskTile(task: tasks[i]),
                ),
                child: InkWell(
                  child: TaskTile(task: tasks[i]),
                  onTap: () {
                    _navigateToTask(context, tasks, i);
                  },
                ),
              ),
              TaskDragTarget(
                onAccept: (drag) => widget.onMoveTask(
                  project: widget.project,
                  buckets: widget.buckets,
                  fromBucketId: drag.fromBucketId,
                  fromIndex: drag.fromIndex,
                  toBucketId: widget.bucket.id,
                  toIndex: i + 1,
                ),
                stopAutoScroll: () {
                  _stopAutoScroll();
                  widget.onAnyDragEnded();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToTask(BuildContext context, List<Task> tasks, int i) {
    Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditPage(
          task: tasks[i],
        ),
      ),
    );
  }
}
