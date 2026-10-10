import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/task_draft.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/date_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/discard_changes_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/priority_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/repeat_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';

/// Edits the core properties of one task. The draft starts from the row as
/// it was when the page opened and Save sends only the fields that differ
/// from it, under the id the row has by then (a queued create may have
/// been answered meanwhile).
class TaskEditPage extends ConsumerStatefulWidget {
  const new({required this.taskId, super.key});

  final int taskId;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _title = TextEditingController();
  Task? _original;
  Task? _current;
  TaskDraft? _draft;
  bool _saving = false;

  bool get _dirty {
    final draft = _draft;
    final original = _original;
    return draft != null && original != null && !draft.diff(original).isEmpty;
  }

  bool get _canSave =>
      _dirty && _draft!.isValid && _current != null && !_saving;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _adopt(Task? task) {
    _current = task;
    if (task == null || _draft != null) return;
    _original = task;
    _draft = TaskDraft.fromTask(task);
    _title.text = task.title;
  }

  /// Applied to the latest draft, so two edits in one frame both count.
  void _update(TaskDraft Function(TaskDraft draft) change) =>
      setState(() => _draft = change(_draft!));

  Future<void> _pickProject() async {
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    final picked = await pickProject(
      context,
      projects: projects,
      selectedId: _draft?.projectId,
    );
    if (picked != null && mounted) {
      _update((draft) => draft.copyWith(projectId: picked.id));
    }
  }

  Future<void> _save() async {
    final repository = ref.read(taskRepositoryProvider);
    final draft = _draft;
    final original = _original;
    final current = _current;
    if (repository == null || draft == null || original == null) return;
    if (current == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    await repository.updateTask(current.id, draft.diff(original));
    if (!mounted) return;
    router.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.taskEditSaved)));
  }

  Future<void> _leaveIfConfirmed() async {
    final router = GoRouter.of(context);
    if (await confirmDiscardChanges(context) && mounted) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final task = ref.watch(taskByIdProvider(widget.taskId));
    if (task case AsyncValue(hasValue: true, :final value)) _adopt(value);
    final draft = _draft;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.taskEditTitle),
          actions: [
            TextButton(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: Text(l10n.taskEditSave),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: switch ((draft, task)) {
          (final draft?, _) => _Form(
            draft: draft,
            titleController: _title,
            projectTitle: ref
                .watch(projectByIdProvider(draft.projectId))
                ?.title,
            onChanged: _update,
            onPickProject: () => unawaited(_pickProject()),
          ),
          (null, AsyncValue(hasValue: true)) => CenteredScrollView(
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.taskEditGoneTitle,
              body: l10n.taskEditGoneBody,
            ),
          ),
          (null, _) => CenteredScrollView(
            child: LoadingPlaceholder(label: l10n.taskEditLoading),
          ),
        },
      ),
    );
  }
}

class _Form extends ConsumerWidget {
  const new({
    required this.draft,
    required this.titleController,
    required this.projectTitle,
    required this.onChanged,
    required this.onPickProject,
  });

  final TaskDraft draft;
  final TextEditingController titleController;
  final String? projectTitle;
  final void Function(TaskDraft Function(TaskDraft draft) change) onChanged;
  final VoidCallback onPickProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockTickProvider);
    final shortcuts = buildDateShortcuts(now);
    final percent = (draft.percentDone * 100).round();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: titleController,
            // Wraps, but Return confirms instead of adding a line: titles
            // are one line everywhere.
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.taskEditTitleLabel,
              errorText: draft.hasTitle ? null : l10n.taskEditTitleRequired,
            ),
            onChanged: (text) =>
                onChanged((draft) => draft.copyWith(title: text)),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.folder_outlined, color: colors.onSurfaceVariant),
          title: Text(l10n.taskEditProject),
          subtitle: Text(projectTitle ?? l10n.projectUnknownTitle),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: onPickProject,
        ),
        const SizedBox(height: 8),
        DateField(
          label: l10n.taskDetailDueDate,
          clearLabel: l10n.taskEditClearDueDate,
          icon: Icons.event,
          value: draft.dueDate,
          now: now,
          shortcuts: shortcuts,
          onChanged: (value) =>
              onChanged((draft) => draft.copyWith(dueDate: value)),
        ),
        DateField(
          label: l10n.taskDetailStartDate,
          clearLabel: l10n.taskEditClearStartDate,
          icon: Icons.play_arrow_outlined,
          value: draft.startDate,
          now: now,
          shortcuts: shortcuts,
          onChanged: (value) =>
              onChanged((draft) => draft.copyWith(startDate: value)),
        ),
        DateField(
          label: l10n.taskDetailEndDate,
          clearLabel: l10n.taskEditClearEndDate,
          icon: Icons.stop_outlined,
          value: draft.endDate,
          now: now,
          shortcuts: shortcuts,
          onChanged: (value) =>
              onChanged((draft) => draft.copyWith(endDate: value)),
        ),
        _SectionTitle(l10n.taskDetailPriority),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PriorityChips(
            value: draft.priority,
            onChanged: (priority) =>
                onChanged((draft) => draft.copyWith(priority: priority)),
          ),
        ),
        _SectionTitle(l10n.taskDetailProgress),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.taskPercentDone(percent)),
        ),
        Slider.adaptive(
          value: percent.toDouble(),
          max: 100,
          divisions: 10,
          label: l10n.taskPercentDone(percent),
          semanticFormatterCallback: (value) =>
              l10n.taskPercentDone(value.round()),
          onChanged: (value) => onChanged(
            (draft) => draft.copyWith(percentDone: value.round() / 100),
          ),
        ),
        _SectionTitle(l10n.taskEditColour),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ColorRow(
            value: draft.hexColor,
            onChanged: (hex) =>
                onChanged((draft) => draft.copyWith(hexColor: hex)),
          ),
        ),
        _SectionTitle(l10n.taskEditRepeat),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RepeatSection(
            value: draft.repeat,
            onChanged: (change) => onChanged(
              (draft) => draft.copyWith(repeat: change(draft.repeat)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
