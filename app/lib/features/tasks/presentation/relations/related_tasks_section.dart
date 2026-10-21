import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The relations other than subtasks and parents, grouped by kind, and the
/// action that adds one. Without [onAdd] (no account) the action is left
/// out, and the section too when there is nothing to show.
class RelatedTasksSection extends StatelessWidget {
  const new({
    required this.task,
    required this.onOpen,
    this.onRemove,
    this.onAdd,
    this.projectTitleOf,
    super.key,
  });

  final Task task;
  final ValueChanged<Task> onOpen;
  final void Function(TaskRelationKind kind, Task other)? onRemove;
  final VoidCallback? onAdd;
  final String? Function(Task other)? projectTitleOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final groups = [
      for (final kind in otherRelationKinds)
        if (task.relatedTasks[kind] case final others? when others.isNotEmpty)
          (kind, inCreationOrder(others)),
    ];
    final onRemove = this.onRemove;
    if (groups.isEmpty && onAdd == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSectionHeader(title: l10n.taskDetailRelatedTasks),
        for (final (kind, others) in groups) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 4),
            child: Text(
              relationKindLabel(l10n, kind),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SectionCard(
            children: [
              for (final other in others)
                RelationRow(
                  key: ValueKey((kind, other.id)),
                  task: other,
                  projectTitle: projectTitleOf?.call(other),
                  onOpen: () => onOpen(other),
                  onRemove: onRemove == null
                      ? null
                      : () => onRemove(kind, other),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (onAdd case final onAdd?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link),
                label: Text(l10n.taskDetailAddRelation),
              ),
            ),
          ),
      ],
    );
  }
}

/// The tasks the sheet's task is a subtask of, each opening on tap.
class ParentTasksBlock extends StatelessWidget {
  const new({
    required this.parents,
    required this.onOpen,
    this.onRemove,
    this.projectTitleOf,
    super.key,
  });

  final List<Task> parents;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task>? onRemove;
  final String? Function(Task parent)? projectTitleOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onRemove = this.onRemove;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSectionHeader(title: l10n.taskDetailParentTask),
        SectionCard(
          children: [
            for (final parent in parents)
              RelationRow(
                key: ValueKey(parent.id),
                task: parent,
                projectTitle: projectTitleOf?.call(parent),
                onOpen: () => onOpen(parent),
                onRemove: onRemove == null ? null : () => onRemove(parent),
              ),
          ],
        ),
      ],
    );
  }
}
