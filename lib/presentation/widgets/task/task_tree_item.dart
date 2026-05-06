import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';

/// Renders a [task] and its subtasks recursively in a tree layout.
///
/// [depth] controls how far to indent (24 dp per level).
/// [subtaskMap] maps parentTaskId → list of subtask [Task] objects sourced
/// from the flat API list, complementing the nested [Task.subtasks] field.
/// [onCheckedChanged] overrides the default mark-as-done behaviour; useful
/// when embedding this widget inside the project page.
/// [onSubtaskReorder] persists the new position of a reordered subtask to the
/// server.  It receives the moved task and its computed new position value.
/// If null, drag-to-reorder is disabled.
/// [dragIndex] when non-null, shows a ⠿ drag handle for this item's position
/// in its parent [SliverReorderableList] (top-level tasks only).
class TaskTreeItem extends ConsumerStatefulWidget {
  final Task task;
  final int depth;
  /// When non-null, this map is the authoritative source of subtasks
  /// (parentId → children). Pass `const {}` for flat mode (no subtasks shown).
  /// When null, falls back to `task.subtasks` from the API response.
  final Map<int, List<Task>>? subtaskMap;
  final Future<void> Function(Task task)? onCheckedChanged;
  final Future<bool> Function(Task task, double newPosition)? onSubtaskReorder;
  final int? dragIndex;

  const TaskTreeItem({
    super.key,
    required this.task,
    required this.depth,
    this.subtaskMap,
    this.onCheckedChanged,
    this.onSubtaskReorder,
    this.dragIndex,
  });

  @override
  ConsumerState<TaskTreeItem> createState() => _TaskTreeItemState();
}

class _TaskTreeItemState extends ConsumerState<TaskTreeItem> {
  bool _isExpanded = true;
  List<Task>? _orderedSubtasks;

  static const double _indentWidth = 24.0;
  static const double _chevronWidth = 28.0;

  List<Task> get _subtasks {
    final map = widget.subtaskMap;

    // null = no map provided, fall back to nested API field.
    if (map == null) {
      final list = List<Task>.from(widget.task.subtasks);
      list.sort((a, b) {
        final pa = a.position ?? double.maxFinite;
        final pb = b.position ?? double.maxFinite;
        return pa.compareTo(pb);
      });
      return list;
    }

    // Non-null map (including const {}) = use it exclusively.
    // An empty map means flat mode — show no subtasks.
    final fromMap = map[widget.task.id] ?? [];
    if (fromMap.isEmpty) return [];

    final list = List<Task>.from(fromMap);
    list.sort((a, b) {
      final pa = a.position ?? double.maxFinite;
      final pb = b.position ?? double.maxFinite;
      return pa.compareTo(pb);
    });
    return list;
  }

  // Returns the locally reordered subtask list (falls back to API list).
  List<Task> get _displaySubtasks => _orderedSubtasks ?? _subtasks;

  bool get _hasSubtasks => _displaySubtasks.isNotEmpty;

  @override
  void didUpdateWidget(TaskTreeItem old) {
    super.didUpdateWidget(old);
    // Reset local order when the server data changes.
    if (old.task != widget.task || old.subtaskMap != widget.subtaskMap) {
      _orderedSubtasks = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the task row only (not the subtask list) with the drag listener so
    // that a long-press on a subtask activates the inner reorderable list
    // rather than dragging the parent task.
    Widget row = _buildRow(context);
    if (widget.dragIndex != null) {
      row = ReorderableDelayedDragStartListener(
        index: widget.dragIndex!,
        child: row,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        if (_hasSubtasks && _isExpanded) _buildSubtaskList(context),
      ],
    );
  }

  Widget _buildSubtaskList(BuildContext context) {
    final subtasks = _displaySubtasks;
    // If no reorder callback is provided, render a plain non-draggable list.
    if (widget.onSubtaskReorder == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: subtasks
            .map(
              (subtask) => TaskTreeItem(
                key: Key('subtask_${subtask.id}'),
                task: subtask,
                depth: widget.depth + 1,
                subtaskMap: widget.subtaskMap,
                onCheckedChanged: widget.onCheckedChanged,
                onSubtaskReorder: null,
              ),
            )
            .toList(),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: subtasks.length,
      itemBuilder: (ctx, index) {
        final subtask = subtasks[index];
        return ReorderableDelayedDragStartListener(
          key: Key('sub_drag_${subtask.id}'),
          index: index,
          child: Material(
            color: Colors.transparent,
            child: TaskTreeItem(
              key: Key('subtask_${subtask.id}'),
              task: subtask,
              depth: widget.depth + 1,
              subtaskMap: widget.subtaskMap,
              onCheckedChanged: widget.onCheckedChanged,
              onSubtaskReorder: widget.onSubtaskReorder,
            ),
          ),
        );
      },
      onReorder: _reorderSubtasks,
    );
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final tasks = List<Task>.from(_displaySubtasks);
    final moved = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, moved);
    setState(() => _orderedSubtasks = tasks);

    final before = newIndex == 0 ? null : tasks[newIndex - 1].position;
    final after =
        newIndex >= tasks.length - 1 ? null : tasks[newIndex + 1].position;
    final newPos = calculateItemPosition(
      positionBefore: before,
      positionAfter: after,
    );

    widget.onSubtaskReorder!(moved, newPos).then((success) {
      if (!success && mounted) {
        // Revert to server order on failure.
        setState(() => _orderedSubtasks = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reorder subtask')),
        );
      }
    });
  }

  Widget _buildRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indentation area: each depth level is 24 dp wide.
          // For depth > 0 the rightmost 2 dp of the indent acts as a vertical
          // connector line to signal the parent–child relationship.
          if (widget.depth > 0)
            SizedBox(
              width: widget.depth * _indentWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 2.0,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          // Chevron toggle (only for tasks that have subtasks).
          if (_hasSubtasks)
            SizedBox(
              width: _chevronWidth,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Task item takes the remaining width.
          Expanded(
            child: TaskListItem(
              key: Key('task_item_${widget.task.id}'),
              task: widget.task,
              onTap: () => _showTaskBottomSheet(context),
              onEdit: () => _onEdit(context),
              onCheckedChanged: (_) => _markAsDone(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (BuildContext context) {
        return TaskBottomSheet(
          task: widget.task,
          onEdit: () => _onEdit(context),
        );
      },
    );
  }

  void _onEdit(BuildContext context) {
    Navigator.push<Task?>(
      context,
      MaterialPageRoute(
        builder: (buildContext) => TaskEditPage(task: widget.task),
      ),
    );
  }

  Future<void> _markAsDone(BuildContext context) async {
    if (widget.onCheckedChanged != null) {
      await widget.onCheckedChanged!(widget.task);
      return;
    }
    final success = await ref
        .read(taskPageControllerProvider.notifier)
        .markAsDone(widget.task);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).taskMarkDoneError),
        ),
      );
    }
  }
}
