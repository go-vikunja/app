import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

final _log = Logger('Outbox');

typedef CreateTimer = Timer Function(
  Duration duration,
  void Function() callback,
);

enum OutboxSenderState {
  /// Nothing queued, or the queue has not been looked at since the last
  /// local write.
  idle,
  draining,

  /// The oldest op waits for its backoff; a timer continues the drain.
  waiting,

  /// The session ended; [OutboxSender.resume] after a new sign-in.
  paused,
}

/// Sends one account's queued task writes, in order and one at a time,
/// and applies what the server answers. Headless: the clients, the
/// database, the sync engine, a clock and a timer factory are injected.
///
/// Transient failures (network, 5xx, 429, a token the server rejected
/// after the interceptor's own refresh, and answers that are not Vikunja's,
/// such as a captive portal's page or a proxy's redirect) are retried with
/// exponential backoff from [initialBackoff], doubling per attempt up to
/// [maxBackoff], shortened by up to half at random; a `Retry-After` is
/// honoured instead. The oldest op blocks the queue while it waits, so
/// later ops never overtake it. A session that ended pauses the sender
/// with the op still queued. Everything else is final: the op becomes a
/// `SyncProblem` until it is retried or discarded. After a drain that sent
/// something the sync engine refreshes, so server-computed fields arrive;
/// and a sync that reaches the server while an op waits out a network
/// failure sends at once, because the network is evidently back.
///
/// A description change that knows the description it started from is
/// checked against the server's right before it is written, so a change
/// made on the web meanwhile is not overwritten silently: checkbox taps
/// are applied again to the server's description, an edit in the editor
/// fails with `DescriptionConflict` until the user keeps theirs or takes
/// the server's.
///
/// A create has no idempotency key, so a request that may have reached the
/// server without an answer (a network failure, a 5xx a proxy answers for
/// a slow upstream, a kill while the request was in flight) is not simply
/// sent again: the next attempt first looks for a task with the sent title
/// created since [lostResponseWindow] before that attempt and adopts it.
/// A create never sent whose task was deleted meanwhile goes with the
/// delete and the row, without a request.
///
/// Senders of the same account may run in several isolates (the app, a
/// background run, a notification action) on the shared database. The
/// claim makes only one of them send an op, and an op another one has in
/// flight (`sending`) stops the queue like a backoff: nothing overtakes it
/// and nothing sends it again until it is [staleSendingAfter] old, which
/// no live sender takes over one op, so only an op a dead run left behind
/// goes back to the queue.
///
/// Uploads go one file per request in a lane of their own, the oldest
/// ready one first, beside the rest of the queue: a large file never holds
/// up an edit, not even one queued while the file is on its way. Each
/// waits out its own backoff and has timeouts sized by the file; one that
/// times out [maxUploadTimeoutsInARow] times in a row, or is above the
/// limit (`maxUploadBytes`) by now, becomes a sync problem. One whose
/// answer was lost is looked for among the task's attachments (same name,
/// size and uploader, created since [lostResponseWindow] before the
/// attempt) before it is sent again. A sender without `uploads`, and a
/// `headless` one (a background run with a deadline), leaves uploads
/// alone.
///
/// A task update the server refuses with code 4020, because the task still
/// points at a cover attachment that was deleted, is sent once more with
/// the cover cleared: the server refuses every update of that task until
/// then.
final class OutboxSender {
  new({
    required this._db,
    required VikunjaWriteClient writeClient,
    required VikunjaReadClient readClient,
    required this._sync,
    DateTime Function()? now,
    this._createTimer = Timer.new,
    Random? random,
    this._uploads,
    this._headless = false,
    int? Function()? currentUserId,
    int? Function()? maxUploadBytes,
  }) : _write = writeClient,
       _read = readClient,
       _now = now ?? DateTime.now,
       _random = random ?? Random(),
       _currentUserId = currentUserId ?? _unknownUser,
       _maxUploadBytes = maxUploadBytes ?? _unknownLimit {
    _syncStatus = _sync.status.listen(_onSyncStatus);
  }

  static int? _unknownUser() => null;
  static int? _unknownLimit() => null;

  static const initialBackoff = Duration(seconds: 2);
  static const maxBackoff = Duration(minutes: 15);

  /// How far before an unanswered create's attempt the lookup reaches: the
  /// server's `created` is its clock, the attempt time this device's, and
  /// the sync engine tolerates the same hour of skew between the two. The
  /// exact title and project keep the match narrow.
  static const lostResponseWindow = Duration(hours: 1);

  /// Above the longest a live sender spends on one op: the connect, send
  /// and receive timeouts of a v1 update's several requests or a label and
  /// assignee diff, and a Retry-After the client waits out.
  static const staleSendingAfter = Duration(minutes: 5);

  /// How often a sender looks again while another isolate sends the op at
  /// the head of the queue, which usually takes seconds.
  static const inFlightRecheck = Duration(seconds: 30);

