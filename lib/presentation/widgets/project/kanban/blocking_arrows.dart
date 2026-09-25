import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';

class BlockingLink {
  final int fromId;
  final int toId;

  const BlockingLink(this.fromId, this.toId);

  @override
  bool operator ==(Object other) =>
      other is BlockingLink && other.fromId == fromId && other.toId == toId;

  @override
  int get hashCode => Object.hash(fromId, toId);
}

/// A blocks B. Prefer `blocking`; also invert `blocked` so one-sided payloads work.
Set<BlockingLink> blockingLinksFromTasks(Iterable<Task> tasks) {
  final onBoard = tasks.map((task) => task.id).toSet();
  final links = <BlockingLink>{};
  for (final task in tasks) {
    for (final other in task.relatedTasks[RelationKind.blocking] ?? const []) {
      if (onBoard.contains(other.id) && other.id != task.id) {
        links.add(BlockingLink(task.id, other.id));
      }
    }
    for (final other in task.relatedTasks[RelationKind.blocked] ?? const []) {
      if (onBoard.contains(other.id) && other.id != task.id) {
        links.add(BlockingLink(other.id, task.id));
      }
    }
  }
  return links;
}

Iterable<Task> tasksInBuckets(List<Bucket> buckets) =>
    buckets.expand((bucket) => bucket.tasks);

class KanbanTaskRegistry extends InheritedWidget {
  final Map<int, GlobalKey> keys;

  const KanbanTaskRegistry({
    super.key,
    required this.keys,
    required super.child,
  });

  GlobalKey keyFor(int taskId) => keys.putIfAbsent(taskId, GlobalKey.new);

  static KanbanTaskRegistry? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<KanbanTaskRegistry>();
  }

  @override
  bool updateShouldNotify(KanbanTaskRegistry oldWidget) => false;
}

class BlockingArrowsLayer extends StatefulWidget {
  final List<Bucket> buckets;
  final Map<int, GlobalKey> taskKeys;

  const BlockingArrowsLayer({
    super.key,
    required this.buckets,
    required this.taskKeys,
  });

  @override
  State<BlockingArrowsLayer> createState() => BlockingArrowsLayerState();
}

class BlockingArrowsLayerState extends State<BlockingArrowsLayer> {
  List<_DrawnArrow> _arrows = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => measure());
  }

  @override
  void didUpdateWidget(BlockingArrowsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => measure());
  }

  void measure() {
    if (!mounted) return;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize || !overlayBox.attached) {
      return;
    }

    final rects = <int, Rect>{};
    for (final entry in widget.taskKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final origin = overlayBox.globalToLocal(box.localToGlobal(Offset.zero));
      rects[entry.key] = origin & box.size;
    }

    final links = blockingLinksFromTasks(tasksInBuckets(widget.buckets));
    final arrows = <_DrawnArrow>[];
    for (final link in links) {
      final from = rects[link.fromId];
      final to = rects[link.toId];
      if (from == null || to == null) continue;
      arrows.add(_arrowBetween(from, to));
    }

    setState(() => _arrows = arrows);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlockingArrowPainter(_arrows));
  }
}

class _DrawnArrow {
  final Offset start;
  final Offset control;
  final Offset end;

  const _DrawnArrow(this.start, this.control, this.end);
}

_DrawnArrow _arrowBetween(Rect from, Rect to) {
  final goingRight = to.center.dx >= from.center.dx;
  final start = goingRight ? from.centerRight : from.centerLeft;
  final end = goingRight ? to.centerLeft : to.centerRight;
  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = max(sqrt(dx * dx + dy * dy), 1);
  final bulge = min(40.0, len * 0.25);
  final control = Offset(mid.dx - dy / len * bulge, mid.dy + dx / len * bulge);
  return _DrawnArrow(start, control, end);
}

class _BlockingArrowPainter extends CustomPainter {
  final List<_DrawnArrow> arrows;

  _BlockingArrowPainter(this.arrows);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xCCD32F2F)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final arrow in arrows) {
      final path = Path()
        ..moveTo(arrow.start.dx, arrow.start.dy)
        ..quadraticBezierTo(
          arrow.control.dx,
          arrow.control.dy,
          arrow.end.dx,
          arrow.end.dy,
        );
      canvas.drawPath(path, paint);
      _drawHead(canvas, paint, arrow.control, arrow.end);
    }
  }

  void _drawHead(Canvas canvas, Paint stroke, Offset control, Offset end) {
    final angle = atan2(end.dy - control.dy, end.dx - control.dx);
    const size = 11.0;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - size * cos(angle - pi / 6),
        end.dy - size * sin(angle - pi / 6),
      )
      ..lineTo(
        end.dx - size * cos(angle + pi / 6),
        end.dy - size * sin(angle + pi / 6),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = stroke.color);
  }

  @override
  bool shouldRepaint(_BlockingArrowPainter oldDelegate) =>
      !identical(oldDelegate.arrows, arrows);
}
