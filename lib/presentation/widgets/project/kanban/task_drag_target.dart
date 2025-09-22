import 'package:flutter/material.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';

class TaskDragTarget extends StatefulWidget {
  final void Function(TaskDrag) onAccept;
  final VoidCallback? stopAutoScroll;

  const TaskDragTarget({
    super.key,
    required this.onAccept,
    this.stopAutoScroll,
  });

  @override
  State<TaskDragTarget> createState() => _TaskDragTargetState();
}

class _TaskDragTargetState extends State<TaskDragTarget> {
  bool _hovering = false;

  void _safeSet(void Function() fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<TaskDrag>(
      onMove: (_) => _safeSet(() => _hovering = true),
      onLeave: (_) => _safeSet(() => _hovering = false),
      onAcceptWithDetails: (details) {
        widget.stopAutoScroll?.call();
        widget.onAccept(details.data);
        _safeSet(() => _hovering = false);
      },
      builder: (context, candidate, rejected) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: _hovering ? 16 : 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: _hovering
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}