  /// The task names a cover attachment that is not one of its own: one that
  /// was deleted.
  static const _foreignCoverCode = 4020;

  /// The server's code for a file above its limit.
  static const _fileTooLargeCode = 4012;

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final SyncEngine _sync;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  final Random _random;
  final UploadFiles? _uploads;
  final bool _headless;
  final int? Function() _currentUserId;
  final int? Function() _maxUploadBytes;
  final _uploading = <String, CancelToken>{};
  final _uploadingChanges = StreamController<Set<String>>.broadcast(sync: true);
  final _uploaded = StreamController<TaskAttachment>.broadcast();
  var _swept = false;
  // Synchronous, so a state has reached its subscribers when a drain's
  // future resolves.
  final _changes = StreamController<OutboxSenderState>.broadcast(sync: true);
  late final StreamSubscription<SyncStatus> _syncStatus;

  OutboxSenderState _state = OutboxSenderState.idle;

  // Each lane is idle, draining or waiting; [_state] is what they come to.
  OutboxSenderState _queueState = OutboxSenderState.idle;
  OutboxSenderState _uploadState = OutboxSenderState.idle;

  /// What the oldest op waits out while the queue is `waiting`.
  VikunjaFailure? _blockedBy;

  /// What the next upload waits out while the uploads are `waiting`.
  VikunjaFailure? _uploadBlockedBy;
  Future<void>? _running;
  var _exiting = false;
  var _requested = false;
  Future<void>? _uploadRunning;
  var _uploadExiting = false;
  var _uploadRequested = false;
  var _paused = false;
  var _disposed = false;
  Timer? _timer;
  Timer? _uploadTimer;

  OutboxSenderState get state => _state;

  /// What the oldest op waits out while [state] is `waiting`, else what
  /// the next upload does; null otherwise.
  VikunjaFailure? get blockedBy => switch (_state) {
    OutboxSenderState.waiting =>
      _queueState == OutboxSenderState.waiting ? _blockedBy : _uploadBlockedBy,
    _ => null,
  };

  /// Every attachment an upload created, as the server answered.
  Stream<TaskAttachment> get uploadedAttachments => _uploaded.stream;

  /// The uploads this sender is sending right now; replays the current set
  /// on subscription. A `sending` op not among them was left by a run
  /// that died and waits for [staleSendingAfter].
  Stream<Set<String>> get uploadingOperations => Stream.multi((subscriber) {
    final subscription = _uploadingChanges.stream.listen(
      subscriber.addSync,
      onError: subscriber.addErrorSync,
    );
    subscriber
      ..onCancel = subscription.cancel
      ..add({..._uploading.keys});
  });

  /// Replays the current state on subscription.
  Stream<OutboxSenderState> get states => Stream.multi((subscriber) {
    final subscription = _changes.stream.listen(
      subscriber.addSync,
      onError: subscriber.addErrorSync,
    );
    subscriber
      ..onCancel = subscription.cancel
      ..add(_state);
  });

  /// Sends what is queued, oldest first, then the uploads, and returns
  /// once the queue and the uploads are empty, blocked by a backoff, or
  /// paused. A call during a drain makes that drain look at the queue once
  /// more before it returns; one while an upload is on its way sends the
  /// queue at once. Database errors of the queue propagate; a failed
  /// request never does.
  Future<void> drain() {
    if (_disposed) return Future.value();
    _requested = true;
    final Future<void> queue;
    // A run on its way out (paused, or just done) no longer looks at the
    // queue; a new one does.
    if (_running case final running? when !_exiting) {
      queue = running;
    } else {
      _exiting = false;
      late final Future<void> run;
      run = _run().whenComplete(() {
        if (identical(_running, run)) _running = null;
      });
      queue = _running = run;
    }
    return queue.then((_) => _uploadRunning);
  }

  /// A drain that skips every backoff: "Send now". Returns the failure
  /// that still blocks the queue or the uploads afterwards, null when
  /// nothing does.
  Future<VikunjaFailure?> sendNow() async {
    if (_disposed) return null;
    await _db.outboxDao.clearBackoff();
    await drain();
    return blockedBy;
  }

