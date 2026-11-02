import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/attachments/application/queue_attachments.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/share/application/share_files.dart';
import 'package:vikunja_mobile/features/share/application/share_targets.dart';
import 'package:vikunja_mobile/features/share/application/share_text.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachment_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';

final _log = Logger('ShareSheet');

/// The share sheet's route, so that a newer share can tell it is open.
const shareSheetRouteName = 'share';

/// What a confirmed share did: [task] got the text and [queued] files, and
/// was [created] for it or already there; [problems] names files that
/// could not be queued.
@immutable
final class ShareOutcome {
  const new({
    required this.task,
    required this.created,
    required this.queued,
    this.problems,
  });

  final Task task;
  final bool created;
  final int queued;
  final String? problems;
}

/// What another app shared, made into a new task or added to one of the
/// active account's tasks; null when the user leaves. Works offline: the
/// task, the description and every file go through the outbox. A Cupertino
/// sheet on iOS, a bottom sheet elsewhere. [onSubmit] gets the confirmed
/// share's work, which goes on when the sheet is dragged away meanwhile;
/// it never throws.
Future<ShareOutcome?> showShareSheet(
  BuildContext context, {
  required IncomingShare share,
  ValueChanged<Future<ShareOutcome?>>? onSubmit,
}) {
  Widget aboveKeyboard(BuildContext context, Widget child) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
  const settings = RouteSettings(name: shareSheetRouteName);
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showReadableCupertinoSheet<ShareOutcome>(
        context: context,
        settings: settings,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: aboveKeyboard(
              context,
              ShareSheet(
                share: share,
                scrollController: scrollController,
                onSubmit: onSubmit,
              ),
            ),
          ),
        ),
      );
    case _:
      return showModalBottomSheet<ShareOutcome>(
        context: context,
        routeSettings: settings,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => aboveKeyboard(
          context,
          FractionallySizedBox(
            heightFactor: 0.9,
            child: ShareSheet(share: share, onSubmit: onSubmit),
          ),
        ),
      );
  }
}

enum _Mode { newTask, addToTask }

typedef _ReadyFile = ({String path, String name, String? mimeType});

class ShareSheet extends ConsumerStatefulWidget {
  const new({
    required this.share,
    this.scrollController,
    this.onSubmit,
    super.key,
  });

