import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// The subtasks with their done controls, and a field that adds one; the
/// field stays focused for the next. Without [onAdd] (no account) the
/// field is left out and the controls only show.
class SubtasksSection extends StatefulWidget {
  const new({
    required this.subtasks,
    required this.onOpen,
    this.onDoneChanged,
    this.onRemove,
    this.onAdd,
    this.projectTitleOf,
    super.key,
  });

  final List<Task> subtasks;
  final ValueChanged<Task> onOpen;
  final void Function(Task subtask, {required bool done})? onDoneChanged;
  final ValueChanged<Task>? onRemove;

  /// True when the subtask was added; it reports a failure itself.
  final Future<bool> Function(String title)? onAdd;

  /// The project title to show for a subtask, null for none.
  final String? Function(Task subtask)? projectTitleOf;

  @override
  State<SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends State<SubtasksSection> {
  final _title = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    final title = _title.text.trim();
    if (onAdd == null || title.isEmpty || _adding) return;
    setState(() => _adding = true);
    final added = await onAdd(title);
    if (!mounted) return;
    setState(() => _adding = false);
    if (added) _title.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtasks = widget.subtasks;
    final done = subtasks.where((task) => task.done).length;
    final onDoneChanged = widget.onDoneChanged;
    final onRemove = widget.onRemove;
    final canAdd = !_adding && _title.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSectionHeader(
          title: l10n.taskDetailSubtasks,
          trailing: subtasks.isEmpty
              ? null
              : l10n.taskDetailSubtasksDone(done, subtasks.length),
        ),
        for (final subtask in subtasks)
          RelationRow(
            key: ValueKey(subtask.id),
            task: subtask,
            projectTitle: widget.projectTitleOf?.call(subtask),
            leading: TaskDoneControl(
              done: subtask.done,
              onChanged: onDoneChanged == null
                  ? null
                  : (done) => onDoneChanged(subtask, done: done),
            ),
            onOpen: () => widget.onOpen(subtask),
            onRemove: onRemove == null ? null : () => onRemove(subtask),
          ),
        if (widget.onAdd != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextField(
              controller: _title,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.taskDetailAddSubtask,
                prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                suffixIcon: IconButton(
                  onPressed: canAdd ? () => unawaited(_add()) : null,
                  tooltip: l10n.taskDetailAddSubtask,
                  icon: const Icon(Icons.add),
                ),
              ),
              // Keeps the keyboard up for the next subtask; Done on an empty
              // field closes it.
              onEditingComplete: () {
                if (_title.text.trim().isEmpty) _focus.unfocus();
              },
              onSubmitted: (_) => unawaited(_add()),
            ),
          ),
      ],
    );
  }
}
