import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _log = Logger('TaskDetails');

sealed class TaskDetailsState {
  const new();
}

/// Nothing asked yet: a task whose create is still queued has no details
/// on the server.
final class TaskDetailsIdle extends TaskDetailsState {
  const new();
}

final class TaskDetailsLoading extends TaskDetailsState {
  const new();
}

final class TaskDetailsLoaded extends TaskDetailsState {
  const new(this.details);

  final TaskDetails details;
}

/// Offline included.
final class TaskDetailsFailed extends TaskDetailsState {
  const new(this.failure);

  final Object failure;
}

/// What the server has beyond the stored row (attachments, reactions, the
/// comment count, unread, subscription), read once when the sheet opens
/// and again on Retry, when a queued create got its server id or when the
/// task changed on the server; changes made here to the attachments, the
/// reactions and the comments apply at once. A refresh under way when one
/// of them comes may have read the server before it, so it is dropped and
/// read again once [writing] has nothing pending. A result that says the
/// task is unread marks it read, fire and forget.
final class TaskDetailsController extends ValueNotifier<TaskDetailsState> {
  new({required this._read, required this._markRead})
    : super(const TaskDetailsIdle());

  final Future<TaskDetails> Function(int taskId) _read;
  final Future<void> Function(int taskId) _markRead;
  int? _id;
  int _generation = 0;
  int? _refreshing;
  int _writes = 0;
  bool _refreshDue = false;
  bool _disposed = false;

  int? get id => _id;

  /// The read, whose failure is also in [value]; the follow bell takes
  /// its subscription from it.
  Future<TaskDetails> load(int taskId) {
    _id = taskId;
    final generation = ++_generation;
    _set(const TaskDetailsLoading());
    final request = Future.sync(() => _read(taskId));
    unawaited(
      request.then(
        (details) {
          if (generation != _generation) return;
          _set(TaskDetailsLoaded(details));
          if (details.isUnread) unawaited(_markReadQuietly(taskId));
        },
        onError: (Object error) {
          _log.fine('Loading task details failed: ${error.runtimeType}');
          if (generation == _generation) _set(TaskDetailsFailed(error));
        },
      ),
    );
    return request;
  }

  /// Reads the details again while the current ones stay in [value]; a
  /// failure keeps them. Unread again means a comment came in while the
  /// sheet was open, in front of the user, so it is marked read too.
  Future<void> refresh() async {
    final taskId = _id;
    if (taskId == null) return;
    if (_writes > 0) {
      _refreshDue = true;
      return;
    }
    final generation = _refreshing = ++_generation;
    try {
      final details = await _read(taskId);
      if (generation != _generation) return;
      _set(TaskDetailsLoaded(details));
      if (details.isUnread) unawaited(_markReadQuietly(taskId));
    } on Object catch (error) {
      _log.fine('Refreshing task details failed: ${error.runtimeType}');
    } finally {
      if (_refreshing == generation) _refreshing = null;
    }
  }

  /// Runs [write], which changes on the server what a change made here
  /// already shows: refreshes wait until it is done.
  Future<T> writing<T>(Future<T> Function() write) async {
    _writes++;
    _dropRefresh();
    try {
      return await write();
    } finally {
      _writes--;
      _refreshIfDue();
    }
  }

  /// An attachment the server has now, shown without a read.
  void addAttachment(TaskAttachment attachment) => _change((details) {
    if (attachment.taskId != _id ||
        details.attachments.any((known) => known.id == attachment.id)) {
      return null;
    }
    return _withAttachments(details, [...details.attachments, attachment]);
  });

  /// The server deleted the attachment, and with it the cover if it was.
  void removeAttachment(int attachmentId) => _change(
    (details) => _withAttachments(
      details,
      [
        for (final attachment in details.attachments)
          if (attachment.id != attachmentId) attachment,
      ],
      cover: details.coverImageAttachmentId == attachmentId
          ? 0
          : details.coverImageAttachmentId,
    ),
  );

  /// The task's cover is [attachmentId] now; 0 for none.
  void setCover(int attachmentId) => _change(
    (details) =>
        _withAttachments(details, details.attachments, cover: attachmentId),
  );

  void setReactions(Reactions reactions) =>
      _change((details) => details.copyWith(reactions: reactions));

  /// A comment written ([by] 1) or deleted ([by] -1) here.
  void countComments(int by) => _change(
    (details) =>
        details.copyWith(commentCount: math.max(0, details.commentCount + by)),
  );

  void _change(TaskDetails? Function(TaskDetails details) change) {
    if (value case TaskDetailsLoaded(:final details)) {
      if (change(details) case final changed?) {
        _set(TaskDetailsLoaded(changed));
        _dropRefresh();
      }
    }
  }

  void _dropRefresh() {
    if (_refreshing == null || _refreshing != _generation) return;
    _refreshing = null;
    _generation++;
    _refreshDue = true;
    _refreshIfDue();
  }

  void _refreshIfDue() {
    if (_writes > 0 || !_refreshDue || _disposed) return;
    _refreshDue = false;
    unawaited(refresh());
  }

  static TaskDetails _withAttachments(
    TaskDetails details,
    List<TaskAttachment> attachments, {
    int? cover,
  }) =>
      details.copyWith(attachments: attachments, coverImageAttachmentId: cover);

  Future<void> _markReadQuietly(int taskId) async {
    try {
      await _markRead(taskId);
    } on Object catch (error) {
      _log.fine('Marking a task read failed: ${error.runtimeType}');
    }
  }

  void _set(TaskDetailsState state) {
    if (!_disposed) value = state;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
