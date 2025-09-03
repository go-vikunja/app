import 'package:flutter/material.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';

class BucketDragTarget extends StatefulWidget {
  final int index;
  final void Function(BucketDrag) onAccept;

  const BucketDragTarget(
      {super.key, required this.index, required this.onAccept});

  @override
  State<BucketDragTarget> createState() => _BucketDragTargetState();
}

class _BucketDragTargetState extends State<BucketDragTarget> {
  bool _hovering = false;

  void _safeSet(void Function() fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<BucketDrag>(
      onMove: (_) => _safeSet(() => _hovering = true),
      onLeave: (_) => _safeSet(() => _hovering = false),
      onAcceptWithDetails: (details) {
        widget.onAccept(details.data);
        _safeSet(() => _hovering = false);
      },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _hovering ? 64 : 16,
          height: 200,
          margin: const EdgeInsets.only(left: 4, right: 4),
          decoration: BoxDecoration(
            color: _hovering
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
