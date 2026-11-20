import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart'
    show StoredRead;
import 'package:vikunja_mobile/features/tasks/presentation/details/refresh_guard.dart';

final _log = Logger('TaskDetails');

/// Whether what the device stored stays, with [failure], once a read of the
/// server failed: for what may pass, such as no connection, a captive
/// portal or a failing proxy, not for a task that is gone or may no longer
/// be read.
bool keepsStored(Object failure) => switch (failure) {
  NetworkFailure() ||
  ServerFailure() ||
  RateLimited() ||
  UnexpectedResponse() ||
  RefreshRaceLost() ||
  TokenRejected() => true,
  _ => false,
};

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
  const new(this.details, {this.storedAt, this.failure});

  final TaskDetails details;

  /// Set while [details] are the ones stored on the device, which the
  /// server answered then; null for its answer of now.
  final DateTime? storedAt;

  /// What kept the server's answer away while the stored ones show
  /// ([keepsStored]); null while it may still come.
  final Object? failure;
}

/// Offline included, when nothing is stored or [failure] does not keep it.
final class TaskDetailsFailed extends TaskDetailsState {
  const new(this.failure);

  final Object failure;
}

typedef StoredDetailsReader = Future<StoredRead<TaskDetails>?> Function(
  int taskId,
);

/// What the server has beyond the stored row (attachments, reactions, the
/// comment count, unread, subscription), read once when the sheet opens
/// and again on Retry, when a queued create got its server id or when the
/// task changed on the server; changes made here to the attachments, the
/// reactions and the comments apply at once. A refresh under way when one
/// of them comes may have read the server before it, so it is dropped and
/// read again once [writing] has nothing pending. A result that says the
/// task is unread marks it read, fire and forget.
///
/// Until the first answer comes, and when it fails for a reason that may
/// pass ([keepsStored]), the details last stored on the device show, if
/// any ([TaskDetailsLoaded.storedAt]); any other failure shows as such.
final class TaskDetailsController extends ValueNotifier<TaskDetailsState> {
  new({required this._read, required this._markRead, this._stored})
    : super(const TaskDetailsIdle());

  final Future<TaskDetails> Function(int taskId) _read;
  final Future<void> Function(int taskId) _markRead;
  final StoredDetailsReader? _stored;
  late final _guard = RefreshGuard(refresh);
  int? _id;

  int? get id => _id;

  /// The read, whose failure is also in [value]; the follow bell takes
  /// its subscription from it. Stored details of the task that show stay
  /// while it runs; a change made here meanwhile drops it like a refresh.
  Future<TaskDetails> load(int taskId) {
    final stored = switch (value) {
      final TaskDetailsLoaded shown
          when taskId == _id && shown.storedAt != null =>
        shown,
      _ => null,
    };
    _id = taskId;
    final generation = ++_guard.generation;
    if (stored != null) {
      _set(TaskDetailsLoaded(stored.details, storedAt: stored.storedAt));
      _guard.refreshing = generation;
    } else {
      _set(const TaskDetailsLoading());
      unawaited(_showStored(taskId, generation));
    }
    final request = Future.sync(() => _read(taskId));
    unawaited(
      request.then(
        (details) {
          if (_guard.refreshing == generation) _guard.refreshing = null;
          if (generation != _guard.generation) return;
          _set(TaskDetailsLoaded(details));
          if (details.isUnread) unawaited(_markReadQuietly(taskId));
        },
        onError: (Object error) {
          if (_guard.refreshing == generation) _guard.refreshing = null;
          _log.fine('Loading task details failed: ${error.runtimeType}');
          if (generation == _guard.generation) _fail(error);
        },
      ),
    );
    return request;
  }

  /// Reads the details again while the current ones stay in [value]; a
  /// failure keeps them, and is the state while none have arrived (the
  /// refresh overtook the first read), so Retry shows. Unread again means a
  /// comment came in while the sheet was open, in front of the user, so it
  /// is marked read too.
  Future<void> refresh() async {
    final taskId = _id;
    if (taskId == null) return;
    if (_guard.hasWrites) {
      _guard.markDue();
      return;
    }
    final generation = _guard.refreshing = ++_guard.generation;
    try {
      final details = await _read(taskId);
      if (generation != _guard.generation) return;
      _set(TaskDetailsLoaded(details));
      if (details.isUnread) unawaited(_markReadQuietly(taskId));
    } on Object catch (error) {
      _log.fine('Refreshing task details failed: ${error.runtimeType}');
      final answered = switch (value) {
        TaskDetailsLoaded(storedAt: null) => true,
        _ => false,
      };
      if (generation == _guard.generation && !answered) _fail(error);
    } finally {
      if (_guard.refreshing == generation) _guard.refreshing = null;
    }
  }

  void _fail(Object error) {
    if (keepsStored(error)) {
      if (value case TaskDetailsLoaded(:final details, storedAt: final at?)) {
        _set(TaskDetailsLoaded(details, storedAt: at, failure: error));
        return;
      }
    }
    _set(TaskDetailsFailed(error));
  }

  /// Shows what is stored while the read runs, or once it failed for a
  /// reason that keeps it.
  Future<void> _showStored(int taskId, int generation) async {
    final read = _stored;
    if (read == null) return;
    final StoredRead<TaskDetails>? stored;
    try {
      stored = await read(taskId);
    } on Object catch (error) {
      _log.warning('Reading stored task details failed: ${error.runtimeType}');
      return;
    }
    if (stored == null || generation != _guard.generation) return;
    switch (value) {
      case TaskDetailsLoading():
        _set(TaskDetailsLoaded(stored.value, storedAt: stored.readAt));
        _guard.refreshing = generation;
      case TaskDetailsFailed(:final failure) when keepsStored(failure):
        _set(
          TaskDetailsLoaded(
            stored.value,
            storedAt: stored.readAt,
            failure: failure,
          ),
        );
      case _:
    }
  }

  /// Runs [write], which changes on the server what a change made here
  /// already shows: refreshes wait until it is done.
  Future<T> writing<T>(Future<T> Function() write) => _guard.writing(write);

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
    if (value case final TaskDetailsLoaded shown) {
      if (change(shown.details) case final changed?) {
        _set(
          TaskDetailsLoaded(
            changed,
            storedAt: shown.storedAt,
            failure: shown.failure,
          ),
        );
        _guard.drop();
      }
    }
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
    if (!_guard.disposed) value = state;
  }

  @override
  void dispose() {
    _guard.dispose();
    super.dispose();
  }
}