  final IncomingShare share;
  final ScrollController? scrollController;
  final ValueChanged<Future<ShareOutcome?>>? onSubmit;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late final SharedTaskText _shared = sharedTaskText(
    subject: widget.share.subject,
    text: widget.share.text,
    singleFileName: widget.share.files.length == 1
        ? widget.share.files.single.displayName
        : null,
  );
  late final _title = TextEditingController(text: _shared.title);
  late final _notes = TextEditingController(text: _shared.notes);
  late final _appended = TextEditingController(
    text: sharedTextToAppend(
      subject: widget.share.subject,
      text: widget.share.text,
    ),
  );
  // Whether the share came with text, not whether the field still has
  // some: emptied, it must stay to be typed into.
  late final bool _hasSharedText = _appended.text.trim().isNotEmpty;
  final _query = TextEditingController();
  late final ShareFilesController _files;
  _Mode _mode = _Mode.newTask;
  int? _pickedProjectId;
  int? _targetId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final attachments = ref.read(attachmentRepositoryProvider);
    _files = ShareFilesController(
      source: ref.read(shareIntentSourceProvider),
      files: widget.share.files,
      uploadsEnabled: attachments?.uploadsEnabled ?? false,
      maxBytes: attachments?.maxUploadBytes ?? 0,
    );
    unawaited(_files.prepare());
    for (final controller in [_title, _appended]) {
      controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _files.dispose();
    for (final controller in [_title, _notes, _appended, _query]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool _canSubmit(Project? project) {
    if (_submitting || _files.preparing) return false;
    return switch (_mode) {
      _Mode.newTask => _title.text.trim().isNotEmpty && project != null,
      _Mode.addToTask =>
        _targetId != null &&
            (_appended.text.trim().isNotEmpty || _files.ready.isNotEmpty),
    };
  }

  Future<void> _pickProject(List<Project> projects, int? selectedId) async {
    final picked = await pickProject(
      context,
      projects: projects,
      selectedId: selectedId,
    );
    if (picked != null && mounted) setState(() => _pickedProjectId = picked.id);
  }

  /// Leaving is blocked meanwhile, except for a drag, which the material
  /// sheet does not ask about; the work goes on without the sheet then.
  Future<void> _submit(Project? project) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null || !_canSubmit(project)) return;
    final l10n = context.l10n;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final files = [
      for (final (item, copy) in _files.ready)
        (path: copy.path, name: item.name, mimeType: item.file.mimeType),
    ];
    final work = switch (_mode) {
      _Mode.newTask => _createTask(l10n, repository, project!.id, files),
      _Mode.addToTask => _addToTask(l10n, repository, _targetId!, files),
    };
    widget.onSubmit?.call(
      work.then((outcome) => outcome, onError: (Object _) => null),
    );
    try {
      final outcome = await work;
      if (!mounted) return;
      if (outcome == null) {
        setState(() => _error = l10n.taskEditGoneBody);
        return;
      }
      Navigator.of(context).pop(outcome);
    } on Object catch (error) {
      _log.warning('Adding a share failed: ${error.runtimeType}');
      if (mounted) setState(() => _error = l10n.shareFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<ShareOutcome> _createTask(
    AppLocalizations l10n,
    TaskRepository repository,
    int projectId,
    List<_ReadyFile> files,
  ) async {
    final title = _title.text.trim();
    final id = await repository.createTask(
      NewTask(
        projectId: projectId,
        title: title,
        description: sharedTextHtml(_notes.text),
      ),
    );
    final queued = await _queueFiles(repository, id, files);
    return ShareOutcome(
      task: Task(id: id, title: title, projectId: projectId),
      created: true,
      queued: queued.queued,
      problems: _problemsOf(l10n, queued),
    );
  }

  /// The text goes after the description as it is stored now, which the
  /// change carries as its base, so a web edit meanwhile is not lost.
  Future<ShareOutcome?> _addToTask(
    AppLocalizations l10n,
    TaskRepository repository,
    int taskId,
    List<_ReadyFile> files,
  ) async {
    final addition = sharedTextHtml(_appended.text);
    final task = await repository.watchTask(taskId).first;
    if (task == null) return null;
    if (addition.isNotEmpty) {
      final queued = await repository.updateDescription(
        task.id,
        appendToDescription(task.description, addition),
        base: task.description,
      );
      if (!queued) return null;
    }
    final queued = await _queueFiles(repository, task.id, files);
    return ShareOutcome(
      task: task,
      created: false,
      queued: queued.queued,
      problems: _problemsOf(l10n, queued),
    );
  }

  /// The inbox copies move into the account's uploads.
  Future<QueuedAttachments> _queueFiles(
    TaskRepository repository,
    int taskId,
    List<_ReadyFile> files,
  ) => queueAttachments(repository, taskId, files, moveSource: true);

  String? _problemsOf(AppLocalizations l10n, QueuedAttachments queued) {
    if (queued.tooLarge.isEmpty && queued.failed.isEmpty) return null;
    return queuedAttachmentsText(
      l10n,
      QueuedAttachments(
        tooLarge: queued.tooLarge,
        maxBytes: queued.maxBytes,
        failed: queued.failed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final settings =
        ref.watch(userSettingsProvider).value ?? const UserSettings();
    final project = defaultProjectFor(
      projects,
      currentProjectId: _pickedProjectId,
      defaultProjectId: settings.defaultProjectId,
    );

    return ListenableBuilder(
      listenable: _files,
      builder: (context, _) => PopScope(
        canPop: !_submitting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.shareSheetTitle,
              leading: IconButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close),
              ),
              actionLabel: switch (_mode) {
                _Mode.newTask => l10n.shareCreate,
                _Mode.addToTask => l10n.shareAdd,
              },
              onAction: _canSubmit(project)
                  ? () => unawaited(_submit(project))
                  : null,
            ),
            SizedBox(
              height: 4,
              child: _submitting ? const LinearProgressIndicator() : null,
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (account != null)
                    Text(
                      accountSubtitleOf(l10n, account),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (_error case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SegmentedButton<_Mode>(
                    segments: [
                      ButtonSegment(
                        value: _Mode.newTask,
                        label: Text(l10n.newTask),
                        icon: const Icon(Icons.add_task),
                      ),
                      ButtonSegment(
                        value: _Mode.addToTask,
                        label: Text(l10n.shareAddToTask),
                        icon: const Icon(Icons.playlist_add),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _submitting
                        ? null
                        : (selected) => setState(() {
                            _mode = selected.single;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  ...switch (_mode) {
                    _Mode.newTask => _newTaskFields(l10n, projects, project),
                    _Mode.addToTask => _addToTaskFields(l10n, projects),
                  },
                  if (widget.share.files.isNotEmpty) ..._fileRows(l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _newTaskFields(
    AppLocalizations l10n,
    List<Project> projects,
    Project? project,
  ) {
    final projectTitle =
        project?.displayTitle(l10n) ?? l10n.projectUnknownTitle;
    return [
      TextField(
        controller: _title,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.taskEditTitleLabel),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        enabled: !_submitting,
        minLines: 2,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.taskDetailDescription),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: ProjectIcon(hexColor: project?.hexColor ?? ''),
          label: Text(
            projectTitle,
            semanticsLabel: l10n.taskEditProjectSemantics(projectTitle),
          ),
          onPressed: _submitting
              ? null
              : () => unawaited(_pickProject(projects, project?.id)),
        ),
      ),
    ];
  }

  List<Widget> _addToTaskFields(AppLocalizations l10n, List<Project> projects) {
    final colors = Theme.of(context).colorScheme;
    final projectsById = {for (final project in projects) project.id: project};
    final tasks = ref.watch(openTasksProvider);
    final candidates = shareTargets(
      tasks.value ?? const [],
      query: _query.text,
      projectsById: projectsById,
    );
    return [
      if (_hasSharedText || widget.share.files.isEmpty) ...[
        TextField(
          controller: _appended,
          enabled: !_submitting,
          minLines: 2,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: l10n.taskDetailDescription,
            helperText: l10n.shareAppendHint,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _query,
        enabled: !_submitting,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: l10n.addRelationSearch,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (_targetId == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.sharePickTask,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      for (final task in candidates)
        _TaskChoice(
          task: task,
          projectTitle: projectsById[task.projectId]?.displayTitle(l10n),
          selected: task.id == _targetId,
          onTap: _submitting ? null : () => setState(() => _targetId = task.id),
        ),
      if (tasks.hasValue && candidates.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            l10n.addRelationNoMatches,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
    ];
  }

  List<Widget> _fileRows(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final note = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final items = _files.value;
    return [
      const SizedBox(height: 16),
      Semantics(
        header: true,
        headingLevel: 2,
        child: Text(
          l10n.shareFiles,
          style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
        ),
      ),
      if (items.any((item) => item.status is ShareFileNotTaken))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.shareFilesLeftOut, style: note),
        ),
      if (_files.leftOut > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.shareTooManyFiles(ShareFilesController.maxFiles),
            style: note,
          ),
        ),
      for (final item in items)
        _FileRow(
          key: ValueKey(('share-file', item.file.uri)),
          item: item,
          onRemove: _submitting ? null : () => _files.remove(item.file),
        ),
    ];
  }
}

class _TaskChoice extends StatelessWidget {
  const new({
    required this.task,
    required this.selected,
    required this.onTap,
    this.projectTitle,
  });

  final Task task;
  final bool selected;
  final VoidCallback? onTap;
  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final projectTitle = this.projectTitle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(task.title),
      subtitle: projectTitle == null ? null : Text(projectTitle),
      onTap: onTap,
    );
  }
}

class _FileRow extends StatelessWidget {
  const new({required this.item, required this.onRemove, super.key});

  final ShareFileItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final (status, problem) = switch (item.status) {
      ShareFilePreparing() => (l10n.shareFilePreparing, false),
      ShareFileReady(:final copy) => (formatFileSize(l10n, copy.size), false),
      ShareFileTooLarge(:final maxBytes) => (
        l10n.shareFileTooLarge(formatFileSize(l10n, maxBytes)),
        true,
      ),
      ShareFileUnreadable() => (l10n.shareFileUnreadable, true),
      ShareFileNotTaken() => (l10n.attachmentsDisabled, true),
    };
    return Row(
      children: [
        Expanded(
          child: MergeSemantics(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ExcludeSemantics(
                child: AttachmentIcon(
                  icon: attachmentIconFor(item.name, item.file.mimeType ?? ''),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                status,
                style: problem ? TextStyle(color: colors.error) : null,
              ),
            ),
          ),
        ),
        if (item.status is ShareFilePreparing)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        IconButton(
          onPressed: onRemove,
          tooltip: l10n.shareRemoveFile(item.name),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
