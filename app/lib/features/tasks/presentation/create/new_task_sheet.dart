import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_format.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';

/// The quick way to a new task: a title, the project it goes to and
/// optionally a due date. [projectId] preselects the list's own project.
Future<void> showNewTaskSheet(BuildContext context, {int? projectId}) =>
    showModalBottomSheet<void>(
      context: context,
      // Over the tab bar, not inside the tab's own navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => NewTaskSheet(projectId: projectId),
    );

const Set<DateShortcut> _quickShortcuts = {
  DateShortcut.today,
  DateShortcut.tomorrow,
  DateShortcut.nextWeek,
};

class NewTaskSheet extends ConsumerStatefulWidget {
  const new({this.projectId, super.key});

  final int? projectId;

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _title = TextEditingController();
  int? _projectId;
  DateTime? _due;
  bool _adding = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canAdd =>
      _title.text.trim().isNotEmpty && _projectId != null && !_adding;

  Future<void> _pickProject(List<Project> projects) async {
    final picked = await pickProject(
      context,
      projects: projects,
      selectedId: _projectId,
    );
    if (picked != null && mounted) setState(() => _projectId = picked.id);
  }

  Future<void> _pickDue(DateTime now) async {
    final picked = await pickDateTime(context, current: _due, now: now);
    if (picked != null && mounted) setState(() => _due = picked.toUtc());
  }

  Future<void> _add({required bool openEditor}) async {
    final repository = ref.read(taskRepositoryProvider);
    final projectId = _projectId;
    if (!_canAdd || repository == null || projectId == null) return;
    final title = _title.text.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    setState(() => _adding = true);
    final id = await repository.createTask(
      NewTask(projectId: projectId, title: title, dueDate: _due),
    );
    if (!mounted) return;
    navigator.pop();
    if (openEditor) {
      unawaited(router.push(AppRoutes.taskEdit(id)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.newTaskCreated(title))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockProvider)();
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    _projectId ??= defaultProjectFor(
      projects,
      currentProjectId: widget.projectId,
    )?.id;
    final project = _projectId == null
        ? null
        : ref.watch(projectByIdProvider(_projectId!));
    final shortcuts = [
      for (final option in buildDateShortcuts(now))
        if (_quickShortcuts.contains(option.shortcut)) option,
    ];
    final dueLocal = _due?.toLocal();
    final dueDay = dueLocal == null
        ? null
        : DateTime(dueLocal.year, dueLocal.month, dueLocal.day);
    final dueOnShortcut = shortcuts.any((option) => option.day == dueDay);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // Scrolls once the keyboard leaves less room than the sheet needs.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text(l10n.newTask, style: theme.textTheme.titleMedium),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _title,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.taskEditTitleLabel,
                  hintText: l10n.newTaskTitleHint,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(_add(openEditor: false)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ActionChip(
                avatar: Icon(
                  Icons.folder_outlined,
                  color: colors.onSurfaceVariant,
                ),
                label: Text(
                  project?.title ?? l10n.newTaskNoProject,
                  semanticsLabel: l10n.taskEditProjectSemantics(
                    project?.title ?? l10n.newTaskNoProject,
                  ),
                ),
                onPressed: () => unawaited(_pickProject(projects)),
              ),
            ),
            const SizedBox(height: 8),
            DateShortcutChips(
              options: shortcuts,
              selectedDay: dueDay,
              wrap: true,
              onSelected: (option) => setState(
                () => _due = option == null
                    ? null
                    : dayWithTime(option.day, current: _due, now: now).toUtc(),
              ),
              trailing: [
                if (_due case final due? when !dueOnShortcut)
                  InputChip(
                    label: Text(formatMoment(context, due)),
                    selected: true,
                    onDeleted: () => setState(() => _due = null),
                    deleteButtonTooltipMessage: l10n.taskEditClearDueDate,
                  ),
                ActionChip(
                  avatar: Icon(Icons.event, color: colors.onSurfaceVariant),
                  label: Text(l10n.newTaskPickDate),
                  onPressed: () => unawaited(_pickDue(now)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              // Stacks the two buttons at large text scales.
              child: OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _canAdd
                        ? () => unawaited(_add(openEditor: true))
                        : null,
                    child: Text(l10n.newTaskMoreOptions),
                  ),
                  FilledButton(
                    onPressed: _canAdd
                        ? () => unawaited(_add(openEditor: false))
                        : null,
                    child: Text(l10n.newTaskAdd),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
