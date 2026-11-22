import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/subscriber_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';
import 'package:vikunja_mobile/features/common/presentation/local_change.dart';
import 'package:vikunja_mobile/features/inbox/application/local_task_lookup.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/reaction_toggle.dart';
import 'package:vikunja_mobile/features/tasks/presentation/delete_task_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

final _log = Logger('TaskDetail');

/// Where the detail shows, as of each read: in the pane beside the list,
/// whose `paneDeleted` leaves the task with that id once it is deleted, or
/// in a sheet (null) over the screen whose messenger is `messengerBelow`.
typedef TaskDetailPlace = ({
  void Function(int taskId)? paneDeleted,
  GlobalKey<ScaffoldMessengerState>? messengerBelow,
});

/// The detail's actions on its task: done with its Undo, delete with the
/// bin's Undo, duplicate, follow and reactions. They ask through the
/// sheet's context and say what happened in the sheet's own messenger, or
/// below the sheet once it has gone. Notifies while a duplicate or a
/// reaction is under way.
final class TaskDetailActions extends ChangeNotifier {
  new({
    required this._context,
    required this._ref,
    required this._messenger,
    required this._place,
    required this._details,
    required this._comments,
    required this._showMessage,
    required this._save,
    required this._open,
  });

  final BuildContext _context;
  final WidgetRef _ref;
  final GlobalKey<ScaffoldMessengerState> _messenger;
  final TaskDetailPlace Function() _place;
  final TaskDetailsController _details;
  final CommentsController _comments;
  final ValueChanged<String> _showMessage;

  /// A write stored on this device, else said in the sheet that it was not.
  final Future<bool> Function(String action, Future<void> Function() write)
  _save;

  /// Another task's detail, over this one or in the pane.
  final ValueChanged<Task> _open;

