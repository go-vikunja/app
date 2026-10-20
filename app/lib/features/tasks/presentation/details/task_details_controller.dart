import 'dart:async';

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
/// and again on Retry or when a queued create got its server id; changes
/// made here to the attachments apply at once. A result that says the task
/// is unread marks it read, fire and forget.
final class TaskDetailsController extends ValueNotifier<TaskDetailsState> {
  new({required this._read, required this._markRead})
    : super(const TaskDetailsIdle());

  final Future<TaskDetails> Function(int taskId) _read;
  final Future<void> Function(int taskId) _markRead;
  int? _id;
  int _generation = 0;
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
  /// failure keeps them.
  Future<void> refresh() async {
    final taskId = _id;
    if (taskId == null) return;
    final generation = ++_generation;
    try {
      final details = await _read(taskId);
      if (generation == _generation) _set(TaskDetailsLoaded(details));
    } on Object catch (error) {
      _log.fine('Refreshing task details failed: ${error.runtimeType}');
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

  void _change(TaskDetails? Function(TaskDetails details) change) {
    if (value case TaskDetailsLoaded(:final details)) {
      if (change(details) case final changed?) {
        _set(TaskDetailsLoaded(changed));
      }
    }
  }

  static TaskDetails _withAttachments(
    TaskDetails details,
    List<TaskAttachment> attachments, {
    int? cover,
  }) => TaskDetails(
    attachments: attachments,
    coverImageAttachmentId: cover ?? details.coverImageAttachmentId,
    reactions: details.reactions,
    commentCount: details.commentCount,
    isUnread: details.isUnread,
    subscription: details.subscription,
  );

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
