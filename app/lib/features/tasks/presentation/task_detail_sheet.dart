import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/platform/copy_confirmation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';
import 'package:vikunja_mobile/features/tasks/application/reaction_toggle.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/application/task_write_access.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/delete_task_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_header_layout.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_picker.dart';
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
/// see [TaskDetailSheet.messengerBelow]; [commentId] is a comment to show,
/// see [TaskDetailSheet.commentId].
Future<void> showTaskDetail(
  BuildContext context, {
  required Task task,
  GlobalKey<ScaffoldMessengerState>? messengerBelow,
  int? commentId,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showReadableCupertinoSheet<void>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => TaskDetailSheet(
          task: task,
          scrollController: scrollController,
          messengerBelow: messengerBelow,
          commentId: commentId,
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
        builder: (context) => _DraggableTaskDetail(
          task: task,
          messengerBelow: messengerBelow,
          commentId: commentId,
        ),
      );
  }
}

/// The Android sheet, which grows to its full height when the comment
/// field gets the focus: at its first height the keyboard would leave the
/// list next to no room.
class _DraggableTaskDetail extends StatefulWidget {
  const new({
    required this.task,
    required this.messengerBelow,
    required this.commentId,
  });

  final Task task;
  final GlobalKey<ScaffoldMessengerState>? messengerBelow;
  final int? commentId;

  @override
  State<_DraggableTaskDetail> createState() => _DraggableTaskDetailState();
}

class _DraggableTaskDetailState extends State<_DraggableTaskDetail> {
  static const _fullSize = 0.95;
  final _sheet = DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _expand() {
    if (!_sheet.isAttached || _sheet.size >= _fullSize - 0.01) return;
    // Not animateTo with a zero duration, which it refuses.
    if (reduceMotionOf(context)) {
      _sheet.jumpTo(_fullSize);
      return;
    }
    _sheet.animateTo(
      _fullSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    controller: _sheet,
    expand: false,
    initialChildSize: 0.65,
    minChildSize: 0.3,
    maxChildSize: _fullSize,
    builder: (context, scrollController) => TaskDetailSheet(
      task: widget.task,
      scrollController: scrollController,
      messengerBelow: widget.messengerBelow,
      commentId: widget.commentId,
      expand: _expand,
    ),
  );
}

enum _SheetAction { duplicate, delete }

/// What the detail does in the pane beside the list instead of in a sheet:
/// [close] closes the pane, [openOther] shows another task inside it,
/// [back] (null on the pane's first task) returns to [backTitle]'s task,
/// and [deleted] leaves the task with that id once it is deleted.
final class TaskDetailPaneHost {
  const new({
    required this.close,
    required this.openOther,
    required this.deleted,
    this.back,
    this.backTitle,
  });

