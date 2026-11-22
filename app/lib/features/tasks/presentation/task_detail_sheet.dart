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
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/platform/copy_confirmation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/local_change.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/common/presentation/share_web_link.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';
import 'package:vikunja_mobile/features/tasks/application/relation_search.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/application/task_write_access.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_card.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/description_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_menu.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/move_to_column.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_detail_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_metadata_line.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/add_relation_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/related_tasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/subtasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_link_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

final _log = Logger('TaskDetail');

/// Shows what this device knows about [task] and, online, what only the
/// server has (attachments, reactions, comments, whether the user follows
/// it). [messengerBelow] is the messenger of the sheet this one opens over,
/// see [TaskDetailSheet.messengerBelow]; [commentId] is a comment to show,
/// see [TaskDetailSheet.commentId]; [board] is the board whose card opened
/// it, see [TaskDetailSheet.board].
Future<void> showTaskDetail(
  BuildContext context, {
  required Task task,
  GlobalKey<ScaffoldMessengerState>? messengerBelow,
  int? commentId,
  TaskBoardOrigin? board,
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
          board: board,
        ),
      );
    case _:
      return showModalBottomSheet<void>(
        context: context,
        barrierLabel: sheetBarrierLabel(context),
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
          board: board,
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
    required this.board,
  });

  final Task task;
  final GlobalKey<ScaffoldMessengerState>? messengerBelow;
  final int? commentId;
  final TaskBoardOrigin? board;

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
      board: widget.board,
      expand: _expand,
    ),
  );
}

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
/// on the server; a read that fails is one line with Retry, above what was
/// last read where that stays (offline, a failure that may pass) and says
/// as of when. Comments are written in a field pinned below the list,
/// which keeps an unsent one as a draft. Messages about what happens in
/// the sheet show inside it.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const new({
    required this.task,
    required this.scrollController,
    this.messengerBelow,
    this.commentId,
    this.board,
    this.expand,
    this.pane,
    super.key,
  });

  final Task task;
  final ScrollController scrollController;

  /// The board whose card opened the detail; null elsewhere.
  final TaskBoardOrigin? board;

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
  late final TaskDetailActions _actions;
  late final _details = TaskDetailsController(
    read: (id) => _detailsRepository().details(id),
    markRead: (id) => _detailsRepository().markRead(id),
    stored: (id) => _detailsRepository().storedDetails(id),
  );
  late final _comments = CommentsController(
    read: (id, {required page, required newestFirst}) =>
        _detailsRepository().comments(id, page: page, newestFirst: newestFirst),
    stored: (id) => _detailsRepository().storedComments(id),
  );
  late final _composer = CommentComposerController()
    ..addListener(_composerChanged);
  // Read up front: an unsent comment is kept also while the sheet goes.
  late final CommentDrafts _drafts;
  late final String? _account;
  late final TaskWriteAccess _access;
  final GlobalKey _commentsHeader = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final _columnMoves = ColumnMoves();
  // As of the last build: Move to column… plans against it once picked.
  ColumnMoveChoice? _moveChoice;
  final _commentKeys = <int, GlobalKey>{};
  final _busyComments = <int>{};
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
  ScaffoldMessengerState? _screenMessenger;

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(commentDraftsProvider);
    _account = ref.read(activeAccountIdProvider);
    _access = ref.read(taskWriteAccessProvider);
    _actions = TaskDetailActions(
      context: context,
      ref: ref,
      messenger: _messenger,
      place: () => (
        paneDeleted: widget.pane?.deleted,
        messengerBelow: widget.messengerBelow,
      ),
      details: _details,
      comments: _comments,
      showMessage: _showMessage,
      save: _save,
      open: _open,
    );
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenMessenger = ScaffoldMessenger.maybeOf(context);
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
    _actions.dispose();
    _details.dispose();
    _comments.dispose();
    _composer.dispose();
    super.dispose();
  }

  TaskDetailsRepository _detailsRepository() =>
      ref.read(taskDetailsRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  /// One read for the details and the follow bell.
  void _loadDetails(int taskId) {
    _comments.forTask(taskId);
    final details = _details.load(taskId);
    unawaited(
      _actions.follow.load(
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
      // In a long thread this reads the pages up to its end.
      await _comments.add(comment, wasEmpty: wasEmpty);
      if (!mounted) {
        showBelow(l10n.commentPosted);
        return;
      }
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

  /// [link] to the web, confirmed with [copied]. A task link carries no
  /// secret, so the plain clipboard does. Android 13 and later confirm a
  /// copy themselves.
  Future<void> _copyLink(Uri link, String copied) async {
    final l10n = context.l10n;
    final systemConfirms = ref.read(systemConfirmsCopiesProvider.future);
    try {
      await Clipboard.setData(ClipboardData(text: '$link'));
    } on Object catch (error) {
      _log.info('Copying a link failed: ${error.runtimeType}');
      if (mounted) _showMessage(l10n.copyToClipboardFailed);
      return;
    }
    final confirmed = await systemConfirms;
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    if (confirmed) {
      announce(context, copied);
    } else {
      _showMessage(copied);
    }
  }

  /// Before a full-screen editor opens: the field that had the focus would
  /// get it back on return and the keyboard would cover what was edited.
  /// Unfocusing the field itself also clears the sheet's focus history; a
  /// menu that just closed hands the focus back in a microtask first. A
  /// row or button a keyboard user is on keeps the focus to come back to.
  Future<void> _dropFieldFocus() async {
    await Future<void>.delayed(Duration.zero);
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.findAncestorStateOfType<EditableTextState>() != null) {
      focus!.unfocus();
    }
  }

  /// A picker over the sheet, after which the comment field would take the
  /// focus back and bring up the keyboard.
  Future<void> _editInPlace(Future<void> Function() edit) async {
    await _dropFieldFocus();
    if (mounted) await edit();
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

  void _announceComments() {
    final before = _commentsBefore;
    final after = _commentsBefore = _comments.value;
    // Also runs from initState, where no inherited widget may be read.
    if (!mounted || !before.loading || after.loading) return;
    final message = commentsResultAnnouncement(
      context.l10n,
      before: before,
      after: after,
      now: ref.read(clockProvider)(),
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

  void _retryOffline(int taskId) {
    syncActiveAccountNow(ref);
    if (taskId > 0) _retryDetails(taskId);
    if (_comments.value.storedAt != null) unawaited(_comments.retry());
  }

  void _showMessage(String text) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// For what is said once the sheet (or the pane) has gone.
  void _showMessageBelow(String text) {
    final messenger = widget.messengerBelow?.currentState ?? _screenMessenger;
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  /// [write] stored on this device, else said in the sheet that it was not.
  Future<bool> _save(String action, Future<void> Function() write) =>
      saveLocalChange(
        context,
        write,
        action: action,
        messenger: _messenger.currentState,
      );

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
      if (mounted) _showMessage(l10n.localChangeFailed);
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
    if (await popPagesOverShell(router) != LeaveOutcome.left) return;
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
    if (relation == null || !mounted) return;
    await _save(
      'Adding a relation',
      () => repository.updateTask(
        task.id,
        TaskChanges(relations: RelationChange(added: {relation})),
      ),
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
    if (!confirmed || !mounted) return;
    await _save(
      'Removing a relation',
      () => repository.updateTask(
        task.id,
        TaskChanges(
          relations: RelationChange(removed: {TaskRelationRef(kind, other.id)}),
        ),
      ),
    );
  }

  /// What the menu offered may be gone by the time it closes; [context] is
  /// the one it was built in.
  void _onMenu(
    BuildContext context,
    TaskDetailMenuAction action, {
    required Task task,
    required TaskRepository? changer,
    required AccountLinkBases? linkBases,
  }) {
    switch (action) {
      case TaskDetailMenuAction.moveToColumn:
        if (changer == null) return;
        unawaited(
          _editInPlace(
            () => moveToColumn(
              context,
              repository: changer,
              task: task,
              choice: () => _moveChoice,
              showMessage: _showMessage,
            ),
          ),
        );
      case TaskDetailMenuAction.copyLink:
        if (linkBases == null) return;
        unawaited(
          _copyLink(linkBases.taskLink(task.id), context.l10n.taskLinkCopied),
        );
      case TaskDetailMenuAction.share:
        if (linkBases == null) return;
        unawaited(
          shareWebLink(
            _menuKey.currentContext ?? context,
            ref,
            url: linkBases.taskLink(task.id),
            subject: task.title,
          ),
        );
      case TaskDetailMenuAction.duplicate:
        if (changer != null) unawaited(_actions.duplicate(changer, task));
      case TaskDetailMenuAction.delete:
        if (changer != null) unawaited(_actions.delete(changer, task));
    }
  }

  /// Reply, Edit and Delete with [canComment], reactions with [mayReact],
  /// and Copy link where the task has a link to the web.
  CommentActions _commentActions(
    Task task, {
    required int? me,
    required bool offline,
    required AccountLinkBases? linkBases,
    required bool canComment,
    required bool mayReact,
  }) {
    final l10n = context.l10n;
    return CommentActions(
      me: me,
      offline: offline,
      onCopyLink: linkBases == null || task.id <= 0
          ? null
          : (comment) => unawaited(
              _copyLink(
                linkBases.taskLink(task.id, commentId: comment.id),
                l10n.commentLinkCopied,
              ),
            ),
      onReply: canComment ? _reply : null,
      onEdit: canComment
          ? (comment) => unawaited(_editComment(task, comment))
          : null,
      onDelete: canComment
          ? (comment) => unawaited(_deleteComment(task, comment))
          : null,
      onToggleReaction: mayReact
          ? (comment, value) =>
                unawaited(_actions.reactToComment(comment, value))
          : null,
      onAddReaction: mayReact
          ? (comment) => unawaited(
              _actions.pickThenReact(
                (value) => _actions.reactToComment(comment, value, add: true),
              ),
            )
          : null,
      busy: _busyComments,
      pendingReactions: _actions.pendingCommentReactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final pane = widget.pane;
    final repository = ref.watch(taskRepositoryProvider);
    final storedValue = ref.watch(taskByIdProvider(widget.task.id));
    final stored = storedValue.value;
    // While it loads the row counts as there, so nothing flickers.
    final rowMissing = storedValue.hasValue && stored == null;
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
    final origin = widget.board;
    final boardSource = origin == null
        ? null
        : ref.watch(boardSourceProvider(origin.projectId, origin.viewId)).value;
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
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockTickProvider);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([_details, _comments, _actions]),
            builder: (context, _) {
              final loaded = switch (_details.value) {
                final TaskDetailsLoaded loaded when task.id > 0 => loaded,
                _ => null,
              };
              final details = loaded?.details;
              // Stored details carry no permission of their own.
              final answered = loaded?.storedAt == null ? details : null;
              // Until the details arrive (or when they leave it open), the
              // permission the last sync stored for the project, which
              // follows changes on the web; an earlier read in this run of
              // the app only where the server stores none.
              final writable =
                  answered?.maxPermission?.canWrite ??
                  (projectAccess.isKnown ? projectAccess.canWrite : null) ??
                  switch (_account) {
                    final account? => _access.writable(account, task.id),
                    null => null,
                  } ??
                  (answered == null ? null : _writable(answered));
              final readOnly = writable == false;
              // Every task write in a read-only or archived project would
              // end as a sync problem; one for a task without a row (a sync
              // removed it, or it is read from the server only) would be
              // dropped.
              final locked = readOnly || archived;
              final changer = locked || rowMissing ? null : repository;
              // A subtask may live in another project.
              bool subtaskReadOnly(Task subtask) =>
                  subtask.projectId == task.projectId
                  ? locked
                  : switch (projectsById[subtask.projectId]) {
                      final project? =>
                        isArchivedInTree(subtask.projectId, projectsById) ||
                            !ProjectAccess.of(project).canChangeTasks,
                      null => false,
                    };
              final moveChoice = origin == null || changer == null
                  ? null
                  : _columnMoves.choiceFor(
                      task,
                      origin: origin,
                      source: boardSource,
                      archived: archived,
                      writable: writable != false,
                    );
              _moveChoice = moveChoice;
              VoidCallback? inPlace(
                Future<void> Function(TaskRepository editor) edit,
              ) => switch (changer) {
                final editor? => () => unawaited(
                  _editInPlace(() => edit(editor)),
                ),
                null => null,
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
                  switch (_details.value) {
                    TaskDetailsLoading() => true,
                    TaskDetailsLoaded(storedAt: _?, failure: null) => true,
                    _ => false,
                  };
              final commentsNote = commentsOffered && task.id > 0
                  ? archived
                        ? l10n.commentsArchivedNote
                        : readOnly
                        ? l10n.commentsReadOnlyNote
                        : null
                  : null;
              final moves = moveChoice != null;
              final links = linkBases != null && task.id > 0;
              final header = TaskDetailHeader(
                task: task,
                project: project,
                projects: projects,
                onOpenProject: (project) => unawaited(_openProject(project)),
                onBack: pane?.back,
                backTitle: pane?.backTitle,
                locked: locked,
                onEdit: changer == null ? null : () => _edit(task),
                guest: guest,
                follow: _actions.follow,
                onFollow: () =>
                    unawaited(_actions.toggleFollow(task, projectTitles)),
                onFavoriteChanged: changer == null
                    ? null
                    : (favorite) => unawaited(
                        _save(
                          'Changing a favorite',
                          () => writeTaskFavorite(
                            changer,
                            task,
                            favorite: favorite,
                          ),
                        ),
                      ),
                menu: moves || links || changer != null
                    ? TaskDetailMenu(
                        buttonKey: _menuKey,
                        moves: moves,
                        links: links,
                        changes: changer != null,
                        duplicating: _actions.duplicating,
                        inPane: pane != null,
                        taskTitle: task.title,
                        onSelected: (action) => _onMenu(
                          context,
                          action,
                          task: task,
                          changer: changer,
                          linkBases: linkBases,
                        ),
                      )
                    : null,
                onClose: pane?.close ?? () => Navigator.of(context).pop(),
              );
              final progress = SizedBox(
                height: 4,
                child: _actions.duplicating || _openingLinkedTask
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
                  InheritedFollowNote(
                    follow: _actions.follow,
                    taskId: task.id,
                    projectTitles: projectTitles,
                  ),
                  const SizedBox(height: 4),
                  _Inset(
                    child: TaskDetailTitle(
                      task: task,
                      onEdit: changer == null ? null : () => _edit(task),
                    ),
                  ),
                  _Inset(
                    child: TaskStatusLine(done: task.done, pending: pending),
                  ),
                  // The shell's banner is under the sheet.
                  if (offline && pane == null)
                    _Inset(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OfflineNotice(
                          onRetry: () => _retryOffline(task.id),
                        ),
                      ),
                    ),
                  if (details != null &&
                      (details.reactions.isNotEmpty || mayReact))
                    _Inset(
                      child: ReactionChips(
                        reactions: details.reactions,
                        offline: offline,
                        onToggle: mayReact
                            ? (value) =>
                                  unawaited(_actions.reactToTask(task, value))
                            : null,
                        onAdd: mayReact
                            ? () => unawaited(
                                _actions.pickThenReact(
                                  (value) => _actions.reactToTask(
                                    task,
                                    value,
                                    add: true,
                                  ),
                                ),
                              )
                            : null,
                        pending: _actions.pendingTaskReactions,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!locked)
                    _Inset(
                      child: TaskDoneButton(
                        done: task.done,
                        onPressed: changer == null
                            ? null
                            : () => unawaited(
                                _actions.setDone(
                                  changer,
                                  task,
                                  done: !task.done,
                                ),
                              ),
                      ),
                    ),
                  ...attributeSection(
                    context,
                    task: task,
                    formatter: formatter,
                    now: now,
                    onOpenLabel: _openLabel,
                    onChangeDueDate: inPlace(
                      (editor) => editDueDate(
                        context,
                        repository: editor,
                        task: task,
                        now: ref.read(clockProvider)(),
                        display: ref.read(displaySettingsProvider),
                      ),
                    ),
                    onChangePriority: inPlace(
                      (editor) =>
                          editPriority(context, repository: editor, task: task),
                    ),
                    onChangeReminders: inPlace(
                      (editor) => editReminders(
                        context,
                        repository: editor,
                        taskId: task.id,
                      ),
                    ),
                    onChangeLabels: inPlace(
                      (editor) =>
                          editLabels(context, repository: editor, task: task),
                    ),
                    onAddReminder: inPlace(
                      (editor) => addReminder(
                        context,
                        repository: editor,
                        task: task,
                        now: ref.read(clockProvider)(),
                        showMessage: _showMessage,
                      ),
                    ),
                  ),
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
                              _actions.setSubtaskDone(
                                repository,
                                subtask,
                                done: done,
                              ),
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
                  ...descriptionSection(
                    task: task,
                    onLink: _openLink,
                    onTaskLink: (taskId) => unawaited(_openLinkedTask(taskId)),
                    onEdit: descriptionWriter == null || readOnly
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
                  if (_details.value case TaskDetailsFailed(:final failure)
                      when task.id > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: DetailsNotice(
                        text: (l10n) => failedOnTheNetwork(failure)
                            ? l10n.taskDetailDetailsOffline
                            : l10n.taskDetailDetailsFailed,
                        onRetry: () => _retryDetails(task.id),
                      ),
                    )
                  else if (loaded case TaskDetailsLoaded(
                    storedAt: final at?,
                    :final failure?,
                  ))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: DetailsNotice(
                        text: (l10n) {
                          final when = storedWhen(l10n, at, now: now);
                          return failedOnTheNetwork(failure)
                              ? l10n.taskDetailDetailsStored(when)
                              : l10n.taskDetailDetailsStoredFailed(when);
                        },
                        onRetry: () => _retryDetails(task.id),
                      ),
                    ),
                  TaskAttachmentsSection(
                    task: task,
                    details: details,
                    controller: _details,
                    writable: descriptionWriter != null && !readOnly,
                    offline: offline,
                    onMessage: _showMessage,
                    onMessageAfterClose: _showMessageBelow,
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
                      now: now,
                      controller: _comments,
                      onLink: _openLink,
                      onTaskLink: (taskId) =>
                          unawaited(_openLinkedTask(taskId)),
                      projectId: task.projectId,
                      actions: _commentActions(
                        task,
                        me: me,
                        offline: offline,
                        linkBases: linkBases,
                        canComment: canComment,
                        mayReact: mayReact,
                      ),
                      headerKey: _commentsHeader,
                      keyOf: _commentKey,
                      highlighted: _highlighted,
                    ),
                  if (commentsNote != null)
                    _Inset(child: CommentsNote(text: commentsNote)),
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
