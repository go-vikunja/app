import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/add_bucket_dialog.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_drag_target.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_item.dart';

class TaskDrag {
  final int taskId;
  final int fromBucketId;
  final int fromIndex;

  TaskDrag({
    required this.taskId,
    required this.fromBucketId,
    required this.fromIndex,
  });
}

class BucketDrag {
  final int bucketId;
  final int fromIndex;

  BucketDrag({required this.bucketId, required this.fromIndex});
}

class KanbanWidget extends ConsumerStatefulWidget {
  final Project project;

  const KanbanWidget({super.key, required this.project});

  @override
  KanbanWidgetState createState() => KanbanWidgetState();
}

class KanbanWidgetState extends ConsumerState<KanbanWidget> {
  static const double bucketWidth = 300;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  bool _dragActive = false;
  Offset? _lastGlobalDragPos;
  Timer? _autoScrollTimer;

  static const double _edgePx = 72; // edge zone width
  static const double _maxStep = 28; // px per tick
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
        !_scrollController.hasClients) {
      return;
    }

    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final local = box.globalToLocal(_lastGlobalDragPos!);
    final size = box.size;

    // Pause if pointer far outside the board
    if (local.dx < -50 ||
        local.dx > size.width + 50 ||
        local.dy < -50 ||
        local.dy > size.height + 50) {
      return;
    }

    double dx = 0;
    if (local.dx <= _edgePx) {
      final t = (1 - (local.dx / _edgePx)).clamp(0.0, 1.0);
      dx = -_maxStep * t;
    } else if (local.dx >= size.width - _edgePx) {
      final t = ((local.dx - (size.width - _edgePx)) / _edgePx).clamp(0.0, 1.0);
      dx = _maxStep * t;
    }

    if (dx.abs() > 0.1) {
      final next = (_scrollController.position.pixels + dx).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
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
    var controller = ref.watch(projectControllerProvider(widget.project));

    return controller.when(
      data: (data) {
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: Container(
            key: _listKey,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              children: [
                BucketDragTarget(
                  index: 0,
                  onAccept: (drag) {
                    _stopAutoScroll(); // ensure timers stop on accept
                    _moveBucket(
                      project: data.project,
                      buckets: data.buckets,
                      from: drag.fromIndex,
                      to: 0,
                    );
                  },
                ),
                for (int i = 0; i < data.buckets.length; i++) ...[
                  BucketColumn(
                    key: ValueKey(data.buckets[i].id),
                    // stable identity on reorder
                    project: data.project,
                    isDoneColumn:
                        data.project.views[data.viewIndex].doneBucketId ==
                        data.buckets[i].id,
                    isDefaultColumn:
                        data.project.views[data.viewIndex].defaultBucketId ==
                        data.buckets[i].id,
                    bucket: data.buckets[i],
                    buckets: data.buckets,
                    bucketIndex: i,
                    onMoveTask: _moveTask,
                    onAnyDragStarted: _startAutoScroll,
                    onAnyDragEnded: _stopAutoScroll,
                    onAnyDragUpdate: _onDragUpdate,
                  ),
                  BucketDragTarget(
                    index: i + 1,
                    onAccept: (drag) {
                      _stopAutoScroll();
                      _moveBucket(
                        project: data.project,
                        buckets: data.buckets,
                        from: drag.fromIndex,
                        to: i + 1,
                      );
                    },
                  ),
                ],
                RotatedBox(
                  quarterTurns: 1,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _addBucketDialog(
                            context,
                            data.project,
                            data.viewIndex,
                          );
                        },
                        child: Text(AppLocalizations.of(context).kanbanAddBucket),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      error: (err, _) => VikunjaErrorWidget(error: err),
      loading: () => const LoadingWidget(),
    );
  }

  Future<void> _addBucketDialog(
    BuildContext context,
    Project project,
    int viewIndex,
  ) {
    FocusScope.of(context).unfocus();
    return showDialog(
      context: context,
      builder: (_) => AddBucketDialog(
        onAdd: (title) => _addBucket(title, context, project, viewIndex),
      ),
    );
  }

  Future<void> _addBucket(
    String title,
    BuildContext context,
    Project project,
    int viewIndex,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    ProjectView view = project.views[viewIndex];

    var bucket = Bucket(
      title: title,
      createdBy: currentUser,
      projectViewId: view.id,
      limit: 0,
    );

    var success = await ref
        .read(projectControllerProvider(project).notifier)
        .addBucket(newBucket: bucket, project: project, viewId: view.id);

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).bucketAddedSuccess)),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).bucketAddError)));
    }
  }

  void _moveBucket({
    required Project project,
    required List<Bucket> buckets,
    required int from,
    required int to,
  }) async {
    if (from == -1 || to == -1 || from == to) return;

    final bucket = buckets.removeAt(from);
    final newIndex = to > from ? max(0, to - 1) : to;
    buckets.insert(newIndex, bucket);

    setState(() {
      var position = calculateItemPosition(
        positionBefore: newIndex == 0 ? null : buckets[newIndex - 1].position,
        positionAfter: newIndex == buckets.length - 1
            ? null
            : buckets[newIndex + 1].position,
      );
      bucket.position = position;
    });

    var success = await ref
        .read(projectControllerProvider(project).notifier)
        .updateBucket(bucket: bucket, project: project);

    var context = this.context;
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).bucketUpdateError)));

      //We need to update the drag immediately for UX reasons -> if it fails afterwards just reload the project
      ref.read(projectControllerProvider(project).notifier).reload();
    }
  }

  void _moveTask({
    required Project project,
    required List<Bucket> buckets,
    required int fromBucketId,
    required int fromIndex,
    required int toBucketId,
    required int toIndex,
  }) {
    setState(() async {
      final fromBucket =
          buckets[buckets.indexWhere((b) => b.id == fromBucketId)];
      final toBucket = buckets[buckets.indexWhere((b) => b.id == toBucketId)];

      if (fromIndex < 0 || fromIndex >= fromBucket.tasks.length) return;

      if (fromBucket == toBucket && toIndex == -1) {
        //No column selected in same bucket - Don't do anything
        return;
      } else if (toIndex == -1) {
        //If dropped to another bucket without selecting position - Put at front
        toIndex == 0;
      }

      final task = fromBucket.tasks.removeAt(fromIndex);
      var toTasks = toBucket.tasks;

      int insertIndex = toIndex.clamp(0, toTasks.length);
      if (fromBucketId == toBucketId && fromIndex < toIndex) {
        insertIndex = max(0, insertIndex - 1);
      }

      toTasks.insert(insertIndex, task);

      var positionBefore = insertIndex == 0
          ? null
          : fromBucket.tasks[insertIndex - 1].position;
      var positionAfter = insertIndex == toTasks.length - 1
          ? null
          : toTasks[insertIndex + 1].position;

      var position = calculateItemPosition(
        positionBefore: positionBefore,
        positionAfter: positionAfter,
      );
      task.position = position;

      var success = await ref
          .read(projectControllerProvider(project).notifier)
          .moveTask(project, task, toBucket, position);

      if (!success && context.mounted) {
        ScaffoldMessenger.of(
          context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).taskMoveError)));

        //We need to update the drag immediately for UX reasons -> if it fails afterwards just reload the project
        ref.read(projectControllerProvider(project).notifier).reload();
      }
    });
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