  final VoidCallback close;
  final void Function(Task task) openOther;
  final void Function(int taskId) deleted;
  final VoidCallback? back;
  final String? backTitle;
}

/// Follows the local row of [task] while it is open, so a done toggle here,
/// the server's answer to it (a repeating task's next occurrence) and the
/// id a queued create gets show; [task] itself is the fallback once the row
/// is gone. Its project is watched too. What only the server has is read
/// on opening and again, with the comments shown, whenever the task changes
/// on the server; offline the sheet says so in one line and shows the
/// rest. Comments are written in a field pinned below the list, which
/// keeps an unsent one as a draft. Messages about what happens in the
/// sheet show inside it.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const new({
    required this.task,
    required this.scrollController,
    this.messengerBelow,
    this.commentId,
    this.expand,
    this.pane,
    super.key,
  });

  final Task task;
  final ScrollController scrollController;

  /// Set in the pane beside the list; null in a sheet.
  final TaskDetailPaneHost? pane;

  /// A comment to show, e.g. the one a notification is about: the comments
  /// load and the sheet scrolls to it, tinted for a moment, when it is on
  /// the first page, else to the comments.
  final int? commentId;

  /// Grows the sheet to its full height; null where it always is.
  final VoidCallback? expand;

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
  late final _composer = CommentComposerController()
    ..addListener(_composerChanged);
  // Read up front: an unsent comment is kept also while the sheet goes.
  late final CommentDrafts _drafts;
  late final String? _account;
  late final TaskWriteAccess _access;
  final GlobalKey _commentsHeader = GlobalKey();
  final _commentKeys = <int, GlobalKey>{};
  final _busyComments = <int>{};
  final _pendingTaskReactions = <String>{};
  final _pendingCommentReactions = <int, Set<String>>{};
  bool _duplicating = false;
  bool _openingLinkedTask = false;
  CommentsState _commentsBefore = const CommentsState();
  StreamSubscription<TaskAttachment>? _uploaded;
  StreamSubscription<DateTime>? _serverChanges;
  late int? _commentToShow = widget.commentId;
  int? _highlighted;
  Timer? _highlightEnd;
  Timer? _draftWrite;
  CommentComposerDraft? _keptDraft;
  bool _draftAsked = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(commentDraftsProvider);
    _account = ref.read(activeAccountIdProvider);
    _access = ref.read(taskWriteAccessProvider);
    _comments.addListener(_announceComments);
    _details.addListener(_rememberAccess);
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
    // A comment by anyone moves the task's `updated`, and the sync brings
    // that here; reactions do not.
    ref.listenManual(taskDetailsRepositoryProvider, (_, repository) {
      unawaited(_serverChanges?.cancel());
      _serverChanges = repository
          ?.watchServerChanges(widget.task.id)
          .listen((_) => _refreshFromServer());
    }, fireImmediately: true);
    if (widget.task.id > 0) _loadDetails(widget.task.id);
  }

  // Before a detail for the same task that replaces this one in the same
  // frame reads the draft in its initState.
  @override
  void deactivate() {
    if (_draftWrite != null) unawaited(_keepDraft());
    super.deactivate();
  }

  @override
  void dispose() {
    unawaited(_uploaded?.cancel());
    unawaited(_serverChanges?.cancel());
    _highlightEnd?.cancel();
    if (_draftWrite != null) unawaited(_keepDraft());
    _follow.dispose();
    _details.dispose();
    _comments.dispose();
    _composer.dispose();
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
    unawaited(_restoreDraft(taskId));
    if (_commentToShow case final commentId?) {
      _commentToShow = null;
      unawaited(
        details.then((_) => _showComment(commentId), onError: (Object _) {}),
      );
    }
  }

  void _refreshFromServer() {
    unawaited(_details.refresh());
    unawaited(_comments.refreshLoaded());
  }

  TaskDetails? _loadedDetails() => switch (_details.value) {
    TaskDetailsLoaded(:final details) => details,
    _ => null,
  };

  void _rememberAccess() {
    final account = _account;
    final taskId = _details.id;
    // Only what the server said: an unknown one must not hide the
    // permission the sync stored for the project.
    final writable = _loadedDetails()?.maxPermission?.canWrite;
    if (account == null || taskId == null || writable == null) return;
    _access.remember(account, taskId, writable: writable);
  }

  // v1 servers do not say; the server refuses what the user may not do.
  static bool _writable(TaskDetails details) =>
      details.maxPermission?.canWrite ?? true;

  /// Loads the comments and scrolls to [commentId], else to the comments.
  Future<void> _showComment(int commentId) async {
    widget.expand?.call();
    await _comments.show();
    // The section shows once the details are in this frame's build.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final found = _comments.find(commentId) != null;
    await _scrollTo(found ? _commentKey(commentId) : _commentsHeader);
    if (!found || !mounted) return;
    _highlightEnd?.cancel();
    setState(() => _highlighted = commentId);
    _highlightEnd = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlighted = null);
    });
  }

  GlobalKey _commentKey(int commentId) =>
      _commentKeys.putIfAbsent(commentId, GlobalKey.new);

  /// The list builds its rows as they come near, so it moves on until the
  /// row of [key] exists, from the top again once it reached the end.
  Future<void> _scrollTo(GlobalKey key) async {
    final scroll = widget.scrollController;
    var fromTop = false;
    for (var step = 0; step < 200 && key.currentContext == null; step++) {
      if (!scroll.hasClients) return;
      final position = scroll.position;
      if (position.pixels >= position.maxScrollExtent) {
        if (fromTop) break;
        fromTop = true;
        position.jumpTo(position.minScrollExtent);
      } else {
        position.jumpTo(
          math.min(
            position.pixels + position.viewportDimension * 0.8,
            position.maxScrollExtent,
          ),
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final row = key.currentContext;
    if (row == null || !row.mounted) return;
    await Scrollable.ensureVisible(
      row,
      alignment: 0.1,
      duration: reduceMotionOf(row)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// The task's unsent comment, unless something was typed meanwhile.
  Future<void> _restoreDraft(int taskId) async {
    final account = _account;
    if (account == null || _draftAsked) return;
    _draftAsked = true;
    try {
      final draft = await _drafts.read(account: account, taskId: taskId);
      if (draft == null || !mounted || !_composer.isEmpty) return;
      _keptDraft = draft;
      _restoringDraft = true;
      try {
        _composer.restore(draft);
      } finally {
        _restoringDraft = false;
      }
    } on Object catch (error) {
      _log.warning('Reading a comment draft failed: ${error.runtimeType}');
    }
  }

  void _composerChanged() {
    if (_restoringDraft) return;
    _draftWrite?.cancel();
    _draftWrite = Timer(const Duration(milliseconds: 500), () {
      unawaited(_keepDraft());
    });
  }

  Future<void> _keepDraft() async {
    _draftWrite?.cancel();
    _draftWrite = null;
    final account = _account;
    final taskId = _details.id;
    if (account == null || taskId == null || taskId <= 0) return;
    final draft = _composer.toDraft();
    if (draft == _keptDraft || (draft.isEmpty && _keptDraft == null)) return;
    _keptDraft = draft;
    try {
      await _drafts.save(draft, account: account, taskId: taskId);
    } on Object catch (error) {
      _log.warning('Keeping a comment draft failed: ${error.runtimeType}');
    }
  }

  /// The sheet may close before the server answers: the draft goes all the
  /// same, and what happened shows below.
  Future<void> _sendComment(Task task) async {
    final repository = ref.read(taskDetailsRepositoryProvider);
    if (repository == null || _composer.isBlank || _composer.sending) return;
    final l10n = context.l10n;
    final account = _account;
    final drafts = _drafts;
    final below = widget.messengerBelow;
    final screenMessenger = ScaffoldMessenger.maybeOf(context);
    void showBelow(String text) => (below?.currentState ?? screenMessenger)
        ?.showSnackBar(SnackBar(content: Text(text)));
    final wasEmpty = _loadedDetails()?.commentCount == 0;
    _composer.sending = true;
    try {
      final comment = await repository.addComment(
        task.id,
        CommentDraft(_composer.html()),
      );
      _draftWrite?.cancel();
      _draftWrite = null;
      // After any save of the text still queued, e.g. the closing sheet's.
      if (account != null) {
        unawaited(
          drafts
              .discard(account: account, taskId: task.id)
              .catchError(
                (Object error) => _log.warning(
                  'Dropping a sent comment draft failed: ${error.runtimeType}',
                ),
              ),
        );
      }
      if (!mounted) {
        showBelow(l10n.commentPosted);
        return;
      }
      _keptDraft = null;
      _composer.clear();
      _details.countComments(1);
      await _comments.add(comment, wasEmpty: wasEmpty);
      if (!mounted) return;
      announce(context, l10n.commentPosted);
      unawaited(_details.refresh());
      if (_comments.find(comment.id) != null) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) await _scrollTo(_commentKey(comment.id));
      }
    } on Object catch (error) {
      _log.info('Sending a comment failed: ${error.runtimeType}');
      final message = commentFailureText(l10n, error, CommentWrite.send);
      if (mounted) {
        _showMessage(message);
      } else {
        showBelow(message);
      }
    } finally {
      if (mounted) _composer.sending = false;
    }
  }

  /// The focus goes to the field, not the screen reader's, so it hears
  /// what is set up there.
  void _reply(TaskComment comment) {
    _composer.replyTo(
      ComposerReply(
        commentId: comment.id,
        html: comment.html,
        authorName: comment.author.displayName,
      ),
    );
    announce(
      context,
      context.l10n.commentReplyingTo(comment.author.displayName),
    );
    widget.expand?.call();
  }

  /// The web's permalink, which opens the task there at the comment.
  /// Android 13 and later confirm a copy themselves.
  Future<void> _copyLink(
    Task task,
    TaskComment comment,
    AccountLinkBases bases,
  ) async {
    final l10n = context.l10n;
    final systemConfirms = ref.read(systemConfirmsCopiesProvider.future);
    final link = bases.relativeBase
        .resolve('tasks/${task.id}')
        .replace(fragment: 'comment-${comment.id}');
    try {
      await Clipboard.setData(ClipboardData(text: '$link'));
    } on Object catch (error) {
      _log.info('Copying a comment link failed: ${error.runtimeType}');
      if (mounted) _showMessage(l10n.copyToClipboardFailed);
      return;
    }
    final confirmed = await systemConfirms;
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    if (confirmed) {
      announce(context, l10n.commentLinkCopied);
    } else {
      _showMessage(l10n.commentLinkCopied);
    }
  }

  /// Before a full-screen editor opens: the field that had the focus would
  /// get it back on return and the keyboard would cover what was edited.
  /// Unfocusing the field itself also clears the sheet's focus history; a
  /// menu that just closed hands the focus back in a microtask first.
  Future<void> _dropFieldFocus() async {
    await Future<void>.delayed(Duration.zero);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// In the full editor; it comes back with the comment as stored.
  Future<void> _editComment(Task task, TaskComment comment) async {
    final l10n = context.l10n;
    await _dropFieldFocus();
    if (!mounted) return;
    final edited = await context.pushPage<Object>(
      AppRoutes.commentEdit(task.id, comment.id),
      extra: CommentTarget(
        taskId: task.id,
        projectId: task.projectId,
        comment: comment,
      ),
    );
    if (!mounted || edited is! TaskComment) return;
    _comments.applyEdit(edited);
    _showMessage(l10n.commentSaved);
    unawaited(_details.refresh());
  }

  Future<void> _deleteComment(Task task, TaskComment comment) async {
    final repository = ref.read(taskDetailsRepositoryProvider);
    if (repository == null || _busyComments.contains(comment.id)) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.commentDeleteTitle,
      body: l10n.commentDeleteBody,
      confirmLabel: l10n.commentDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyComments.add(comment.id));
    try {
      await repository.deleteComment(task.id, comment.id);
      if (!mounted) return;
      _comments.remove(comment.id);
      _details.countComments(-1);
      _showMessage(l10n.commentDeleted);
      unawaited(_details.refresh());
    } on Object catch (error) {
      _log.info('Deleting a comment failed: ${error.runtimeType}');
      if (!mounted) return;
      _showMessage(commentFailureText(l10n, error, CommentWrite.delete));
      // The server answers a failed write as a missing comment too: what
      // it has decides whether the comment stays.
      if (error is NotFound ||
          (error is ServerFailure && error.statusCode == 404)) {
        unawaited(_comments.refreshLoaded());
      }
    } finally {
      if (mounted) setState(() => _busyComments.remove(comment.id));
    }
  }

  /// At once here, then on the server; undone here when that fails. The
  /// controller showing it reads nothing from the server meanwhile.
  Future<void> _react({
    required ReactionEntity kind,
    required int id,
    required String value,
    required bool add,
    required Reactions? Function() current,
    required void Function(Reactions reactions) apply,
    required Future<void> Function(Future<void> Function() write) writing,
    required Set<String> pending,
  }) async {
    final repository = ref.read(taskDetailsRepositoryProvider);
    final me = ref.read(activeUserProvider);
    final before = current();
    if (repository == null ||
        me == null ||
        before == null ||
        pending.contains(value)) {
      return;
    }
    final l10n = context.l10n;
    setState(() => pending.add(value));
    try {
      await writing(() async {
        final optimistic = toggledReaction(before, value, me: me, add: add);
        apply(optimistic);
        try {
          if (add) {
            await repository.addReaction(kind, id, value);
          } else {
            await repository.removeReaction(kind, id, value);
          }
        } on Object catch (error) {
          _log.info('Changing a reaction failed: ${error.runtimeType}');
          // Back to where the user was, unless a read brought news meanwhile.
          if (current() case final now?) {
            apply(
              reactionsEqual(now, optimistic)
                  ? before
                  : toggledReaction(now, value, me: me, add: !add),
            );
          }
          if (mounted) {
            _showMessage(commentFailureText(l10n, error, CommentWrite.react));
          }
        }
      });
    } finally {
      if (mounted) setState(() => pending.remove(value));
    }
  }

  Future<void> _reactToTask(Task task, String value, {bool? add}) async {
    final reactions = _loadedDetails()?.reactions;
    final me = ref.read(activeUserIdProvider);
    if (reactions == null || me == null) return;
    final mine = reactedWith(reactions, value, me);
    if (add == true && mine) return;
    await _react(
      kind: ReactionEntity.task,
      id: task.id,
      value: value,
      add: add ?? !mine,
      current: () => _loadedDetails()?.reactions,
      apply: _details.setReactions,
      writing: _details.writing,
      pending: _pendingTaskReactions,
    );
  }

  Future<void> _reactToComment(
    TaskComment comment,
    String value, {
    bool? add,
  }) async {
    final reactions = _comments.find(comment.id)?.reactions;
    final me = ref.read(activeUserIdProvider);
    if (reactions == null || me == null) return;
    final mine = reactedWith(reactions, value, me);
    if (add == true && mine) return;
    await _react(
      kind: ReactionEntity.comment,
      id: comment.id,
      value: value,
      add: add ?? !mine,
      current: () => _comments.find(comment.id)?.reactions,
      apply: (reactions) => _comments.setReactions(comment.id, reactions),
      writing: _comments.writing,
      pending: _pendingCommentReactions.putIfAbsent(comment.id, () => {}),
    );
  }

  Future<void> _pickReaction(Future<void> Function(String value) react) async {
    final value = await pickReaction(context);
    if (value != null && mounted) await react(value);
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
    announce(context, message);
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

  /// The sheet closes, so its "Task deleted" lands on what is below it; in
  /// the pane it shows on the screen beside it.
  Future<void> _delete(TaskRepository repository, Task task) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final screenMessenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteTask(context, title: task.title);
    if (!confirmed || !mounted) return;
    await repository.deleteTask(task.id);
    if (!mounted) return;
    if (widget.pane case final pane?) {
      pane.deleted(task.id);
      screenMessenger.showSnackBar(SnackBar(content: Text(l10n.taskDeleted)));
      return;
    }
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

  static String _duplicateFailureText(AppLocalizations l10n, Object error) {
    final shared = actionFailureText(l10n, error);
    return switch (error) {
      NetworkFailure() => l10n.taskDuplicateNeedsConnection,
      TaskNotSyncedYet() => l10n.taskDuplicateNotSynced,
      Forbidden() => l10n.taskDuplicateForbidden,
      NotFound(code: 4034) => l10n.taskDuplicateFileMissing,
      NotFound(code: 4002) => l10n.syncProblemTaskMissing,
      VikunjaFailure(code: 3008) => l10n.taskDuplicateArchived,
      _ when shared != null => shared,
      VikunjaFailure(:final message) when message.trim().isNotEmpty =>
        l10n.taskDuplicateFailed(message.trim()),
      _ => l10n.taskDuplicateFailedUnknown,
    };
  }

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

  /// The edit page replaces the sheet, so its "Saved" lands on the list;
  /// the pane stays under it.
  void _edit(Task task) {
    final router = GoRouter.of(context);
    if (widget.pane == null) Navigator.of(context).pop();
    unawaited(router.push(AppRoutes.taskEdit(task.id)));
  }

  /// The editor opens over the sheet, which comes back with the new
  /// description.
  /// An image inserted in the editor is an attachment by now, whether the
  /// edit was saved or not; the server's task does not say so.
  Future<void> _editDescription(Task task) async {
    final l10n = context.l10n;
    await _dropFieldFocus();
    if (!mounted) return;
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
    announce(
      context,
      checked ? l10n.checklistItemChecked : l10n.checklistItemUnchecked,
    );
  }

  /// Another sheet over this one, which closing brings back; in the pane,
  /// the next task in it, which its back arrow leaves.
  void _open(Task other) {
    if (!mounted) return;
    if (widget.pane case final pane?) {
      pane.openOther(other);
      return;
    }
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

  /// The label's open tasks over the sheet, which going back brings back.
  void _openLabel(Label label) =>
      unawaited(context.pushPage<void>(AppRoutes.labelTasks(label.id)));

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
    final pane = widget.pane;
    final repository = ref.watch(taskRepositoryProvider);
    final stored = ref.watch(taskByIdProvider(widget.task.id)).value;
    final task = stored ?? widget.task;
    // A queued create named by the server while the sheet is open.
    ref.listen(taskByIdProvider(widget.task.id), (_, next) {
      final id = next.value?.id;
      if (id != null && id > 0 && _details.id != id) _loadDetails(id);
    });
    final project = ref.watch(projectByIdProvider(task.projectId));
    final projectAccess = ref.watch(projectAccessProvider(task.projectId));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectTitles = {
      for (final project in projects) project.id: project.displayTitle(l10n),
    };
    final projectsById = {for (final project in projects) project.id: project};
    // The server refuses every task write in an archived project, also
    // below an archived parent; a task shown only from the server (a link
    // to one this device has not synced yet) has no row to queue on. The
    // same holds for its attachments.
    final archived = isArchivedInTree(task.projectId, projectsById);
    final descriptionWriter = repository != null && stored != null && !archived
        ? repository
        : null;
    // Comments and reactions go to the server directly, so a task that is
    // there is enough.
    final onlineWrites =
        ref.watch(taskDetailsRepositoryProvider) != null &&
        task.id > 0 &&
        !archived;
    final commentsOffered = ref.watch(activeServerOffersCommentsProvider);
    final offline = ref.watch(offlineProvider) != null;
    final me = ref.watch(activeUserIdProvider);
    // The server refuses a link-share guest's reactions and subscriptions
    // and ignores its favourites.
    final guest = ref.watch(activeAccountIsGuestProvider);
    final linkBases = ref.watch(activeLinkBasesProvider);
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
      String? semanticsText,
      TextStyle? style,
    }) => _Attribute.text(
      icon: icon,
      label: label,
      text: formatter.absolute(moment),
      semanticsText: semanticsText ?? formatter.semanticsLabel(moment),
      style: style,
    );
    final dueTone = DueTone.of(task, now: now);
    final attributes = [
      if (task.dueDate case final dueDate?)
        dateAttribute(
          dueTone == DueTone.overdue
              ? Icons.error_outline
              : Icons.event_outlined,
          l10n.taskDetailDueDateRow,
          dueDate,
          semanticsText: dueTone == DueTone.overdue
              ? l10n.taskOverdueSemantics(formatter.spokenAbsolute(dueDate))
              : null,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: switch (dueTone) {
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
          merge: false,
          value: (alignment) => Wrap(
            alignment: alignment,
            spacing: 6,
            children: [
              for (final label in rowLabels(task.labels))
                LabelPill(label: label, onTap: () => _openLabel(label)),
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
              // Until the details arrive (or when they leave it open), the
              // permission the last sync stored for the project, which
              // follows changes on the web; an earlier read in this run of
              // the app only where the server stores none.
              final writable =
                  details?.maxPermission?.canWrite ??
                  (projectAccess.isKnown ? projectAccess.canWrite : null) ??
                  switch (_account) {
                    final account? => _access.writable(account, task.id),
                    null => null,
                  } ??
                  (details == null ? null : _writable(details));
              final readOnly = writable == false;
              // Every task write in a read-only project would end as a
              // sync problem.
              final changer = readOnly ? null : repository;
              // A subtask may live in another project.
              bool subtaskReadOnly(Task subtask) =>
                  subtask.projectId == task.projectId
                  ? readOnly
                  : switch (projectsById[subtask.projectId]) {
                      final project? => !ProjectAccess.of(
                        project,
                      ).canChangeTasks,
                      null => false,
                    };
              final mayWrite = onlineWrites && writable == true;
              final mayReact = mayWrite && !guest;
              final canComment = mayWrite && commentsOffered;
              // Shown disabled while the first read is under way, so that
              // the list does not jump for the many who may write.
              final composerWaiting =
                  writable == null &&
                  onlineWrites &&
                  commentsOffered &&
                  !offline &&
                  _details.value is TaskDetailsLoading;
              final commentsNote = commentsOffered && task.id > 0
                  ? archived
                        ? l10n.commentsArchivedNote
                        : readOnly
                        ? l10n.commentsReadOnlyNote
                        : null
                  : null;
              final commentActions = CommentActions(
                me: me,
                offline: offline,
                onCopyLink: linkBases == null || task.id <= 0
                    ? null
                    : (comment) =>
                          unawaited(_copyLink(task, comment, linkBases)),
                onReply: canComment ? _reply : null,
                onEdit: canComment
                    ? (comment) => unawaited(_editComment(task, comment))
                    : null,
                onDelete: canComment
                    ? (comment) => unawaited(_deleteComment(task, comment))
                    : null,
                onToggleReaction: mayReact
                    ? (comment, value) =>
                          unawaited(_reactToComment(comment, value))
                    : null,
                onAddReaction: mayReact
                    ? (comment) => unawaited(
                        _pickReaction(
                          (value) => _reactToComment(comment, value, add: true),
                        ),
                      )
                    : null,
                busy: _busyComments,
                pendingReactions: _pendingCommentReactions,
              );
              final back = pane?.back;
              final header = Padding(
                padding: EdgeInsetsDirectional.only(
                  start: back == null ? 16 : 4,
                  end: 4,
                ),
                child: DetailHeaderLayout(
                  // Below the back arrow, in line with the title.
                  breadcrumbIndent: back == null ? 0 : 12,
                  back: back == null
                      ? null
                      : IconButton(
                          onPressed: back,
                          tooltip: l10n.taskDetailPaneBack(
                            pane?.backTitle ?? '',
                          ),
                          // The tooltip names the task; the icon's own
                          // "Back" would be read before it.
                          icon: const ExcludeSemantics(child: BackButtonIcon()),
                        ),
                  breadcrumb: project == null
                      ? null
                      : ProjectBreadcrumb(
                          path: projectPath(project, projects),
                          onOpen: (project) => unawaited(_openProject(project)),
                        ),
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!readOnly)
                        IconButton(
                          onPressed: repository == null
                              ? null
                              : () => _edit(task),
                          tooltip: l10n.taskEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (!guest) ...[
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
                          onChanged: changer == null
                              ? null
                              : (favorite) => unawaited(
                                  writeTaskFavorite(
                                    changer,
                                    task,
                                    favorite: favorite,
                                  ),
                                ),
                        ),
                      ],
                      if (!readOnly)
                        PopupMenuButton<_SheetAction>(
                          // Beside the screen's own More in the pane.
                          tooltip: pane == null
                              ? l10n.moreActions
                              : l10n.taskDetailPaneMore(task.title),
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
                        onPressed:
                            pane?.close ?? () => Navigator.of(context).pop(),
                        tooltip: l10n.taskDetailClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              );
              final progress = SizedBox(
                height: 4,
                child: _duplicating || _openingLinkedTask
                    ? const LinearProgressIndicator()
                    : null,
              );
              final list = ListView(
                controller: widget.scrollController,
                // iOS has no other way to close the keyboard of the subtask
                // field, which keeps it up for the next one.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (pane == null) ...[header, progress],
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
                      color: color,
                      onEdit: changer == null ? null : () => _edit(task),
                    ),
                  ),
                  _Inset(
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
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
                  if (details != null &&
                      (details.reactions.isNotEmpty || mayReact))
                    _Inset(
                      child: ReactionChips(
                        reactions: details.reactions,
                        offline: offline,
                        onToggle: mayReact
                            ? (value) => unawaited(_reactToTask(task, value))
                            : null,
                        onAdd: mayReact
                            ? () => unawaited(
                                _pickReaction(
                                  (value) =>
                                      _reactToTask(task, value, add: true),
                                ),
                              )
                            : null,
                        pending: _pendingTaskReactions,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!readOnly)
                    _Inset(
                      child: _DoneButton(
                        done: task.done,
                        onPressed: repository == null
                            ? null
                            : () => unawaited(
                                writeTaskDone(
                                  repository,
                                  task,
                                  done: !task.done,
                                ),
                              ),
                      ),
                    ),
                  if (attributes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _AttributeCard(attributes: attributes),
                  ],
                  if (task.parentTasks.isNotEmpty)
                    ParentTasksBlock(
                      parents: inCreationOrder(task.parentTasks),
                      projectTitleOf: otherProjectTitle,
                      onOpen: _open,
                      onRemove: changer == null
                          ? null
                          : (parent) => unawaited(
                              _removeRelation(
                                changer,
                                task,
                                TaskRelationKind.parentTask,
                                parent,
                              ),
                            ),
                    ),
                  if (task.subtasks.isNotEmpty || changer != null)
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
                      isReadOnly: subtaskReadOnly,
                      onRemove: changer == null
                          ? null
                          : (subtask) => unawaited(
                              _removeRelation(
                                changer,
                                task,
                                TaskRelationKind.subtask,
                                subtask,
                              ),
                            ),
                      onAdd: changer == null
                          ? null
                          : (title) => _addSubtask(changer, task, title),
                    ),
                  DetailSectionHeader(
                    title: l10n.taskDetailDescription,
                    trailing: checklist.total > 0
                        ? ChecklistSummary(statistics: checklist, style: null)
                        : null,
                    actions: [
                      if (descriptionWriter != null &&
                          !readOnly &&
                          hasDescription(task))
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
                        onAdd: descriptionWriter == null || readOnly
                            ? null
                            : () => unawaited(_editDescription(task)),
                        onToggleTaskItem: descriptionWriter == null || readOnly
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
                    writable: descriptionWriter != null && !readOnly,
                    onMessage: _showMessage,
                  ),
                  RelatedTasksSection(
                    task: task,
                    projectTitleOf: otherProjectTitle,
                    onOpen: _open,
                    onRemove: changer == null
                        ? null
                        : (kind, other) => unawaited(
                            _removeRelation(changer, task, kind, other),
                          ),
                    onAdd: changer == null
                        ? null
                        : () => unawaited(_addRelation(changer, task)),
                  ),
                  if (details != null &&
                      (commentsOffered || details.commentCount > 0))
                    ...commentsSection(
                      count: details.commentCount,
                      state: _comments.value,
                      controller: _comments,
                      onLink: _openLink,
                      onTaskLink: (taskId) =>
                          unawaited(_openLinkedTask(taskId)),
                      projectId: task.projectId,
                      actions: commentActions,
                      headerKey: _commentsHeader,
                      keyOf: _commentKey,
                      highlighted: _highlighted,
                    ),
                  if (commentsNote != null)
                    _Inset(child: _CommentsNote(text: commentsNote)),
                  const SizedBox(height: 16),
                  _Inset(child: TaskMetadataLine(task: task)),
                ],
              );
              // The composer takes no more than the height above the
              // keyboard, the list what it leaves.
              final content = LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Expanded(child: list),
                    if (canComment || composerWaiting)
                      CommentComposer(
                        controller: _composer,
                        projectId: task.projectId,
                        offline: offline,
                        enabled: canComment,
                        maxHeight: constraints.maxHeight,
                        onSend: () => unawaited(_sendComment(task)),
                        onFocused: widget.expand,
                      ),
                  ],
                ),
              );
              if (pane == null) return content;
              // Close and back stay in reach however far the pane scrolls:
              // there is no drag handle or scrim to leave it by.
              return Column(
                children: [
                  header,
                  progress,
                  Expanded(child: content),
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

/// The title after the task's [color], which opens the edit page; one
/// node with the heading, its tap and the hint.
class _Title extends StatelessWidget {
  const new({required this.task, required this.color, required this.onEdit});

  final Task task;
  final Color? color;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall;
    final title = Text(
      task.title,
      style: task.done
          ? style?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : style,
    );
    return MergeSemantics(
      child: Semantics(
        header: true,
        headingLevel: 1,
        button: onEdit != null,
        hint: onEdit == null ? null : l10n.taskEdit,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: switch (color) {
              null => title,
              final color => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // One line of the title's height, so the dot sits on its
                  // first.
                  ExcludeSemantics(
                    child: Text.rich(
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ColorDot(color: color),
                      ),
                      style: style,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: title),
                ],
              ),
            },
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

/// Why there is no comment field.
class _CommentsNote extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
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

/// The attribute card, whose rows share one column for their names, as
/// wide as the widest name on one line, so that they line up and go from
/// side by side to stacked together.
class _AttributeCard extends StatelessWidget {
  const new({required this.attributes});

  final List<_Attribute> attributes;

  static const _minLabelWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = _Attribute.nameStyle(context);
    final direction = Directionality.of(context);
    double widthOf(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: textScaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Android 14 and later scale text nonlinearly: the minimum grows as the
    // names' own size does, not as a font size of 96.
    final size = style?.fontSize ?? 14;
    final minWidth = _minLabelWidth * textScaler.scale(size) / size;
    final width = attributes
        .map((attribute) => widthOf(attribute.label))
        .fold(minWidth, math.max)
        .ceilToDouble();
    return _NameColumn(
      width: width,
      child: SectionCard(children: attributes),
    );
  }
}

class _NameColumn extends InheritedWidget {
  const new({required this.width, required super.child});

  final double width;

  @override
  bool updateShouldNotify(_NameColumn oldWidget) => width != oldWidget.width;
}

/// One row of the attribute card: an icon, the name in the card's column
/// and the value at the end; the value goes under the name when the two do
/// not fit side by side, as at a large text size. [value] gets the
/// alignment of the side it is on.
class _Attribute extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.value,
    this.merge = true,
  });

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

  /// False when [value] holds buttons, each of which a screen reader must
  /// reach on its own.
  final bool merge;

  static const _minValueWidth = 120.0;

  /// Bold under the platform's bold text setting, as [Text] draws it, so
  /// that the card measures what is drawn.
  static TextStyle? nameStyle(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.boldTextOf(context)
        ? style?.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelWidth = context
        .dependOnInheritedWidgetOfExactType<_NameColumn>()!
        .width;
    final name = Text(label, style: nameStyle(context));
    final glyph = Icon(icon, size: 20, color: colors.onSurfaceVariant);
    final row = DefaultTextStyle.merge(
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
                  // At least the column: a name a fraction wider than
                  // measured takes from the value instead of wrapping.
                  ConstrainedBox(
                    constraints: BoxConstraints(minWidth: labelWidth),
                    child: name,
                  ),
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
    );
    return merge ? MergeSemantics(child: row) : row;
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
