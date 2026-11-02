import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// Lets the user pick a kind and another task of this account for a new
/// relation of [task]; null when dismissed. Searches the tasks on this
/// device, so it works offline.
Future<TaskRelationRef?> pickRelation(
  BuildContext context, {
  required Task task,
}) => showPickerSheet<TaskRelationRef>(
  context,
  heightFactor: 0.9,
  builder: (context, scrollController) =>
      AddRelationSheet(task: task, scrollController: scrollController),
);

class AddRelationSheet extends ConsumerStatefulWidget {
  const new({required this.task, this.scrollController, super.key});

  final Task task;
  final ScrollController? scrollController;

  @override
  ConsumerState<AddRelationSheet> createState() => _AddRelationSheetState();
}

class _AddRelationSheetState extends ConsumerState<AddRelationSheet> {
  final _query = TextEditingController();
  TaskRelationKind _kind = TaskRelationKind.related;
  bool _includeDone = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The open tasks, or with [_includeDone] every task without its lists
  /// and relations, and whether they have loaded.
  (List<Task>, bool) _tasks() {
    final tasks = ref.watch(
      _includeDone ? searchableTasksProvider : openTasksProvider,
    );
    return (tasks.value ?? const [], tasks.hasValue);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (tasks, loaded) = _tasks();
    final candidates = relationCandidates(
      tasks,
      task: widget.task,
      kind: _kind,
      query: _query.text,
      includeDone: _includeDone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: l10n.taskDetailAddRelation),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DropdownButtonFormField<TaskRelationKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.addRelationKind),
                  items: [
                    for (final kind in pickableRelationKinds)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(
                          relationKindLabel(l10n, kind),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (kind) {
                    if (kind != null) setState(() => _kind = kind);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.addRelationSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SwitchListTile.adaptive(
                value: _includeDone,
                onChanged: (value) => setState(() => _includeDone = value),
                title: Text(l10n.addRelationShowDone),
              ),
              for (final other in candidates)
                _CandidateRow(
                  task: other,
                  projectTitle: other.projectId == widget.task.projectId
                      ? null
                      : ref
                            .watch(projectByIdProvider(other.projectId))
                            ?.displayTitle(l10n),
                  onTap: () =>
                      Navigator.of(context)
                          .pop(TaskRelationRef(_kind, other.id)),
                ),
              if (loaded && candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.addRelationNoMatches,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const new({required this.task, required this.onTap, this.projectTitle});

  final Task task;
  final VoidCallback onTap;
  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final projectTitle = this.projectTitle;
    return ListTile(
      leading: Icon(
        task.done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.done ? colors.primary : colors.onSurfaceVariant,
        semanticLabel: task.done ? l10n.taskDone : null,
      ),
      title: Text(
        task.title,
        style: task.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: projectTitle == null ? null : Text(projectTitle),
      onTap: onTap,
    );
  }
}