  late final follow = FollowController(
    entity: SubscriptionEntity.task,
    read: (id) => _subscriptions().forTask(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setTaskSubscribed(id, subscribed: subscribed),
    optOuts: () => _ref.read(activeServerHasFollowOptOutsProvider),
  );
  final _pendingTaskReactions = <String>{};
  final _pendingCommentReactions = <int, Set<String>>{};
  bool _duplicating = false;
  int? _undoTaskId;

  /// Shows the Undo that is up below the sheet once the sheet goes.
  VoidCallback? _handOverUndo;

  bool get duplicating => _duplicating;

  /// The task's reactions waiting for the server.
  Set<String> get pendingTaskReactions =>
      UnmodifiableSetView(_pendingTaskReactions);

  /// Per comment, the reactions waiting for the server.
  Map<int, Set<String>> get pendingCommentReactions =>
      UnmodifiableMapView(_pendingCommentReactions);

  @override
  void dispose() {
    if (_handOverUndo case final handOver?) {
      // The tree is locked while it unmounts the sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) => handOver());
    }
    follow.dispose();
    super.dispose();
  }

  SubscriptionRepository _subscriptions() =>
      _ref.read(subscriptionRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  /// A done shows the lists' "Marked as done · Undo" in the sheet; its Undo
  /// gives a repeating [task] its dates and reminders back. Reopening the
  /// task whose Undo is up makes that Undo moot. A sheet closed while it is
  /// up hands it to what is below, as the row may have left the list there;
  /// the pane keeps it in its own messenger.
  Future<void> setDone(
    TaskRepository repository,
    Task task, {
    required bool done,
  }) async {
    final messenger = _messenger.currentState;
    final l10n = _context.l10n;
    if (!done) {
      if (_undoTaskId == task.id) {
        _undoTaskId = null;
        _handOverUndo = null;
        messenger?.hideCurrentSnackBar();
      }
      await _save(
        'Reopening a task',
        () => writeTaskDone(repository, task, done: false),
      );
      return;
    }
    final saved = await _save(
      'Marking a task done',
      () => writeTaskDone(repository, task, done: true),
    );
    if (!saved || !_context.mounted || messenger == null) return;
    // The sheet may have gone by the time Undo is tapped below it.
    void undo() => unawaited(
      saveLocalChangeIn(
        messenger,
        l10n,
        () => writeTaskUndo(repository, task),
        action: 'Undoing a done',
      ),
    );
    _undoTaskId = task.id;
    _handOverUndo = _place().paneDeleted == null ? _undoBelow(undo) : null;
    await showMarkedDoneSnackBar(_context, messenger: messenger, onUndo: undo);
    if (_undoTaskId == task.id) {
      _undoTaskId = null;
      _handOverUndo = null;
    }
  }

  VoidCallback _undoBelow(VoidCallback onUndo) {
    final below = _place().messengerBelow;
    final screenMessenger = ScaffoldMessenger.maybeOf(_context);
    final l10n = _context.l10n;
    final persist = MediaQuery.accessibleNavigationOf(_context);
    return () {
      final messenger = below?.currentState ?? screenMessenger;
      if (messenger == null || !messenger.mounted) return;
      unawaited(
        showMarkedDoneSnackBarIn(
          messenger,
          l10n: l10n,
          persist: persist,
          onUndo: onUndo,
        ),
      );
    };
  }

  /// A subtask comes without its reminders, which the Undo of a repeating
  /// one puts back, so the stored task is what a done undoes.
  Future<void> setSubtaskDone(
    TaskRepository repository,
    Task subtask, {
    required bool done,
  }) async {
    var task = subtask;
    if (done) {
      try {
        task = await findLocalTask(repository, subtask.id) ?? subtask;
      } on Object catch (error) {
        _log.warning('Reading a subtask failed: ${error.runtimeType}');
      }
      if (!_context.mounted) return;
    }
    await setDone(repository, task, done: done);
  }

  /// The sheet closes, so its "Task deleted" lands on what is below it; in
  /// the pane it shows on the screen beside it. On a server with the bin a
  /// queued delete can be undone from there; a task with a temporary id
  /// is said to go to the bin only as far as the server may have it.
  Future<void> delete(TaskRepository repository, Task task) async {
    final trash = _ref.read(activeServerHasTrashProvider);
    final guest = _ref.read(activeAccountIsGuestProvider);
    final l10n = _context.l10n;
    final navigator = Navigator.of(_context);
    final screenMessenger = ScaffoldMessenger.of(_context);
    final persist = MediaQuery.accessibleNavigationOf(_context);
    final onServer = trash && task.id < 0
        ? await _onServer(repository, task.id)
        : TaskOnServer.yes;
    if (!_context.mounted) return;
    final confirmed = await confirmDeleteTask(
      _context,
      title: task.title,
      trash: trash,
      guest: guest,
      onServer: onServer,
    );
    if (!confirmed || !_context.mounted) return;
    late final TaskDeletion deletion;
    final deleted = await _save('Deleting a task', () async {
      deletion = await repository.deleteTask(task.id);
    });
    if (!deleted || !_context.mounted) return;
    // A done of the deleted task has nothing left to undo.
    _handOverUndo = null;
    // Gone while the dialog was up: a sync removed it, or its delete was
    // queued already. Nothing was deleted, so nothing is said to be.
    if (deletion == TaskDeletion.none) {
      _showMessage(l10n.taskDeleteGone);
      return;
    }
    final place = _place();
    final ScaffoldMessengerState messenger;
    if (place.paneDeleted case final paneDeleted?) {
      paneDeleted(task.id);
      messenger = screenMessenger;
    } else {
      messenger = place.messengerBelow?.currentState ?? screenMessenger;
      navigator.pop();
    }
    if (!trash) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.taskDeleted)));
      return;
    }
    final undoable = deletion == TaskDeletion.queued;
    showDeletedSnackBar(
      messenger,
      text: undoable && task.id > 0 ? l10n.taskMovedToTrash : l10n.taskDeleted,
      undoLabel: l10n.undo,
      persist: persist,
      onUndo: undoable
          ? () => unawaited(
              runUndo(
                messenger,
                l10n,
                restore: () => repository.restoreTask(task.id),
                restored: l10n.taskRestored,
                action: TrashAction.restoreTask,
              ),
            )
          : null,
    );
  }

  Future<void> duplicate(TaskRepository repository, Task task) async {
    final l10n = _context.l10n;
    _duplicating = true;
    notifyListeners();
    try {
      final copyId = await repository.duplicateTask(task.id);
      if (!_context.mounted) return;
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
            persist: MediaQuery.accessibleNavigationOf(_context),
            action: SnackBarAction(
              label: l10n.taskDuplicateOpen,
              onPressed: () => _open(copy),
            ),
          ),
        );
    } on Object catch (error) {
      _log.warning('Duplicating a task failed: ${error.runtimeType}');
      if (_context.mounted) _showMessage(taskDuplicateFailureText(l10n, error));
    } finally {
      if (_context.mounted) {
        _duplicating = false;
        notifyListeners();
      }
    }
  }

  /// A change that went through is said, as the project's follow is; an
  /// unfollow also says that the task no longer notifies where the server
  /// reminds only its followers (D80).
  Future<void> toggleFollow(Task task, Map<int, String> projectTitles) async {
    final l10n = _context.l10n;
    if (task.id < 0) {
      _showMessage(l10n.followTaskOnceSynced);
      return;
    }
    final before = follow.value;
    final message = await toggleFollowing(
      _context,
      follow,
      id: task.id,
      projectTitle: (id) => projectTitles[id] ?? l10n.projectUnknownTitle,
    );
    if (!_context.mounted) return;
    final silenced =
        _ref.read(accountsProvider).value?.activeAccount?.subscriberId != null;
    final text =
        message ??
        switch ((before, follow.value)) {
          (FollowKnown(following: false), FollowKnown(following: true)) =>
            l10n.taskFollowed,
          (FollowKnown(following: true), FollowKnown(following: false)) =>
            silenced ? l10n.taskUnfollowedSilenced : l10n.taskUnfollowed,
          _ => null,
        };
    if (text != null) _showMessage(text);
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
    final repository = _ref.read(taskDetailsRepositoryProvider);
    final me = _ref.read(activeUserProvider);
    final before = current();
    if (repository == null ||
        me == null ||
        before == null ||
        pending.contains(value)) {
      return;
    }
    final l10n = _context.l10n;
    pending.add(value);
    notifyListeners();
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
          if (_context.mounted) {
            _showMessage(commentFailureText(l10n, error, CommentWrite.react));
          }
        }
      });
    } finally {
      if (_context.mounted) {
        pending.remove(value);
        notifyListeners();
      }
    }
  }

  Reactions? _taskReactions() => switch (_details.value) {
    TaskDetailsLoaded(:final details) => details.reactions,
    _ => null,
  };

  Future<void> reactToTask(Task task, String value, {bool? add}) async {
    final reactions = _taskReactions();
    final me = _ref.read(activeUserIdProvider);
    if (reactions == null || me == null) return;
    final mine = reactedWith(reactions, value, me);
    if (add == true && mine) return;
    await _react(
      kind: ReactionEntity.task,
      id: task.id,
      value: value,
      add: add ?? !mine,
      current: _taskReactions,
      apply: _details.setReactions,
      writing: _details.writing,
      pending: _pendingTaskReactions,
    );
  }

  Future<void> reactToComment(
    TaskComment comment,
    String value, {
    bool? add,
  }) async {
    final reactions = _comments.find(comment.id)?.reactions;
    final me = _ref.read(activeUserIdProvider);
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

  /// The reaction picker, then [react] with what was picked.
  Future<void> pickThenReact(Future<void> Function(String value) react) async {
    final value = await pickReaction(_context);
    if (value != null && _context.mounted) await react(value);
  }
}