  /// Stops sending until [resume]; the op being sent still completes.
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _cancelTimer();
    _cancelUploadTimer();
    _queueState = OutboxSenderState.idle;
    _uploadState = OutboxSenderState.idle;
    _emit(OutboxSenderState.paused);
  }

  Future<void> resume() {
    if (!_paused || _disposed) return Future.value();
    _paused = false;
    _publish();
    return drain();
  }

  /// A failed op goes back to the queue and the drain starts.
  Future<void> retry(String operationId) async {
    await _db.outboxDao.retry(operationId);
    await drain();
  }

  /// Drops the op and restores the task from the server, with the inverse
  /// edges of its discarded relation changes on the other tasks; a task the
  /// server no longer has, or no longer shows this user, is removed here.
  /// Throws the `VikunjaFailure` of the read and changes nothing then, so
  /// the user can try again later. An op that went meanwhile (a retry that
  /// succeeded, a delete that was sent) leaves the row as it is. A
  /// rejected create is dropped with its row: the server never had it.
  Future<void> discard(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return;
    if (op.kind == OutboxOperationKind.uploadAttachment.name) {
      await cancelUpload(operationId);
      _log.info('Discarded an upload to task ${op.taskId}');
      return;
    }
    if (op.kind == OutboxOperationKind.createTask.name) {
      await _db.outboxDao.cancelCreate(op.taskId);
      await sweepUploads();
      _log.info('Discarded the create of task ${op.taskId}');
      return;
    }
    final fresh = await _readOrGone(op.taskId);
    await _db.transaction(() async {
      if (await _db.outboxDao.find(operationId) == null) return;
      await _db.outboxDao.remove(op.id);
      if (fresh == null) {
        await _db.tasksDao.deleteRow(op.taskId);
        return;
      }
      if (op.kind == OutboxOperationKind.deleteTask.name) {
        await _db.outboxDao.clearPendingDelete(op.taskId);
      }
      await _db.tasksDao.upsertAll([fresh]);
    });
    _log.info('Discarded ${op.kind} for task ${op.taskId}');
  }

  /// The description the server has now for the task of [operationId],
  /// null when the server no longer has the task or the op is gone. Throws
  /// the `VikunjaFailure` of the read.
  Future<String?> webDescription(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return null;
    return (await _readOrGone(op.taskId))?.description;
  }

  /// "Keep mine" for a `DescriptionConflict`: the op goes back to the
  /// queue and its description overwrites [webDescription], the server's
  /// the user saw, but not a change made on the web after that.
  Future<void> keepMyDescription(
    String operationId, {
    required String webDescription,
  }) async {
    await _db.outboxDao.retryOverwritingDescription(
      operationId,
      base: webDescription,
    );
    await drain();
  }

  /// "Use the web's" for a `DescriptionConflict`: the op's description goes
  /// and the server's task replaces the row, except for what else the op
  /// still changes, which is sent. Throws the `VikunjaFailure` of the read
  /// and changes nothing then; a task the server no longer has goes, as on
  /// [discard].
  Future<void> useWebDescription(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return;
    final fresh = await _readOrGone(op.taskId);
    final taken = await _db.transaction(() async {
      if (fresh == null) {
        if (await _db.outboxDao.find(operationId) == null) return false;
        await _db.outboxDao.remove(operationId);
        await _db.tasksDao.deleteRow(op.taskId);
        return true;
      }
      if (!await _db.outboxDao.dropDescription(operationId)) return false;
      await _db.tasksDao.upsertAll([fresh]);
      return true;
    });
    if (!taken) return;
    _log.info('Took the server description of task ${op.taskId}');
    await drain();
  }

  /// Drops the upload and its stored copy; one on its way is aborted.
  Future<void> cancelUpload(String operationId) async {
    if (_uploading.remove(operationId) case final cancel?) {
      cancel.cancel();
      _uploadingChanged();
    }
    final file = await _db.outboxDao.removeUpload(operationId);
    if (file != null) await _deleteStoredCopy(file);
  }

  /// Deletes the stored copies no queued upload names any more: those of
  /// a cancelled create or a deleted task. Never throws.
  Future<void> sweepUploads() async {
    final uploads = _uploads;
    if (uploads == null || _headless || _disposed) return;
    try {
      final deleted = await uploads.sweep(_db.outboxDao.uploadFiles);
      if (deleted > 0) _log.fine('Deleted $deleted orphaned upload copies');
    } on Object catch (error) {
      _log.info('Sweeping the upload copies failed: ${error.runtimeType}');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _cancelTimer();
    _cancelUploadTimer();
    for (final cancel in _uploading.values) {
      cancel.cancel();
    }
    _uploading.clear();
    await _syncStatus.cancel();
    await _changes.close();
    await _uploadingChanges.close();
    await _uploaded.close();
  }

  /// Null for a task the server no longer has or forbids: a 403 on the
  /// task means its project left the user's list, and the row would
  /// otherwise be purge-protected by its op forever. A 404 without a
  /// Vikunja code is a missing route, which is a failure.
  Future<Task?> _readOrGone(int taskId) async {
    try {
      return await _read.tasks.read(taskId);
    } on NotFound catch (failure) {
      if (failure.routeAbsent) rethrow;
      return null;
    } on Forbidden {
      return null;
    }
  }

  /// A sync that reached the server while an op waits out a network
  /// failure: the network is back, so the backoff is dropped.
  void _onSyncStatus(SyncStatus status) {
    if (status is! SyncIdle || blockedBy is! NetworkFailure) return;
    _log.fine('A sync got through; sending the waiting ops now');
    unawaited(
      sendNow().then<void>(
        (_) {},
        onError: (Object error) =>
            _log.warning('Drain after a sync failed: ${error.runtimeType}'),
      ),
    );
  }

  Future<void> _run() async {
    if (!_swept) {
      _swept = true;
      await sweepUploads();
    }
    try {
      while (_requested && !_disposed && !_paused) {
        _requested = false;
        final sent = await _sendUntilBlocked();
        if (sent > 0) await _refreshQuietly();
      }
    } finally {
      _exiting = true;
      // A database error left the drain: the queue has not been looked at.
      if (_queueState == OutboxSenderState.draining) {
        _setQueueState(OutboxSenderState.idle);
      }
    }
  }

  /// Sends until the queue is empty, the oldest op waits for its backoff
  /// or is in flight elsewhere, or the sender is paused; returns how many
  /// ops the server accepted. The uploads start (or look again) once the
  /// queue has nothing ready: an upload behind a create goes once it is
  /// answered.
  Future<int> _sendUntilBlocked() async {
    _cancelTimer();
    _setQueueState(OutboxSenderState.draining);
    await _db.outboxDao.resetSending(
      now: _now(),
      olderThan: staleSendingAfter,
      keep: _uploading.keys.toSet(),
    );
    var sent = 0;
    while (!_disposed && !_paused) {
      final next = await _db.outboxDao.nextInLine();
      Duration? wait;
      if (next != null) {
        if (next.state == OutboxState.sending.name) {
          _blockedBy = null;
          wait = _inFlightWait(next);
          _log.fine(
            '${next.kind} for task ${next.taskId} is in flight elsewhere',
          );
        } else {
          final due = next.nextAttemptAt?.difference(_now());
          if (due == null || due <= Duration.zero) {
            // Claimed as it is now: an edit merged in since the read goes too.
            final op = await _db.outboxDao.claim(next.id, at: _now());
            if (op != null && await _send(op)) sent++;
            continue;
          }
          wait = due;
        }
      }
      // Started before the queue goes idle, so the state does not flicker.
      _startUploads();
      if (wait == null) {
        _blockedBy = null;
        _setQueueState(OutboxSenderState.idle);
        return sent;
      }
      _arm(wait);
      _setQueueState(OutboxSenderState.waiting);
      return sent;
    }
    if (_paused) _publish();
    return sent;
  }

  /// Runs the uploads beside the queue; a call while they run makes them
  /// look once more after the file on its way.
  void _startUploads() {
    if (_uploads == null || _headless || _disposed || _paused) return;
    _uploadRequested = true;
    if (_uploadRunning != null && !_uploadExiting) return;
    _uploadExiting = false;
    late final Future<void> run;
    run = _runUploads().whenComplete(() {
      if (identical(_uploadRunning, run)) _uploadRunning = null;
    });
    _uploadRunning = run;
  }

  /// Never throws: a timer or an unawaited drain may have started it, so a
  /// database error is only logged.
  Future<void> _runUploads() async {
    try {
      while (_uploadRequested && !_disposed && !_paused) {
        _uploadRequested = false;
        await _sendUploadsUntilBlocked();
      }
    } on Object catch (error) {
      _log.warning('Sending the uploads failed: ${error.runtimeType}');
    } finally {
      _uploadExiting = true;
      if (_uploadState == OutboxSenderState.draining) {
        _setUploadState(OutboxSenderState.idle);
      }
    }
  }

  /// Sends uploads until none is ready; a backoff or an upload in flight
  /// elsewhere arms the timer, which starts a drain.
  Future<void> _sendUploadsUntilBlocked() async {
    _cancelUploadTimer();
    _setUploadState(OutboxSenderState.draining);
    while (!_disposed && !_paused) {
      final (:sent, :wait) = await _sendNextUpload();
      if (sent) continue;
      if (wait == null) {
        _uploadBlockedBy = null;
        _setUploadState(OutboxSenderState.idle);
        return;
      }
      _armUploads(wait);
      _setUploadState(OutboxSenderState.waiting);
      return;
    }
    if (_paused) _publish();
  }

  /// Sends the oldest upload that is ready, so one waiting out its backoff
  /// or left `sending` by a run that died holds up none of the others;
  /// else says how long until one is, no wait when there is none to send.
  Future<({bool sent, Duration? wait})> _sendNextUpload() async {
    if (_disposed || _paused) return (sent: false, wait: null);
    final now = _now();
    Duration? wait;
    for (final upload in await _db.outboxDao.queuedUploads()) {
      final Duration until;
      if (upload.state == OutboxState.sending.name) {
        // Never this sender's own: it awaits its uploads. A stale one is
        // reset by the drain the timer starts.
        until = _inFlightWait(upload);
      } else {
        final due = upload.nextAttemptAt?.difference(now);
        if (due == null || due <= Duration.zero) {
          final op = await _db.outboxDao.claim(upload.id, at: now);
          if (op != null) await _sendUpload(op);
          return (sent: true, wait: null);
        }
        until = due;
      }
      if (wait == null || until < wait) wait = until;
    }
    return (sent: false, wait: wait);
  }

  /// True when the server accepted the op. Only the request is guarded:
  /// once the server has stored the change, an error while applying it
  /// propagates and leaves the op `sending`, so nothing is re-sent on the
  /// spot; once it is [staleSendingAfter] old a drain resets it and sends
  /// an update or delete again (at least once), while a create is looked
  /// up first.
  Future<bool> _send(OutboxRow op) async {
    final kind = OutboxOperationKind.values.asNameMap()[op.kind];
    if (kind == null) {
      await _db.outboxDao.markFailed(
        op.id,
        UnexpectedResponse(null, message: 'unknown op ${op.kind}'),
      );
      return false;
    }
    if (kind == OutboxOperationKind.uploadAttachment) {
      await _sendUpload(op);
      return false;
    }
    if (kind == OutboxOperationKind.createTask &&
        op.sentAt == null &&
        await _db.outboxDao.cancelDeletedCreate(op.id)) {
      await sweepUploads();
      _log.info('Task ${op.taskId} was deleted before its create was sent');
      return false;
    }
    TaskChanges? changes;
    if (kind == OutboxOperationKind.updateTask) {
      changes = await _sendableChanges(op);
      if (changes == null) {
        // An edit merged in after the queue was read names a task whose
        // create is still on its way; the queue skips the op until then.
        await _db.outboxDao.unclaim(op.id);
        return false;
      }
    }
    final Task? task;
    try {
      switch (kind) {
        case OutboxOperationKind.createTask:
          final newTask = decodeNewTask(op.payload);
          task =
              await _recoverCreate(op, newTask) ??
              await _write.tasks.create(newTask);
        case OutboxOperationKind.updateTask:
          task = await _update(op, changes!);
        case OutboxOperationKind.deleteTask:
          await _write.tasks.delete(op.taskId);
          task = null;
        case OutboxOperationKind.uploadAttachment:
          task = null;
      }
    } on VikunjaFailure catch (failure) {
      if (failure case NotFound(taskGone: true) || NotFound(projectGone: true)
          when kind == OutboxOperationKind.deleteTask) {
        await _applyDelete(op);
        return true;
      }
      if (kind == OutboxOperationKind.createTask &&
          _mayHaveReachedServer(failure) &&
          !_disposed) {
        await _db.outboxDao.markUncertain(
          op.id,
          sentAt: op.lastAttemptAt ?? _now(),
        );
      }
      await _handleFailure(op, failure);
      return false;
    } on Object catch (error) {
      // A cancelled request or a bug; never a server answer.
      await _handleFailure(
        op,
        UnexpectedResponse(null, message: '${error.runtimeType}'),
      );
      return false;
    }
    switch (kind) {
      case OutboxOperationKind.createTask:
        await _applyCreate(op, task!);
      case OutboxOperationKind.updateTask:
        await _applyUpdate(op, task!, changes!);
      case OutboxOperationKind.deleteTask:
        await _applyDelete(op);
      case OutboxOperationKind.uploadAttachment:
        break;
    }
    _log.fine('Sent ${op.kind} for task ${op.taskId}');
    return true;
  }

  /// The update of [op], sent once more with the cover cleared when the
  /// task still points at a deleted cover attachment (code 4020): every
  /// update of such a task fails until the cover is cleared. A change that
  /// sets the cover itself is refused as it is.
  Future<Task> _update(OutboxRow op, TaskChanges changes) async {
    Future<Task> send(TaskChanges changes) => _write.tasks.update(
      op.taskId,
      changes,
      rebaseDescription: changes.descriptionBase == null
          ? null
          : (current) => _descriptionToSend(op, changes, current),
    );
    try {
      return await send(changes);
    } on VikunjaFailure catch (failure) {
      if (failure.code != _foreignCoverCode ||
          changes.coverImageAttachmentId != null) {
        rethrow;
      }
      _log.info(
        'Task ${op.taskId} points at a deleted cover; clearing it with the '
        'update',
      );
      return await send(
        changes.merge(const TaskChanges(coverImageAttachmentId: 0)),
      );
    }
  }

  /// Sends one upload and applies the answer. A failure is handled like
  /// any other op's, except that a missing route means attachments are
  /// switched off on the server, which no retry changes, and a missing
  /// stored copy can never be sent.
  Future<void> _sendUpload(OutboxRow op) async {
    final upload = decodeQueuedUpload(op.payload);
    if (!UploadFiles.isStoredName(upload.file)) {
      await _failMissingCopy(op);
      return;
    }
    final file = await _uploads!.fileFor(upload.file);
    if (!file.existsSync()) {
      await _failMissingCopy(op);
      return;
    }
    final cancel = CancelToken();
    _uploading[op.id] = cancel;
    _uploadingChanged();
    final TaskAttachment attachment;
    try {
      final length = await file.length();
      if (_maxUploadBytes() case final limit? when length > limit) {
        // Queued under a larger limit, or before the app had one.
        throw const FileTooLarge(code: _fileTooLargeCode);
      }
      attachment =
          await _recoverUpload(op, upload, length) ??
          await _write.attachments.upload(
            op.taskId,
            fileName: upload.fileName,
            bytes: file.openRead(),
            length: length,
            mimeType: upload.mimeType,
            timeout: uploadTimeoutFor(length),
            cancel: cancel,
          );
    } on VikunjaFailure catch (failure) {
      if (_mayHaveReachedServer(failure) && !_disposed) {
        await _db.outboxDao.markUncertain(
          op.id,
          sentAt: op.lastAttemptAt ?? _now(),
        );
      }
      if (failure case NotFound(routeAbsent: true) when !_disposed) {
        await _db.outboxDao.markFailed(op.id, failure);
        _log.warning('Upload to task ${op.taskId} refused: no attachments');
        return;
      }
      if (failure case NetworkFailure(problem: NetworkProblem.timeout)
          when !_disposed) {
        await _handleUploadTimeout(op, failure);
        return;
      }
      await _handleFailure(op, failure);
      return;
    } on DioException catch (error) {
      // Cancelled by the user, who dropped the op, or by dispose, which
      // leaves it for the next start.
      if (error.type == DioExceptionType.cancel) return;
      await _handleFailure(
        op,
        UnexpectedResponse(null, message: '${error.runtimeType}'),
      );
      return;
    } on FileSystemException {
      await _failMissingCopy(op);
      return;
    } on Object catch (error) {
      await _handleFailure(
        op,
        UnexpectedResponse(null, message: '${error.runtimeType}'),
      );
      return;
    } finally {
      if (_uploading.remove(op.id) != null) _uploadingChanged();
    }
    if (_disposed) return;
    final stored = await _db.outboxDao.removeUpload(op.id);
    if (stored != null) await _deleteStoredCopy(stored);
    _uploaded.add(attachment);
    _log.fine('Uploaded a file to task ${op.taskId}');
  }

  /// A timeout right after others is counted in `attempts`, which starts
  /// again from one after any other failure: a link too slow for the file
  /// makes it a sync problem after [maxUploadTimeoutsInARow], while being
  /// offline (no timeout) keeps it waiting for the network.
  Future<void> _handleUploadTimeout(OutboxRow op, NetworkFailure failure) {
    final previous = switch (op.lastError) {
      final json? => decodeFailure(json),
      null => null,
    };
    final inARow =
        previous is NetworkFailure && previous.problem == NetworkProblem.timeout
        ? op.attempts + 1
        : 1;
    if (inARow >= maxUploadTimeoutsInARow) {
      _log.warning(
        'An upload to task ${op.taskId} timed out $inARow times in a row',
      );
      return _db.outboxDao.markFailed(op.id, failure);
    }
    return _handleFailure(op, failure, attempts: inARow);
  }

  Future<void> _failMissingCopy(OutboxRow op) async {
    if (_disposed) return;
    await _db.outboxDao.markFailed(
      op.id,
      const UnexpectedResponse(null, message: uploadFileMissingMessage),
    );
    _log.warning('The stored copy of an upload to task ${op.taskId} is gone');
  }

  /// The attachment an earlier, unanswered attempt of this upload left on
  /// the server, if there is one: the newest attachment of the task with
  /// the sent name and size, uploaded by this user since
  /// [lostResponseWindow] before that attempt. Null when the upload was
  /// never sent or nothing is found, so it must go (again).
  Future<TaskAttachment?> _recoverUpload(
    OutboxRow op,
    QueuedUpload upload,
    int length,
  ) async {
    final sentAt = op.sentAt;
    if (sentAt == null) return null;
    final details = await _read.tasks.readDetails(op.taskId);
    final userId = _currentUserId();
    final since = sentAt.subtract(lostResponseWindow);
    TaskAttachment? found;
    for (final candidate in details.attachments) {
      final created = candidate.created;
      if (candidate.name != upload.fileName ||
          candidate.size != length ||
          (userId != null && candidate.createdBy?.id != userId) ||
          (created != null && created.isBefore(since))) {
        continue;
      }
      if (found == null || candidate.id > found.id) found = candidate;
    }
    _log.info(
      found == null
          ? 'An upload to task ${op.taskId} did not reach the server; '
                'sent again'
          : 'An upload to task ${op.taskId} had reached the server; adopted',
    );
    return found;
  }

  Future<void> _deleteStoredCopy(String name) async {
    try {
      await _uploads?.delete(name);
    } on FileSystemException catch (error) {
      _log.info('Could not delete an upload copy: ${error.osError?.errorCode}');
    }
  }

  /// The op's changes with every task its relations name followed to the
  /// server id; null while one of them is still a task created here whose
  /// create has not been answered.
  Future<TaskChanges?> _sendableChanges(OutboxRow op) async {
    final changes = decodeTaskChanges(op.payload);
    final relations = changes.relations;
    if (relations == null) return changes;
    final resolved = <int, int>{};
    for (final id in relatedTaskIds(changes)) {
      final serverId = await _db.tasksDao.resolveId(id);
      if (serverId < 0) return null;
      resolved[id] = serverId;
    }
    return withRelations(
      changes,
      relations.mapTaskIds((id) => resolved[id] ?? id),
    );
  }

  /// The description to write over the server's [current]: the queued one
  /// while the server still has the one it started from (an empty one
  /// counts as unchanged however it is written) or has the queued one
  /// already (a re-send after a lost answer, or the same change made on
  /// the web), each as the server stores it, without U+0000; the taps
  /// applied again to [current] when they are all the change was, else a
  /// `DescriptionConflict`.
  static String _descriptionToSend(
    OutboxRow op,
    TaskChanges changes,
    String current,
  ) {
    final base = changes.descriptionBase!;
    final queued = changes.description!;
    if (current == withoutNul(base) ||
        current == withoutNul(queued) ||
        (isRichTextEmpty(current) && isRichTextEmpty(base))) {
      return queued;
    }
    if (changes.checklistToggles case final toggles?) {
      _log.info(
        'The description of task ${op.taskId} changed on the server; '
        '${toggles.length} checkbox taps applied to it again',
      );
      return rebaseChecklistToggles(current, toggles);
    }
    _log.info('The description of task ${op.taskId} changed on the server');
    throw const DescriptionConflict();
  }

  /// The task an earlier, unanswered attempt of this create left on the
  /// server, if there is one: the newest task of the project with the sent
  /// title, created since [lostResponseWindow] before that attempt, that
  /// no other create of this device has adopted already; of two created in
  /// the same second (the server's order among them is undefined) the one
  /// with the higher id. Null when the create was never sent or nothing is
  /// found, so it must go (again).
  Future<Task?> _recoverCreate(OutboxRow op, NewTask newTask) async {
    final sentAt = op.sentAt;
    if (sentAt == null) return null;
    final page = await _read.tasks.listInProject(
      newTask.projectId,
      TaskQuery(
        filter: TaskFilters.createdSince(sentAt.subtract(lostResponseWindow)),
        sort: TaskFilters.byCreatedDescending,
      ),
    );
    final title = withoutNul(newTask.title);
    final adopted = await _db.tasksDao.remappedServerIds();
    Task? found;
    for (final candidate in page.items) {
      if (candidate.title != title || adopted.contains(candidate.id)) {
        continue;
      }
      if (found == null ||
          (candidate.created == found.created && candidate.id > found.id)) {
        found = candidate;
      } else if (candidate.created != found.created) {
        break;
      }
    }
    if (found != null) {
      _log.info(
        'Create of task ${op.taskId} had reached the server as '
        '${found.id}; adopted',
      );
      return found;
    }
    _log.info(
      'Create of task ${op.taskId} did not reach the server; sent again',
    );
    return null;
  }

  /// The row moves to the server id with the response applied; the ops
  /// queued behind the create follow it.
  Future<void> _applyCreate(OutboxRow op, Task task) async {
    if (_disposed) return;
    await _db.outboxDao.completeCreate(op.id, task, at: _now());
  }

  /// The server's task replaces the row, except for the fields a later op
  /// of the task still carries, and the sent kanban placements and list
  /// positions move the task on the downloaded boards and lists, which no
  /// sync would. Nothing is written after dispose: sign-out closes the
  /// database behind a request in flight, and an op left in `sending` is
  /// reset at the next start and sent again.
  Future<void> _applyUpdate(OutboxRow op, Task task, TaskChanges sent) async {
    if (_disposed) return;
    await _db.transaction(() async {
      await _db.outboxDao.remove(op.id);
      await _db.tasksDao.upsertAll([task]);
      if (sent.kanban case final placements? when placements.isNotEmpty) {
        await _db.kanbanDao.applySentPlacements(task.id, placements);
      }
      if (sent.positions case final positions? when positions.isNotEmpty) {
        await _db.listSnapshotsDao.applySentPositions(task.id, positions);
      }
    });
  }

  /// Every op of the task goes with the row: an update that failed while
  /// the delete was queued would otherwise stay as a problem without a
  /// task.
  Future<void> _applyDelete(OutboxRow op) async {
    if (_disposed) return;
    await _db.transaction(() async {
      await _db.outboxDao.removeAllOf(op.taskId);
      await _db.tasksDao.deleteRow(op.taskId);
    });
    await sweepUploads();
  }

  /// [attempts] counts the failed attempts including this one, when they
  /// are not simply one more than before.
  Future<void> _handleFailure(
    OutboxRow op,
    VikunjaFailure failure, {
    int? attempts,
  }) async {
    if (_disposed) return;
    if (_isTransient(failure)) {
      final failed = attempts ?? op.attempts + 1;
      // A Retry-After of 0 (the last second of a rate-limit window) would
      // make the next attempt immediate.
      final delay = switch (failure) {
        RateLimited(:final retryAfter?) when retryAfter > Duration.zero =>
          retryAfter > maxBackoff ? maxBackoff : retryAfter,
        _ => _backoff(failed - 1),
      };
      await _db.outboxDao.scheduleRetry(
        op.id,
        attempts: failed,
        failure: failure,
        nextAttemptAt: _now().add(delay),
      );
      if (op.kind == OutboxOperationKind.uploadAttachment.name) {
        _uploadBlockedBy = failure;
      } else {
        _blockedBy = failure;
      }
      _log.info(
        '${op.kind} for task ${op.taskId} failed with '
        '${failure.runtimeType}, attempt $failed; next in $delay',
      );
      return;
    }
    if (failure is SessionEnded) {
      await _db.outboxDao.holdForSession(op.id, failure);
      _paused = true;
      _log.warning(
        'Session ended while sending ${op.kind} for task ${op.taskId}; '
        'the outbox waits for a new sign-in',
      );
      return;
    }
    await _db.outboxDao.markFailed(op.id, failure);
    _log.warning('${op.kind} for task ${op.taskId} was rejected: $failure');
    // A refused create with a delete queued behind it went with its row.
    if (op.kind == OutboxOperationKind.createTask.name &&
        await _db.outboxDao.find(op.id) == null) {
      await sweepUploads();
    }
  }

  /// A request the server may have processed without this device seeing
  /// the answer: the connection broke or timed out, or a proxy answered
  /// for an upstream that was still at work.
  static bool _mayHaveReachedServer(VikunjaFailure failure) =>
      failure is NetworkFailure || failure is ServerFailure;

  /// What a later attempt may get past. A token the server rejects after
  /// the interceptor's own refresh means a session that was replaced or a
  /// server that will accept the next token; the session that ended for
  /// good arrives as `SessionEnded`. An answer without a Vikunja error
  /// code (a captive portal's page, a proxy's redirect, a web server's
  /// 404 during a deploy, an empty body) is not the server's last word.
  static bool _isTransient(VikunjaFailure failure) => switch (failure) {
    NetworkFailure() ||
    ServerFailure() ||
    RateLimited() ||
    RefreshRaceLost() ||
    TokenRejected() => true,
    NotFound(:final routeAbsent) => routeAbsent,
    UnexpectedResponse(:final statusCode) =>
      statusCode == null || statusCode < 400,
    _ => false,
  };

  /// [attempts] failed so far: 2 s, 4 s, 8 s, … up to [maxBackoff], each
  /// shortened by up to half at random.
  Duration _backoff(int attempts) {
    final doubled = initialBackoff * pow(2, attempts.clamp(0, 30));
    final ceiling = doubled > maxBackoff ? maxBackoff : doubled;
    return ceiling - ceiling * (_random.nextDouble() / 2);
  }

  /// The sync status reports the outcome; a failed refresh does not fail
  /// the drain.
  Future<void> _refreshQuietly() async {
    if (_disposed) return;
    try {
      await _sync.refresh();
    } on Object catch (error) {
      _log.info('Refresh after the drain failed: ${error.runtimeType}');
    }
  }

  /// How long until a sender looks again at an op another isolate sends.
  Duration _inFlightWait(OutboxRow op) {
    final now = _now();
    final untilStale = (op.lastAttemptAt ?? now)
        .add(staleSendingAfter)
        .difference(now);
    if (untilStale < inFlightRecheck) {
      return untilStale.isNegative ? Duration.zero : untilStale;
    }
    return inFlightRecheck;
  }

  void _arm(Duration wait) {
    _cancelTimer();
    _timer = _createTimer(wait, () {
      _timer = null;
      _drainAfterWait();
    });
  }

  /// Through a drain, which first resets an upload a dead run left
  /// `sending`.
  void _armUploads(Duration wait) {
    _cancelUploadTimer();
    _uploadTimer = _createTimer(wait, () {
      _uploadTimer = null;
      _drainAfterWait();
    });
  }

  void _drainAfterWait() => unawaited(
    drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Drain after backoff failed: ${error.runtimeType}'),
    ),
  );

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _cancelUploadTimer() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  void _uploadingChanged() {
    if (!_disposed) _uploadingChanges.add({..._uploading.keys});
  }

  void _setQueueState(OutboxSenderState state) {
    _queueState = state;
    _publish();
  }

  void _setUploadState(OutboxSenderState state) {
    _uploadState = state;
    _publish();
  }

  void _publish() {
    final lanes = {_queueState, _uploadState};
    _emit(
      _paused
          ? OutboxSenderState.paused
          : lanes.contains(OutboxSenderState.draining)
          ? OutboxSenderState.draining
          : lanes.contains(OutboxSenderState.waiting)
          ? OutboxSenderState.waiting
          : OutboxSenderState.idle,
    );
  }

  void _emit(OutboxSenderState state) {
    if (_disposed || _state == state) return;
    _state = state;
    _changes.add(state);
  }
}
