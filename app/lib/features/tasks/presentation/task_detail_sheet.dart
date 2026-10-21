import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/identifier_text.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';
import 'package:vikunja_mobile/features/tasks/application/task_identifier.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/delete_task_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_metadata_line.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/add_relation_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/related_tasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/subtasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_link_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

final _log = Logger('TaskDetail');

/// Shows what this device knows about [task] and, online, what only the
/// server has (attachments, reactions, comments, whether the user follows
/// it). [messengerBelow] is the messenger of the sheet this one opens over,
/// see [TaskDetailSheet.messengerBelow].
Future<void> showTaskDetail(
  BuildContext context, {
  required Task task,
  GlobalKey<ScaffoldMessengerState>? messengerBelow,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<void>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => TaskDetailSheet(
          task: task,
          scrollController: scrollController,
          messengerBelow: messengerBelow,
        ),
      );
    case _:
      return showModalBottomSheet<void>(
        context: context,
        // Over the tab bar, not inside the tab's own navigator.
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        // The page's colour, under the cards of the sections.
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) => TaskDetailSheet(
            task: task,
            scrollController: scrollController,
            messengerBelow: messengerBelow,
          ),
        ),
      );
  }
}

enum _SheetAction { duplicate, delete }

/// Follows the local row of [task] while it is open, so a done toggle here,
/// the server's answer to it (a repeating task's next occurrence) and the
/// id a queued create gets show; [task] itself is the fallback once the row
/// is gone. Its project is watched too. What only the server has is read
/// once on opening; offline the sheet says so in one line and shows the
/// rest. Messages about what happens in the sheet show inside it.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const new({
    required this.task,
    required this.scrollController,
    this.messengerBelow,
    super.key,
  });

  final Task task;
  final ScrollController scrollController;

  /// Where a message outlasting this sheet shows once it closes: the sheet
  /// it was opened over, which the screen's own messenger would sit behind.
  /// Null over a screen.
  final GlobalKey<ScaffoldMessengerState>? messengerBelow;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _follow = FollowController(
    entity: SubscriptionEntity.task,
    read: (id) => _subscriptions().forTask(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setTaskSubscribed(id, subscribed: subscribed),
  );
  late final _details = TaskDetailsController(
    read: (id) => _detailsRepository().details(id),
    markRead: (id) => _detailsRepository().markRead(id),
  );
  late final _comments = CommentsController(
    read: (id, {required page, required newestFirst}) =>
        _detailsRepository().comments(id, page: page, newestFirst: newestFirst),
  );
  bool _duplicating = false;
  bool _openingLinkedTask = false;
  CommentsState _commentsBefore = const CommentsState();
  StreamSubscription<TaskAttachment>? _uploaded;

  @override
  void initState() {
    super.initState();
    _comments.addListener(_announceComments);
    // A queued upload that went through while the sheet is open shows
    // without a read; the server does not mark the task changed for it.
    ref.listenManual(taskRepositoryProvider, (_, repository) {
      unawaited(_uploaded?.cancel());
      _uploaded = repository?.uploadedAttachments.listen(
        _details.addAttachment,
      );
    }, fireImmediately: true);
    ref.listenManual(
      userSettingsProvider.select((settings) => settings.value),
      (_, settings) {
        if (settings == null) return;
        _comments.useDefaultOrder(
          newestFirst:
              settings.commentSortOrder == CommentSortOrder.newestFirst,
        );
      },
      fireImmediately: true,
    );
    if (widget.task.id > 0) _loadDetails(widget.task.id);
  }

  @override
  void dispose() {
    unawaited(_uploaded?.cancel());
    _follow.dispose();
    _details.dispose();
    _comments.dispose();
    super.dispose();
  }

  SubscriptionRepository _subscriptions() =>
      ref.read(subscriptionRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  TaskDetailsRepository _detailsRepository() =>
      ref.read(taskDetailsRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  /// One read for the details and the follow bell.
  void _loadDetails(int taskId) {
    _comments.forTask(taskId);
    final details = _details.load(taskId);
    unawaited(
      _follow.load(
        taskId,
        pending: details.then((details) => details.subscription),
      ),
    );
  }

  void _announceComments() {
    final before = _commentsBefore;
    final after = _commentsBefore = _comments.value;
    // Also runs from initState, where no inherited widget may be read.
    if (!mounted || !before.loading || after.loading) return;
    final message = commentsResultAnnouncement(
      context.l10n,
      before: before,
      after: after,
    );
    if (message == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  /// The details again, and the images that failed for a reason that may
  /// have passed.
  void _retryDetails(int taskId) {
    ref.read(attachmentImagesProvider)?.forgetFailures();
    _loadDetails(taskId);
  }

  void _showMessage(String text) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// The sheet closes, so its "Task deleted" lands on what is below it.
  Future<void> _delete(TaskRepository repository, Task task) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final screenMessenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteTask(context, title: task.title);
    if (!confirmed || !mounted) return;
    await repository.deleteTask(task.id);
    if (!mounted) return;
    final messenger = widget.messengerBelow?.currentState ?? screenMessenger;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.taskDeleted)));
  }

  Future<void> _duplicate(TaskRepository repository, Task task) async {
    final l10n = context.l10n;
    setState(() => _duplicating = true);
    try {
      final copyId = await repository.duplicateTask(task.id);
      if (!mounted) return;
      // The sheet follows the stored copy; this stands in until it shows.
      final copy = Task(
        id: copyId,
        title: task.title,
        projectId: task.projectId,
      );
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.taskDuplicated),
            persist: MediaQuery.accessibleNavigationOf(context),
            action: SnackBarAction(
              label: l10n.taskDuplicateOpen,
              onPressed: () => _open(copy),
            ),
          ),
        );
    } on Object catch (error) {
      _log.warning('Duplicating a task failed: ${error.runtimeType}');
      if (mounted) _showMessage(_duplicateFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  static String _duplicateFailureText(AppLocalizations l10n, Object error) =>
      switch (error) {
        NetworkFailure() => l10n.taskDuplicateNeedsConnection,
        TaskNotSyncedYet() => l10n.taskDuplicateNotSynced,
        VikunjaFailure(:final message) when message.trim().isNotEmpty =>
          l10n.taskDuplicateFailed(message.trim()),
        _ => l10n.taskDuplicateFailedUnknown,
      };

  Future<void> _toggleFollow(Task task, Map<int, String> projectTitles) async {
    final l10n = context.l10n;
    if (task.id < 0) {
      _showMessage(l10n.followTaskOnceSynced);
      return;
    }
    final message = await toggleFollowing(
      context,
      _follow,
      id: task.id,
      projectTitle: (id) => projectTitles[id] ?? l10n.projectUnknownTitle,
    );
    if (message != null && mounted) _showMessage(message);
  }

  /// The edit page replaces the sheet, so its "Saved" lands on the list.
  void _edit(Task task) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(AppRoutes.taskEdit(task.id)));
  }

  /// The editor opens over the sheet, which comes back with the new
  /// description.
  /// An image inserted in the editor is an attachment by now, whether the
  /// edit was saved or not; the server's task does not say so.
  Future<void> _editDescription(Task task) async {
    final l10n = context.l10n;
    final saved = await context.pushPage<bool>(
      AppRoutes.taskDescription(task.id),
    );
    if (!mounted) return;
    unawaited(_details.refresh());
    if (saved ?? false) _showMessage(l10n.descriptionEditorSaved);
  }

  /// Applied at once and queued; a tap on a view older than the row (a
  /// second tap before it caught up) is refused and the view follows the
  /// row.
  Future<void> _toggleChecklistItem(
    TaskRepository repository,
    Task task,
    String html,
    RichTaskItem item,
  ) async {
    final l10n = context.l10n;
    final checked = !item.checked;
    final bool toggled;
    try {
      toggled = await repository.toggleChecklistItem(
        task.id,
        html: html,
        item: item,
        checked: checked,
      );
    } on Object catch (error) {
      _log.warning('Ticking a checklist item failed: ${error.runtimeType}');
      return;
    }
    if (!toggled || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        checked ? l10n.checklistItemChecked : l10n.checklistItemUnchecked,
        Directionality.of(context),
      ),
    );
  }

  /// Another sheet over this one, which closing brings back.
  void _open(Task other) {
    if (!mounted) return;
    unawaited(showTaskDetail(context, task: other, messengerBelow: _messenger));
  }

  /// A task link in the description or a comment, in this sheet's account;
  /// one not on this device is read online, with progress at the top and
  /// further taps ignored meanwhile.
  Future<void> _openLinkedTask(int taskId) async {
    if (_openingLinkedTask) return;
    final accountId = ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    final l10n = context.l10n;
    setState(() => _openingLinkedTask = true);
    try {
      final task = await ref
          .read(taskOpenerProvider)
          .resolve(accountId, TaskById(taskId));
      if (mounted && ref.read(activeAccountIdProvider) == accountId) {
        _open(task);
      }
    } on Object catch (error) {
      _log.info('Opening a linked task failed: ${error.runtimeType}');
      if (mounted) _showMessage(taskOpenFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _openingLinkedTask = false);
    }
  }

  void _openLink(String href) => unawaited(
    openRichTextLink(
      ref,
      href,
      openTask: (taskId) => unawaited(_openLinkedTask(taskId)),
      showMessage: (text) {
        if (mounted) _showMessage(text(context.l10n));
      },
    ),
  );

  /// The project's screen is in a tab: the sheets close and the pages
  /// over the shell go as if the user went back.
  Future<void> _openProject(Project project) async {
    final router = GoRouter.of(context);
    ref.read(rootModalRoutesProvider).closeAll();
    if (!await popPagesOverShell(router)) return;
    router.go(AppRoutes.project(project.id));
  }

  /// Works offline: the subtask and its relation are queued, the create
  /// first. True once the subtask exists, also when its relation could not
  /// be queued: adding it again would make a second one.
  Future<bool> _addSubtask(
    TaskRepository repository,
    Task parent,
    String title,
  ) async {
    final l10n = context.l10n;
    final int id;
    try {
      id = await repository.createTask(
        NewTask(projectId: parent.projectId, title: title),
      );
    } on Object catch (error) {
      _log.warning('Adding a subtask failed: ${error.runtimeType}');
      if (mounted) _showMessage(l10n.taskDetailAddSubtaskFailed);
      return false;
    }
    try {
      await repository.updateTask(
        id,
        TaskChanges(
          relations: RelationChange(
            added: {TaskRelationRef(TaskRelationKind.parentTask, parent.id)},
          ),
        ),
      );
    } on Object catch (error) {
      _log.warning('Linking a new subtask failed: ${error.runtimeType}');
      if (mounted) _showMessage(l10n.taskDetailSubtaskNotLinked);
    }
    return true;
  }

  Future<void> _addRelation(TaskRepository repository, Task task) async {
    final relation = await pickRelation(context, task: task);
    if (relation == null) return;
    await repository.updateTask(
      task.id,
      TaskChanges(relations: RelationChange(added: {relation})),
    );
  }

  /// The server removes both directions of the relation.
  Future<void> _removeRelation(
    TaskRepository repository,
    Task task,
    TaskRelationKind kind,
    Task other,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.taskRelationRemoveTitle,
      body: l10n.taskRelationRemoveBody(other.title),
      confirmLabel: l10n.taskRelationRemoveConfirm,
      destructive: true,
    );
    if (!confirmed) return;
    await repository.updateTask(
      task.id,
      TaskChanges(
        relations: RelationChange(removed: {TaskRelationRef(kind, other.id)}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final repository = ref.watch(taskRepositoryProvider);
    final stored = ref.watch(taskByIdProvider(widget.task.id)).value;
    final task = stored ?? widget.task;
    // A queued create named by the server while the sheet is open.
    ref.listen(taskByIdProvider(widget.task.id), (_, next) {
      final id = next.value?.id;
      if (id != null && id > 0 && _details.id != id) _loadDetails(id);
    });
    final project = ref.watch(projectByIdProvider(task.projectId));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectTitles = {
      for (final project in projects) project.id: project.displayTitle(l10n),
    };
    // The server refuses every task write in an archived project, also
    // below an archived parent; a task shown only from the server (a link
    // to one this device has not synced yet) has no row to queue on. The
    // same holds for its attachments.
    final descriptionWriter =
        repository != null &&
            stored != null &&
            !isArchivedInTree(task.projectId, {
              for (final project in projects) project.id: project,
            })
        ? repository
        : null;
    String? otherProjectTitle(Task other) => other.projectId == task.projectId
        ? null
        : projectTitles[other.projectId];
    final pending =
        ref
            .watch(pendingTaskIdsProvider)
            .unwrapPrevious()
            .value
            ?.contains(task.id) ??
        false;
    final repeat = formatRepeat(l10n, task);
    final percent = (task.percentDone * 100).round();
    final color = parseHexColor(task.hexColor);
    final checklist = checklistStatistics(task.description);
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockTickProvider);
    _Attribute dateAttribute(
      IconData icon,
      String label,
      DateTime moment, {
      TextStyle? style,
    }) => _Attribute.text(
      icon: icon,
      label: label,
      text: formatter.absolute(moment),
      semanticsText: formatter.semanticsLabel(moment),
      style: style,
    );
    final attributes = [
      if (task.dueDate case final dueDate?)
        dateAttribute(
          Icons.event_outlined,
          l10n.taskDetailDueDate,
          dueDate,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: switch (DueTone.of(task, now: now)) {
              DueTone.overdue => colors.error,
              DueTone.today => colors.primary,
              DueTone.later => colors.onSurface,
              DueTone.done => colors.onSurfaceVariant,
            },
          ),
        ),
      if (task.startDate case final startDate?)
        dateAttribute(
          Icons.play_arrow_outlined,
          l10n.taskDetailStartDate,
          startDate,
        ),
      if (task.endDate case final endDate?)
        dateAttribute(Icons.stop_outlined, l10n.taskDetailEndDate, endDate),
      if (task.priority != TaskPriority.unset)
        _Attribute(
          icon: Icons.flag_outlined,
          label: l10n.taskDetailPriority,
          value: (_) => _PriorityValue(priority: task.priority),
        ),
      if (percent > 0)
        _Attribute.text(
          icon: Icons.percent,
          label: l10n.taskDetailProgress,
          text: l10n.taskPercentDone(percent),
        ),
      if (repeat != null)
        _Attribute.text(
          icon: Icons.repeat,
          label: l10n.taskDetailRepeat,
          text: repeat,
        ),
      if (task.reminders.isNotEmpty)
        _Attribute.text(
          icon: Icons.alarm_outlined,
          label: l10n.taskDetailReminders,
          text: [
            for (final reminder in task.reminders)
              formatReminder(
                l10n,
                reminder,
                formatAbsolute: formatter.absolute,
              ),
          ].join('\n'),
          semanticsText: [
            for (final reminder in task.reminders)
              formatReminder(
                l10n,
                reminder,
                formatAbsolute: formatter.spokenAbsolute,
              ),
          ].join('\n'),
        ),
      if (task.labels.isNotEmpty)
        _Attribute(
          icon: Icons.label_outline,
          label: l10n.taskDetailLabels,
          value: (alignment) => Wrap(
            alignment: alignment,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in rowLabels(task.labels))
                LabelPill(label: label),
            ],
          ),
        ),
      if (task.assignees.isNotEmpty)
        _Attribute(
          icon: Icons.people_outline,
          label: l10n.taskDetailAssignees,
          value: (alignment) => Wrap(
            alignment: alignment,
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final user in task.assignees) _Assignee(user: user),
            ],
          ),
        ),
    ];

    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([_details, _comments]),
            builder: (context, _) {
              final details = switch (_details.value) {
                TaskDetailsLoaded(:final details) when task.id > 0 => details,
                _ => null,
              };
              return ListView(
                controller: widget.scrollController,
                // iOS has no other way to close the keyboard of the subtask
                // field, which keeps it up for the next one.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 4,
                    ),
                    child: Row(
                      children: [
                        if (color != null) ...[
                          ColorDot(color: color),
                          const SizedBox(width: 8),
                        ],
                        // A task not yet sent has no identifier until the
                        // server assigns one. Beside five actions in large
                        // text it shrinks rather than break in two.
                        Expanded(
                          child: task.id > 0
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: IdentifierText(
                                    taskIdentifierIn(task, project),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        IconButton(
                          onPressed: repository == null
                              ? null
                              : () => _edit(task),
                          tooltip: l10n.taskEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        ValueListenableBuilder(
                          valueListenable: _follow,
                          builder: (context, state, _) => FollowButton(
                            state: task.id < 0 ? const FollowUnknown() : state,
                            onPressed: () =>
                                unawaited(_toggleFollow(task, projectTitles)),
                          ),
                        ),
                        FavouriteButton(
                          isFavorite: task.isFavorite,
                          onChanged: repository == null
                              ? null
                              : (favorite) => unawaited(
                                  writeTaskFavorite(
                                    repository,
                                    task,
                                    favorite: favorite,
                                  ),
                                ),
                        ),
                        PopupMenuButton<_SheetAction>(
                          tooltip: l10n.moreActions,
                          enabled: repository != null,
                          onSelected: (action) => switch (action) {
                            _SheetAction.duplicate => unawaited(
                              _duplicate(repository!, task),
                            ),
                            _SheetAction.delete => unawaited(
                              _delete(repository!, task),
                            ),
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _SheetAction.duplicate,
                              enabled: !_duplicating,
                              child: Row(
                                children: [
                                  const Icon(Icons.content_copy_outlined),
                                  const SizedBox(width: 12),
                                  Flexible(child: Text(l10n.taskDuplicate)),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: _SheetAction.delete,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      l10n.taskDelete,
                                      style: TextStyle(color: colors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: l10n.taskDetailClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 4,
                    child: _duplicating || _openingLinkedTask
                        ? const LinearProgressIndicator()
                        : null,
                  ),
                  _Inset(
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (project != null)
                          ProjectBreadcrumb(
                            path: projectPath(project, projects),
                            onOpen: (project) =>
                                unawaited(_openProject(project)),
                          ),
                        Text(
                          task.done ? l10n.taskDone : l10n.taskDetailStatusOpen,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (pending) const _PendingNote(),
                      ],
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _follow,
                    builder: (context, state, _) => switch (state) {
                      FollowKnown(:final subscription?)
                          when task.id > 0 && _follow.inherits(subscription) =>
                        _Inset(
                          child: _InheritedFollowNote(
                            projectTitle: projectTitles[subscription.entityId],
                          ),
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                  const SizedBox(height: 4),
                  _Inset(
                    child: _Title(
                      task: task,
                      onEdit: repository == null ? null : () => _edit(task),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Inset(
                    child: _DoneButton(
                      done: task.done,
                      onPressed: repository == null
                          ? null
                          : () => unawaited(
                              writeTaskDone(repository, task, done: !task.done),
                            ),
                    ),
                  ),
                  if (attributes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SectionCard(children: attributes),
                  ],
                  if (task.parentTasks.isNotEmpty)
                    ParentTasksBlock(
                      parents: inCreationOrder(task.parentTasks),
                      projectTitleOf: otherProjectTitle,
                      onOpen: _open,
                      onRemove: repository == null
                          ? null
                          : (parent) => unawaited(
                              _removeRelation(
                                repository,
                                task,
                                TaskRelationKind.parentTask,
                                parent,
                              ),
                            ),
                    ),
                  if (task.subtasks.isNotEmpty || repository != null)
                    SubtasksSection(
                      // Keeps the typed title and the focus when rows above
                      // come or go, such as the pending note.
                      key: const ValueKey('subtasks'),
                      subtasks: inCreationOrder(task.subtasks),
                      projectTitleOf: otherProjectTitle,
                      onOpen: _open,
                      onDoneChanged: repository == null
                          ? null
                          : (subtask, {required done}) => unawaited(
                              writeTaskDone(repository, subtask, done: done),
                            ),
                      onRemove: repository == null
                          ? null
                          : (subtask) => unawaited(
                              _removeRelation(
                                repository,
                                task,
                                TaskRelationKind.subtask,
                                subtask,
                              ),
                            ),
                      onAdd: repository == null
                          ? null
                          : (title) => _addSubtask(repository, task, title),
                    ),
                  DetailSectionHeader(
                    title: l10n.taskDetailDescription,
                    trailing: checklist.total > 0
                        ? ChecklistSummary(statistics: checklist, style: null)
                        : null,
                    actions: [
                      if (descriptionWriter != null && hasDescription(task))
                        IconButton(
                          onPressed: () => unawaited(_editDescription(task)),
                          tooltip: l10n.taskDetailEditDescription,
                          icon: const Icon(Icons.edit_note),
                        ),
                    ],
                  ),
                  SectionCard(
                    children: [
                      _Description(
                        task: task,
                        onLink: _openLink,
                        onTaskLink: (taskId) =>
                            unawaited(_openLinkedTask(taskId)),
                        onAdd: descriptionWriter == null
                            ? null
                            : () => unawaited(_editDescription(task)),
                        onToggleTaskItem: descriptionWriter == null
                            ? null
                            : (html, item) => unawaited(
                                _toggleChecklistItem(
                                  descriptionWriter,
                                  task,
                                  html,
                                  item,
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (details != null && details.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: ReactionChips(reactions: details.reactions),
                    ),
                  if (_details.value case TaskDetailsFailed(:final failure)
                      when task.id > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: DetailsNotice(
                        text: (l10n) => failure is NetworkFailure
                            ? l10n.taskDetailDetailsOffline
                            : l10n.taskDetailDetailsFailed,
                        onRetry: () => _retryDetails(task.id),
                      ),
                    ),
                  TaskAttachmentsSection(
                    task: task,
                    details: details,
                    controller: _details,
                    writable: descriptionWriter != null,
                    onMessage: _showMessage,
                  ),
                  RelatedTasksSection(
                    task: task,
                    projectTitleOf: otherProjectTitle,
                    onOpen: _open,
                    onRemove: repository == null
                        ? null
                        : (kind, other) => unawaited(
                            _removeRelation(repository, task, kind, other),
                          ),
                    onAdd: repository == null
                        ? null
                        : () => unawaited(_addRelation(repository, task)),
                  ),
                  if (details != null && details.commentCount > 0)
                    ...commentsSection(
                      count: details.commentCount,
                      state: _comments.value,
                      controller: _comments,
                      onLink: _openLink,
                      onTaskLink: (taskId) =>
                          unawaited(_openLinkedTask(taskId)),
                      projectId: task.projectId,
                    ),
                  const SizedBox(height: 16),
                  _Inset(child: TaskMetadataLine(task: task)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Inset extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
}

/// The title, which opens the edit page; one node with the heading, its
/// tap and the hint.
class _Title extends StatelessWidget {
  const new({required this.task, required this.onEdit});

  final Task task;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall;
    return MergeSemantics(
      child: Semantics(
        header: true,
        button: onEdit != null,
        hint: onEdit == null ? null : l10n.taskEdit,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              task.title,
              style: task.done
                  ? style?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : style,
            ),
          ),
        ),
      ),
    );
  }
}

/// The done toggle as a full-width button: filled while the task is open,
/// outlined once it is done.
class _DoneButton extends StatelessWidget {
  const new({required this.done, required this.onPressed});

  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filled = Theme.of(context).filledButtonTheme.style;
    return SizedBox(
      width: double.infinity,
      child: done
          ? OutlinedButton.icon(
              onPressed: onPressed,
              // The filled button's size, so a toggle moves nothing below.
              style: ButtonStyle(
                minimumSize: filled?.minimumSize,
                textStyle: filled?.textStyle,
              ),
              icon: const Icon(Icons.undo),
              label: Text(l10n.taskDetailMarkNotDone),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.check),
              label: Text(l10n.taskDetailMarkDone),
            ),
    );
  }
}

/// Selectable rich text whose checkboxes take taps when [onToggleTaskItem]
/// is set; without visible content "Add description" when [onAdd] is set,
/// else "No description".
class _Description extends StatelessWidget {
  const new({
    required this.task,
    required this.onLink,
    required this.onTaskLink,
    required this.onAdd,
    required this.onToggleTaskItem,
  });

  final Task task;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final VoidCallback? onAdd;
  final void Function(String html, RichTaskItem item)? onToggleTaskItem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onAdd = this.onAdd;
    final empty = onAdd == null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.taskDetailNoDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        // The button's own padding lines its icon up with the card's text.
        : Padding(
            padding: const EdgeInsets.all(4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.taskDetailAddDescription),
              ),
            ),
          );
    if (!hasDescription(task)) return empty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        child: RichHtml(
          html: task.description,
          onLink: onLink,
          onTaskLink: onTaskLink,
          onToggleTaskItem: onToggleTaskItem,
          style: theme.textTheme.bodyLarge,
          projectId: task.projectId,
          empty: empty,
        ),
      ),
    );
  }
}

class _InheritedFollowNote extends StatelessWidget {
  const new({required this.projectTitle});

  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(switch (projectTitle) {
              final title? => l10n.followingViaProject(title),
              null => l10n.followingViaSomeProject,
            }, style: style),
          ),
        ],
      ),
    );
  }
}

class _PendingNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.l10n.taskNotYetSynced,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of the attribute card: an icon, the name in a column of its
/// own and the value at the end; the value goes under the name when the
/// two do not fit side by side, as at a large text size. [value] gets the
/// alignment of the side it is on.
class _Attribute extends StatelessWidget {
  const new({required this.icon, required this.label, required this.value});

  factory text({
    required IconData icon,
    required String label,
    required String text,
    String? semanticsText,
    TextStyle? style,
  }) => _Attribute(
    icon: icon,
    label: label,
    value: (alignment) => Text(
      text,
      semanticsLabel: semanticsText,
      style: style,
      textAlign: alignment == WrapAlignment.end
          ? TextAlign.end
          : TextAlign.start,
    ),
  );

  final IconData icon;
  final String label;
  final Widget Function(WrapAlignment alignment) value;

  static const _labelWidth = 96.0;
  static const _minValueWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelWidth = MediaQuery.textScalerOf(context).scale(_labelWidth);
    final name = Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
    final glyph = Icon(icon, size: 20, color: colors.onSurfaceVariant);
    return MergeSemantics(
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide =
                    constraints.maxWidth - 20 - 16 - labelWidth - 16 >=
                    _minValueWidth;
                if (!sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: glyph,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [name, value(WrapAlignment.start)],
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    glyph,
                    const SizedBox(width: 16),
                    SizedBox(width: labelWidth, child: name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: value(WrapAlignment.end),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The priority with its flag: in the error colour from urgent up, amber
/// for high, muted below.
class _PriorityValue extends StatelessWidget {
  const new({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (priority.value) {
      >= 4 => (Icons.flag, colors.error),
      3 => (Icons.flag, HighlightColors.of(context).highlight),
      _ => (Icons.outlined_flag, colors.onSurfaceVariant),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            priorityLabel(context.l10n, priority),
            style: priority.value >= 4 ? TextStyle(color: colors.error) : null,
          ),
        ),
      ],
    );
  }
}

class _Assignee extends StatelessWidget {
  const new({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      UserAvatar(user: user, radius: 12),
      const SizedBox(width: 6),
      Flexible(child: Text(user.displayName)),
    ],
  );
}
