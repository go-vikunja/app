import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/application/task_draft.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/assignees_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/date_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/discard_changes_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/labels_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/priority_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/reminders_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/repeat_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/assignee_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';

/// The title's counter shows once this few code points are left.
const _counterFrom = 50;

/// Edits the core properties of one task. The draft starts from the row as
/// it was when the page opened and Save sends only the fields that differ
/// from it, under the id the row has by then (a queued create may have
/// been answered meanwhile). The description opens the editor, which saves
/// it on its own.
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

  bool get _titleFits => _draft!.titleFits(_original!);

  bool get _canSave =>
      _dirty && _draft!.isValid && _titleFits && _current != null && !_saving;

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

  Future<void> _pickLabels() async {
    final picked = await pickLabels(context, selected: _draft!.labels);
    if (picked != null && mounted) {
      _update((draft) => draft.copyWith(labels: picked));
    }
  }

  Future<void> _pickAssignees() async {
    final draft = _draft!;
    final picked = await pickAssignees(
      context,
      projectId: draft.projectId,
      selected: draft.assignees,
    );
    if (picked != null && mounted) {
      _update((draft) => draft.copyWith(assignees: picked));
    }
  }

  /// Adds a reminder, or replaces the one at [index]; one the list already
  /// has is not added twice.
  Future<void> _pickReminder({int? index}) async {
    final draft = _draft!;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final picked = await pickReminder(
      context,
      dates: draft.reminderDates,
      now: ref.read(clockProvider)(),
      editing: index == null ? null : draft.reminders[index],
      existing: draft.reminders,
    );
    if (picked == null || !mounted) return;
    final reminders = withReminder(_draft!.reminders, picked, replacing: index);
    if (reminders == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.taskEditReminderDuplicate)),
      );
      return;
    }
    _update((draft) => draft.copyWith(reminders: reminders));
  }

  Future<void> _editDescription() async {
    final current = _current;
    if (current == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final saved = await context.pushPage<bool>(
      AppRoutes.taskDescription(current.id),
    );
    if (saved ?? false) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.descriptionEditorSaved)));
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
    final current = _current;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final archived =
        current != null &&
        isArchivedInTree(current.projectId, {
          for (final project in projects) project.id: project,
        });

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(l10n.taskEditTitle),
          actions: [
            AppBarTextAction(
              onPressed: _canSave ? () => unawaited(_save()) : null,
              child: Text(l10n.taskEditSave),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: switch ((draft, task)) {
          (final draft?, _) => _Form(
            draft: draft,
            originalHexColor: _original?.hexColor.toLowerCase() ?? '',
            description: current?.description ?? '',
            onEditDescription: current == null || archived
                ? null
                : () => unawaited(_editDescription()),
            titleController: _title,
            titleTooLong: !_titleFits,
            project: ref.watch(projectByIdProvider(draft.projectId)),
            onChanged: _update,
            onPickProject: () => unawaited(_pickProject()),
            onPickLabels: () => unawaited(_pickLabels()),
            onPickAssignees: () => unawaited(_pickAssignees()),
            onPickReminder: ({index}) => unawaited(_pickReminder(index: index)),
          ),
          (null, AsyncValue(hasValue: true)) => CenteredScrollView(
            maxWidth: ReadableWidth.form,
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.taskEditGoneTitle,
              body: l10n.taskEditGoneBody,
            ),
          ),
          (null, _) => CenteredScrollView(
            maxWidth: ReadableWidth.form,
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
    required this.originalHexColor,
    required this.description,
    required this.onEditDescription,
    required this.titleController,
    required this.titleTooLong,
    required this.project,
    required this.onChanged,
    required this.onPickProject,
    required this.onPickLabels,
    required this.onPickAssignees,
    required this.onPickReminder,
  });

  final TaskDraft draft;
  final String originalHexColor;

  /// As stored now: the editor saves it on its own.
  final String description;
  final VoidCallback? onEditDescription;
  final TextEditingController titleController;

  /// Changed and still over the limit, which a stored title may be.
  final bool titleTooLong;
  final Project? project;
  final void Function(TaskDraft Function(TaskDraft draft) change) onChanged;
  final VoidCallback onPickProject;
  final VoidCallback onPickLabels;
  final VoidCallback onPickAssignees;
  final void Function({int? index}) onPickReminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockTickProvider);
    final shortcuts = buildDateShortcuts(now);
    final percent = (draft.percentDone * 100).round();
    final descriptionText = htmlToPlainText(description);
    final used = titleController.text.runes.length;
    final left = Task.maxTitleLength - used;

    return ReadableWidth.builder(
      maxWidth: ReadableWidth.form,
      builder: (_, _, inset) => ListView(
        padding: EdgeInsets.fromLTRB(inset, 8, inset, 32),
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
              inputFormatters: [CodePointLimitFormatter(Task.maxTitleLength)],
              decoration: InputDecoration(
                labelText: l10n.taskEditTitleLabel,
                errorText: draft.hasTitle ? null : l10n.taskEditTitleRequired,
                counterText: left <= _counterFrom
                    ? '$used/${Task.maxTitleLength}'
                    : null,
                counterStyle: titleTooLong
                    ? TextStyle(color: colors.error)
                    : null,
                semanticCounterText: left <= _counterFrom && left >= 0
                    ? l10n.labelsTitleRemaining(left)
                    : null,
              ),
              onChanged: (text) =>
                  onChanged((draft) => draft.copyWith(title: text)),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: ProjectIcon(hexColor: project?.hexColor ?? ''),
            title: Text(l10n.taskEditProject),
            subtitle: Text(
              project?.displayTitle(l10n) ?? l10n.projectUnknownTitle,
            ),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: onPickProject,
          ),
          ListTile(
            leading: Icon(Icons.notes, color: colors.onSurfaceVariant),
            title: Text(l10n.taskDetailDescription),
            subtitle: Text(
              descriptionText.isEmpty
                  ? l10n.taskDetailNoDescription
                  : descriptionText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: onEditDescription != null,
            onTap: onEditDescription,
          ),
          _SectionTitle(l10n.taskDetailLabels),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelsSection(
              labels: draft.labels,
              onRemove: (label) => onChanged(
                (draft) => draft.copyWith(
                  labels: [
                    for (final kept in draft.labels)
                      if (kept.id != label.id) kept,
                  ],
                ),
              ),
              onAdd: onPickLabels,
            ),
          ),
          _SectionTitle(l10n.taskDetailAssignees),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AssigneesSection(
              assignees: draft.assignees,
              onRemove: (user) => onChanged(
                (draft) => draft.copyWith(
                  assignees: [
                    for (final kept in draft.assignees)
                      if (kept.id != user.id) kept,
                  ],
                ),
              ),
              onAdd: onPickAssignees,
            ),
          ),
          const SizedBox(height: 16),
          DateField(
            label: l10n.taskDetailDueDate,
            clearLabel: l10n.taskEditClearDueDate,
            icon: Icons.event_outlined,
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
          _SectionTitle(l10n.taskDetailReminders),
          RemindersSection(
            reminders: draft.reminders,
            dates: draft.reminderDates,
            onEdit: (index) => onPickReminder(index: index),
            onRemove: (index) => onChanged(
              (draft) => draft.copyWith(
                reminders: [...draft.reminders]..removeAt(index),
              ),
            ),
            onAdd: onPickReminder,
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
              original: originalHexColor,
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ListSectionHeader(
    title: text,
    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
  );
}