/// A create that cannot be read counts as one the server may have: that
/// text promises nothing.
Future<TaskOnServer> _onServer(TaskRepository repository, int taskId) async {
  try {
    return await repository.taskOnServer(taskId);
  } on Object catch (error) {
    _log.warning('Reading a create failed: ${error.runtimeType}');
    return TaskOnServer.maybe;
  }
}

String taskDuplicateFailureText(AppLocalizations l10n, Object error) {
  final shared = actionFailureText(l10n, error);
  final notSent = notSentFailureText(l10n, error);
  return switch (error) {
    _ when notSent != null => notSent,
    NetworkFailure() => l10n.taskDuplicateNeedsConnection,
    TaskNotSyncedYet() => l10n.taskDuplicateNotSynced,
    Forbidden() => l10n.taskDuplicateForbidden,
    NotFound(code: 4034) => l10n.taskDuplicateFileMissing,
    NotFound(taskGone: true) => l10n.syncProblemTaskMissing,
    NotFound(projectGone: true) => l10n.syncProblemProjectMissing,
    VikunjaFailure(code: 3008) => l10n.taskDuplicateArchived,
    _ when shared != null => shared,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.taskDuplicateFailed(message.trim()),
    _ => l10n.taskDuplicateFailedUnknown,
  };
}
