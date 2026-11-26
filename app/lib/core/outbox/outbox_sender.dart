import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/failure_retry.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/posted_at_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/moments.dart';
import 'package:vikunja_mobile/core/time/timers.dart';

final _log = Logger('Outbox');

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
/// such as a proxy's redirect, an access gate's 401 or 407, or a web
/// server's 404) are retried with exponential backoff from
/// [initialBackoff], doubling per attempt up to [maxBackoff], shortened by
/// up to half at random; a `Retry-After` is honored instead. A request
/// that the account's client refused because it was replaced while the op
/// was on its way (a changed server version rebuilds the clients) goes
/// again at once over the new one. The oldest op blocks the queue while it
/// waits, so later ops never overtake it. An answer that is neither
/// success nor the server's last word counts, and
/// the op becomes a `SyncProblem` after [maxFailedAnswersInARow] of them in
/// a row (an upload after [maxFailedUploadAnswersInARow]); a network
/// failure, a captive portal's page, a 429 or a rejected token never does,
/// as nothing else could go meanwhile either. A session that ended pauses
/// the sender with the op still queued. Everything else is final, an
/// exception without an answer and a 2xx whose JSON cannot be read too,
/// except for a create or an upload, which may already have been stored.
/// After a drain that sent something the sync engine refreshes,
/// so server-computed fields arrive, unless its caller syncs itself
/// ([sendNow]); and a sync that reaches the server while an op waits out a
/// network failure or a captive portal sends at once, because the network
/// is evidently back.
///
/// A repeating task's Done is not applied twice when an answer was lost:
/// the server moves the dates on every Done it gets. Before the first
/// attempt of an update with a Done the sender reads the task and keeps
/// its dates and `done_at` with the op; every later attempt reads it again,
/// and when both moved, that occurrence is already complete. The Done
/// is retired, and companion edits go under their usual conflict rules
/// except for dates and reminders, which may belong to the old occurrence.
/// Those stay on the server's schedule; unmatched edits become a problem.
/// After a lost answer the same holds for fields without a conflict check
/// of their own (title, favorite, priority, progress, colour, repeat,
/// project, cover, a description without a base): an equal one already
/// landed, a differing one may have been changed on the web since. Only a
/// request that never left the device sends them again.
/// Nor is a Done made on the web for the occurrence the device showed: the
/// first attempt compares that occurrence, kept with the op when it was
/// queued, with the task it reads, and does the same when the server has
/// moved on.
///
/// A description change that knows the description it started from is
/// checked against the server's right before it is written, so a change
/// made on the web meanwhile is not overwritten silently: checkbox taps
/// are applied again to the server's description, an edit in the editor
/// fails with `DescriptionConflict` until the user keeps theirs or takes
/// the server's.
///
/// Task creates have no server-side idempotency key. Without the answer
/// there is no way to tell which task is ours, or even whether it now
/// exists, so an uncertain create is a sync problem. Its draft and queued
/// dependents stay under the temporary ID. A create and its queued delete
/// cancel each other without a request only when the create was never sent.
///
/// Senders of the same account may run in several isolates (the app, a
/// background run, a notification action) on the shared database. The
/// claim makes only one of them send an op, and an op another one has in
/// flight (`sending`) stops the queue like a backoff: nothing overtakes it
/// and nothing sends it again until it is [staleSendingAfter] old. A slow
/// upload verification can outlast that wait, but its result will only
/// apply if it still owns the claim. Every isolate of the app runs in one
/// process, so what another process left `sending` goes back at the first
/// drain after a restart, without that wait.
///
/// Uploads go one file per request in a lane of their own, the oldest
/// ready one first, beside the rest of the queue: a large file never holds
/// up an edit, not even one queued while the file is on its way. Each
/// waits out its own backoff and has timeouts sized by the file. A file
/// above the current server limit becomes a sync problem. One whose
/// answer was lost looks for a matching attachment in [lostResponseWindow].
/// Before its first request it reads the task's highest attachment id, so
/// an identical file attached earlier is never taken for its own.
/// It can complete only after verifying the original bytes; an unverified
/// upload becomes a sync problem and keeps its copy. Retry checks again,
/// without uploading again. A sender without `uploads`, and a `headless`
/// one (a background run with a deadline), leaves uploads alone.
///
/// When the server makes a task's delete, the task's uploads not yet on the
/// server are set aside with their copies for [setAsideFor], or as long as
/// [holdSetAside] holds them for an Undo still offered, so an Undo that
/// restores the task from the trash queues them again; afterwards, and at
/// the next start, they and their copies go. A headless sender sets them
/// aside but leaves the drop to the app's.
///
/// A task update the server refuses with code 4020 that sets a cover the
/// task no longer has (its attachment was deleted meanwhile) is sent once
/// more without it; one whose task still points at a deleted cover is sent
/// once more with the cover cleared, as the server refuses every update of
/// that task until then.
///
/// For a label created on the device, one whose
/// attempt may have reached the server without an answer first looks for
/// the newest label of exactly that title this user created from
/// [lostResponseWindow] before that attempt to as long after the last
/// attempt before this one, that the device did not have when the create
/// was queued, that no other create of the device took and whose delete is
/// not queued, and adopts it; one from `findOrCreate` first takes a label
/// the server has under that title, ignoring case, but none whose delete is
/// queued. Its answer is remapped onto the temporary id, and the task
/// updates waiting for it follow. A label's edit queued behind its create
/// goes after it, and so does a delete queued while the create is on its
/// way. A create whose label was deleted here goes with the delete and the
/// row, without a lookup or a request, also after an attempt without an
/// answer: a label that attempt made comes back with the next sync.
final class OutboxSender {
  new({
    required AppDatabase db,
    required VikunjaWriteClient writeClient,
    required VikunjaReadClient readClient,
    required SyncEngine sync,
    DateTime Function()? now,
    CreateTimer createTimer = Timer.new,
    Random? random,
    UploadFiles? uploads,
    bool headless = false,
    int? Function()? currentUserId,
    int? Function()? maxUploadBytes,
    Future<Duration?> Function()? serverClockOffset,
    int? processId,
  }) : this.following(
         db: db,
         writeClient: () => writeClient,
         readClient: () => readClient,
         sync: () => sync,
         syncStatus: sync.status,
         now: now,
         createTimer: createTimer,
         random: random,
         uploads: uploads,
         headless: headless,
         currentUserId: currentUserId,
         maxUploadBytes: maxUploadBytes,
         serverClockOffset: serverClockOffset,
         processId: processId,
       );

  /// Over clients and a sync engine that may be rebuilt while it lives, as
  /// the account's are for a changed server version: it takes each anew
  /// for every request, and [syncStatus] reports the syncs of whichever
  /// engine runs them.
  new following({
    required this._db,
    required this._writeClient,
    required this._readClient,
    required SyncEngine Function() sync,
    required Stream<SyncStatus> syncStatus,
    DateTime Function()? now,
    this._createTimer = Timer.new,
    Random? random,
    this._uploads,
    this._headless = false,
    int? Function()? currentUserId,
    int? Function()? maxUploadBytes,
    Future<Duration?> Function()? serverClockOffset,
    int? processId,
  }) : _syncEngine = sync,
       _now = now ?? DateTime.now,
       _random = random ?? Random(),
       _currentUserId = currentUserId ?? _unknownUser,
       _maxUploadBytes = maxUploadBytes ?? _unknownLimit,
       _serverClockOffset = serverClockOffset ?? _unknownOffset,
       _process = processId ?? pid {
    _syncStatus = syncStatus.listen(_onSyncStatus);
  }

  static int? _unknownUser() => null;
  static int? _unknownLimit() => null;
  static Future<Duration?> _unknownOffset() async => null;

  static const initialBackoff = Duration(seconds: 2);
  static const maxBackoff = Duration(minutes: 15);

  /// The backoff reaches [maxBackoff] after the 10th, so the 16th comes one
  /// to two hours after the first: long enough to ride out a server's
  /// restart or upgrade behind a proxy that answers 502 meanwhile, short
  /// enough that a change the server never takes holds back the queue no
  /// longer. Send now and the background runs skip the backoff and get
  /// there sooner, each attempt still an answer of the server.
  static const maxFailedAnswersInARow = 16;

  /// Lower for the separate upload lane: a verification may download
  /// the whole attachment again.
  static const maxFailedUploadAnswersInARow = 4;

  /// How far around an unanswered attempt the lookup reaches, before the
  /// first and after the request last left the device: the server's
  /// `created` is its clock, the attempt time this device's, with and
  /// without the server's clock offset the session learned (see
  /// [_lookupWindow]), and the hour covers what that offset misses, as the
  /// sync engine tolerates the same hour of skew. The exact title and
  /// project keep the match narrow.
  static const lostResponseWindow = Duration(hours: 1);

  /// Above the longest a live sender spends on one op: the connect, send
  /// and receive timeouts of a v1 update's several requests or a label and
  /// assignee diff, and a Retry-After the client waits out.
  static const staleSendingAfter = Duration(minutes: 5);

  /// How often a sender looks again while another isolate sends the op at
  /// the head of the queue, which usually takes seconds.
  static const inFlightRecheck = Duration(seconds: 30);

  /// How long an answer from the server spares an unsent create the read
  /// before it ([_serverAnswers]).
  static const answeredRecently = Duration(seconds: 30);

  /// Counted from the server's answer, which comes after the Undo was
  /// offered, plus a margin for a tap at its last moment; an Undo offered
  /// longer holds them ([holdSetAside]), and a restore holds them itself
  /// while it is on its way.
  static final Duration setAsideFor =
      deleteUndoWindow + const Duration(seconds: 5);

  /// The task names a cover attachment that is not one of its own: one that
  /// was deleted.
  static const _foreignCoverCode = 4020;

  /// The server's code for a file above its limit.
  static const _fileTooLargeCode = 4012;

  static const _labelMissingCode = 8002;

  final AppDatabase _db;
  final VikunjaWriteClient Function() _writeClient;
  final VikunjaReadClient Function() _readClient;
  final SyncEngine Function() _syncEngine;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  final Random _random;
  final UploadFiles? _uploads;
  final bool _headless;
  final int? Function() _currentUserId;
  final int? Function() _maxUploadBytes;
  final Future<Duration?> Function() _serverClockOffset;
  final int _process;
  final _uploading = <String, CancelToken>{};
  final _uploadingChanges = StreamController<Set<String>>.broadcast(sync: true);
  final _uploaded = StreamController<TaskAttachment>.broadcast();
  var _swept = false;
  Timer? _setAsideDrop;
  // How many holds each task id has, as [holdSetAside] got it.
  final _undoHolds = <int, int>{};
  // Synchronous, so a state has reached its subscribers when a drain's
  // future resolves.
  final _changes = StreamController<OutboxSenderState>.broadcast(sync: true);
  late final StreamSubscription<SyncStatus> _syncStatus;

  // When the server last answered, and when a request last got no answer
  // to rely on ([_serverAnswers]).
  DateTime? _answeredAt;
  DateTime? _unansweredAt;

  OutboxSenderState _state = OutboxSenderState.idle;

  // [_state] is what the two lanes come to.
  late final _queueLane = _Lane(_publish, _createTimer, _drainAfterWait);

  /// Its timer drains, which first resets an upload a dead run left
  /// `sending`.
  late final _uploadLane = _Lane(_publish, _createTimer, _drainAfterWait);
  var _paused = false;
  var _disposed = false;
  var _refreshAfterSending = true;

  VikunjaWriteClient get _write => _writeClient();
  VikunjaReadClient get _read => _readClient();
  SyncEngine get _sync => _syncEngine();
  _Clients get _clients => (write: _write, read: _read);

  OutboxSenderState get state => _state;

  /// What the oldest op waits out while [state] is `waiting`, else what
  /// the next upload does; null otherwise.
  VikunjaFailure? get blockedBy => switch (_state) {
    OutboxSenderState.waiting =>
      _queueLane.state == OutboxSenderState.waiting
          ? _queueLane.blockedBy
          : _uploadLane.blockedBy,
    _ => null,
  };

  /// Every attachment an upload created, as the server answered.
  Stream<TaskAttachment> get uploadedAttachments => _uploaded.stream;

  /// The uploads this sender is sending right now; replays the current set
  /// on subscription. A `sending` op not among them is another isolate's,
  /// or was left by a run that died and waits for [staleSendingAfter] or,
  /// after a restart, for the next drain.
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
    return _queueLane.request(_run).then((_) => _uploadLane.running);
  }

  /// A drain that skips every backoff: "Send now". Returns the failure that
  /// still blocks the queue or the uploads afterwards, null when nothing
  /// does. With [refreshAfter] false the sender leaves the sync to its
  /// caller from now on, for the drain this starts or joins and every later
  /// one: a background run syncs each account right after sending, and its
  /// container lives for one run.
  Future<VikunjaFailure?> sendNow({bool refreshAfter = true}) async {
    if (_disposed) return null;
    // Before the first await: the drain the provider started when it built
    // this sender, which this call joins, has not sent yet; it yields at its
    // sweep first.
    if (!refreshAfter) _refreshAfterSending = false;
    await _db.outboxDao.clearBackoff();
    await drain();
    return blockedBy;
  }

  /// [sendNow] for the queue alone: the uploads keep their backoffs and go
  /// on beside it unawaited, and the failure returned is the queue's, never
  /// an upload's.
  Future<VikunjaFailure?> sendQueueNow() async {
    if (_disposed) return null;
    await _db.outboxDao.clearBackoff(uploads: false);
    await _queueLane.request(_run);
    return !_paused && _queueLane.state == OutboxSenderState.waiting
        ? _queueLane.blockedBy
        : null;
  }

  /// Stops sending until [resume]; the op being sent still completes.
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _queueLane.stop();
    _uploadLane.stop();
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

  /// [retry] for each of [operationIds] that is still failed, then one
  /// drain.
  Future<void> retryAll(Iterable<String> operationIds) async {
    await _db.outboxDao.retryFailed(operationIds);
    await drain();
  }

  /// Drops the op and restores the task from the server, with the inverse
  /// edges of its discarded relation changes on the other tasks; a task the
  /// server no longer has, or no longer shows this user, is removed here
  /// with every op and upload of it. Throws the `VikunjaFailure` of the
  /// read and changes nothing then, so the user can try again later. An op
  /// that went meanwhile (a retry that succeeded, a delete that was sent)
  /// leaves the row as it is. A rejected create is dropped with its row:
  /// the server never had it. A schedule notice never changed the task,
  /// so dismissing it needs no server read. What waited for the dropped
  /// ops is sent.
  Future<void> discard(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return;
    if (op.labelId != null) {
      await _discardLabelOp(op);
      return;
    }
    if (op.kind == OutboxOperationKind.uploadAttachment.name) {
      await cancelUpload(operationId);
      _log.info('Discarded an upload to task ${op.taskId}');
      return;
    }
    if (op.kind == OutboxOperationKind.createTask.name) {
      await _db.outboxDao.cancelCreate(op.taskId);
      await sweepUploads();
      _log.info('Discarded the create of task ${op.taskId}');
      // An update of another task that named it in a relation waited.
      _drainInBackground();
      return;
    }
    if (op.lastError case final error?
        when isRecurringScheduleConflict(decodeFailure(error))) {
      // The notice never overlaid the server schedule.
      await _db.outboxDao.remove(op.id);
      return;
    }
    final fresh = await _readOrGone(op.taskId);
    final gone = await _db.transaction(() async {
      if (await _db.outboxDao.find(operationId) == null) return false;
      if (fresh == null) {
        await _db.outboxDao.removeAllOf(op.taskId);
        await _db.tasksDao.deleteRow(op.taskId);
        return true;
      }
      await _db.outboxDao.remove(op.id);
      if (op.kind == OutboxOperationKind.deleteTask.name) {
        await _db.outboxDao.clearPendingDelete(op.taskId);
      }
      await _db.tasksDao.upsertAll([fresh]);
      return false;
    });
    _log.info('Discarded ${op.kind} for task ${op.taskId}');
    if (gone) {
      await sweepUploads();
      _drainInBackground();
    }
  }

  /// A failed label create goes with its label, which leaves every task
  /// and queued edit, without a server read; a label an unanswered attempt
  /// made, before the create was given up, comes back with the next sync. A
  /// label's failed edit or delete goes, and the label is read from the
  /// server and stored under what else is queued for it, a deleted one
  /// back on the tasks the server has it on; one the server no longer has
  /// goes here too, and one it refuses to show stays as it is. Throws any
  /// other `VikunjaFailure` of that read and changes nothing then.
  Future<void> _discardLabelOp(OutboxRow op) async {
    final labelId = op.labelId!;
    if (op.kind == OutboxOperationKind.createLabel.name) {
      await _db.labelOpsDao.cancelCreate(labelId);
      _log.info('Discarded the create of label $labelId');
      _drainInBackground();
      return;
    }
    Label? fresh;
    var gone = false;
    try {
      // Empty changes are a read.
      fresh = await _write.labels.update(labelId, const LabelChanges());
    } on NotFound catch (failure) {
      if (failure.routeAbsent) rethrow;
      gone = true;
    } on Forbidden {
      // Someone else's: it stays as it is.
    }
    await _db.transaction(() async {
      if (await _db.outboxDao.find(op.id) == null) return;
      if (gone) {
        await _db.labelOpsDao.completeGone(op);
      } else if (fresh case final label?) {
        await _db.labelOpsDao.completeUpdate(op, label);
      } else {
        await _db.outboxDao.remove(op.id);
      }
    });
    _log.info('Discarded ${op.kind} for label $labelId');
    _drainInBackground();
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

  /// "Keep my version" for a repeating task's notice: what it held back,
  /// apart from dates, reminders and fields changed since, is sent as a new
  /// edit, overwriting the server's values of those fields.
  /// A held cover is compared with the server's when this device knows no
  /// cover of the task; throws the `VikunjaFailure` of that read.
  Future<void> keepHeldChanges(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return;
    int? serverCover;
    if (decodeTaskChanges(op.payload).coverImageAttachmentId != null &&
        await _db.outboxDao.localCover(op.taskId) == null) {
      serverCover = (await _read.tasks.readDetails(op.taskId))
          .coverImageAttachmentId;
    }
    if (!await _db.outboxDao.keepHeldChanges(
      operationId,
      now: _now(),
      serverCover: serverCover,
    )) {
      return;
    }
    _log.info('Queued the held changes of $operationId again');
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
        await _db.outboxDao.removeAllOf(op.taskId);
        await _db.tasksDao.deleteRow(op.taskId);
        return true;
      }
      if (!await _db.outboxDao.dropDescription(operationId)) return false;
      await _db.tasksDao.upsertAll([fresh]);
      return true;
    });
    if (!taken) return;
    if (fresh == null) {
      await sweepUploads();
      _log.info('Task ${op.taskId} was gone from the server with every op');
    } else {
      _log.info('Took the server description of task ${op.taskId}');
    }
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
  /// a cancelled create or a deleted task. Copies of set-aside uploads stay
  /// until their time is over, or while [holdSetAside] holds them. Never
  /// throws.
  Future<void> sweepUploads() => _sweep();

  /// Keeps the uploads set aside for the delete of [taskIds], and their
  /// copies, while an Undo of that delete is offered, past [setAsideFor]:
  /// a screen reader keeps the Undo up until it is closed (decision log:
  /// Tasks). It may come before the delete is answered; a temporary id
  /// follows its create to the server's id. The returned function lets go,
  /// after which they go once their time is over.
  void Function() holdSetAside(Iterable<int> taskIds) {
    final ids = taskIds.toSet();
    for (final id in ids) {
      _undoHolds.update(id, (holds) => holds + 1, ifAbsent: () => 1);
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      for (final id in ids) {
        final left = _undoHolds[id]! - 1;
        if (left == 0) {
          _undoHolds.remove(id);
        } else {
          _undoHolds[id] = left;
        }
      }
      unawaited(sweepUploads());
    };
  }

  Future<void> _sweep({bool starting = false}) async {
    final uploads = _uploads;
    if (uploads == null || _headless || _disposed) return;
    try {
      final now = _now();
      // The next start drops every one, whatever its time (decision log:
      // Tasks); a hold is for an Undo this run offers.
      _armSetAsideDrop(
        await _db.outboxDao.dropSetAsideUploads(
          now: now,
          latest: now.add(staleSendingAfter),
          all: starting,
          keep: {
            for (final id in [..._undoHolds.keys])
              await _db.tasksDao.resolveId(id),
          },
        ),
      );
      final deleted = await uploads.sweep(_db.outboxDao.uploadFiles);
      if (deleted > 0) _log.fine('Deleted $deleted orphaned upload copies');
    } on Object catch (error) {
      _log.info('Sweeping the upload copies failed: ${error.runtimeType}');
    }
  }

  void _armSetAsideDrop(DateTime? due) {
    _setAsideDrop?.cancel();
    _setAsideDrop = null;
    if (due == null || _disposed) return;
    final wait = due.difference(_now());
    _setAsideDrop = _createTimer(wait.isNegative ? Duration.zero : wait, () {
      _setAsideDrop = null;
      unawaited(sweepUploads());
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _queueLane.cancelTimer();
    _uploadLane.cancelTimer();
    _setAsideDrop?.cancel();
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
  /// failure or a captive portal: the network is back, so the backoff is
  /// dropped. Its time counts as an answer of the server's (a restored or
  /// older one is past [answeredRecently]).
  void _onSyncStatus(SyncStatus status) {
    if (status is! SyncIdle) return;
    if (_answeredAt case final at
        when at == null || status.lastSyncedAt.isAfter(at)) {
      _answeredAt = status.lastSyncedAt;
    }
    if (blockedBy is! NetworkFailure && blockedBy is! NotJsonResponse) {
      return;
    }
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
      await _sweep(starting: true);
    }
    try {
      while (_queueLane.requested && !_disposed && !_paused) {
        _queueLane.requested = false;
        final sent = await _sendUntilBlocked();
        if (sent > 0 && _refreshAfterSending) await _refreshQuietly();
      }
    } finally {
      _queueLane.exit();
    }
  }

  /// Sends until the queue is empty, the oldest op waits for its backoff
  /// or is in flight elsewhere, or the sender is paused; returns how many
  /// ops the server accepted. The uploads start (or look again) once the
  /// queue has nothing ready: an upload behind a create goes once it is
  /// answered.
  Future<int> _sendUntilBlocked() async {
    _queueLane.begin();
    await _db.outboxDao.resetSending(
      now: _now(),
      olderThan: staleSendingAfter,
      keep: _uploading.keys.toSet(),
      process: _process,
    );
    var sent = 0;
    while (!_disposed && !_paused) {
      final next = await _db.outboxDao.nextInLine();
      Duration? wait;
      if (next != null) {
        if (next.state == OutboxState.sending.name) {
          _queueLane.blockedBy = null;
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
      _queueLane.settle(wait);
      return sent;
    }
    if (_paused) _publish();
    return sent;
  }

  /// Runs the uploads beside the queue; a call while they run makes them
  /// look once more after the file on its way.
  void _startUploads() {
    if (_uploads == null || _headless || _disposed || _paused) return;
    unawaited(_uploadLane.request(_runUploads));
  }

  /// Never throws: a timer or an unawaited drain may have started it, so a
  /// database error is only logged.
  Future<void> _runUploads() async {
    try {
      while (_uploadLane.requested && !_disposed && !_paused) {
        _uploadLane.requested = false;
        await _sendUploadsUntilBlocked();
      }
    } on Object catch (error) {
      _log.warning('Sending the uploads failed: ${error.runtimeType}');
    } finally {
      _uploadLane.exit();
    }
  }

  /// Sends uploads until none is ready; a backoff or an upload in flight
  /// elsewhere arms the timer, which starts a drain.
  Future<void> _sendUploadsUntilBlocked() async {
    _uploadLane.begin();
    while (!_disposed && !_paused) {
      final (:sent, :wait) = await _sendNextUpload();
      if (sent) continue;
      _uploadLane.settle(wait);
      return;
    }
    if (_paused) _publish();
  }

  /// Sends the oldest upload that is ready, so one waiting out its backoff
  /// or left `sending` by a run that died holds up none of the others;
  /// else says how long until one is, no wait when there is none to send.
  /// When only uploads in flight elsewhere are left, no failure blocks
  /// them, as for the queue's head.
  Future<({bool sent, Duration? wait})> _sendNextUpload() async {
    if (_disposed || _paused) return (sent: false, wait: null);
    final now = _now();
    Duration? wait;
    var backingOff = false;
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
        backingOff = true;
      }
      if (wait == null || until < wait) wait = until;
    }
    if (wait != null && !backingOff) _uploadLane.blockedBy = null;
    return (sent: false, wait: wait);
  }

  /// True when the server accepted the op. Only the request is guarded:
  /// once the server has stored the change, an error while applying it
  /// propagates and leaves the op `sending`, so nothing is re-sent on the
  /// spot; once it is [staleSendingAfter] old, or after a restart, a drain
  /// resets it and sends an update or delete again (at least once), while a
  /// create whose request went out is blocked, and an update with a
  /// repeating task's Done is checked against the server first
  /// ([_updateOnce]).
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
    if (kind.isLabelOp) {
      return await _sendLabelOp(op, kind);
    }
    if (kind == OutboxOperationKind.createTask) {
      if (op.sentAt != null) {
        await _blockUnconfirmed(op);
        return false;
      }
      if (await _dropDeletedCreate(op)) return false;
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
    final clients = _clients;
    if (kind == OutboxOperationKind.createTask) {
      final answers = await _serverAnswers(op, clients);
      if (_disposed) {
        // Nothing went out: the next start sends it rather than block it.
        try {
          await _db.outboxDao.unclaim(op.id);
        } on Object catch (error) {
          _log.info('Returning an unsent create failed: ${error.runtimeType}');
        }
        return false;
      }
      if (!answers) return false;
      // Only from here on may the create be on the server; a claim reset
      // meanwhile has handed the op back, and it must not go twice.
      if (!await _db.outboxDao.markCreatePosted(op, at: _now())) {
        return false;
      }
    }
    final Task? task;
    try {
      switch (kind) {
        case OutboxOperationKind.createTask:
          task = await _write.tasks.create(decodeNewTask(op.payload));
        case OutboxOperationKind.updateTask:
          final (sent, answer) = await _updateOnce(op, changes!);
          changes = sent;
          task = answer;
        case OutboxOperationKind.deleteTask:
          await _write.tasks.delete(op.taskId);
          task = null;
        case OutboxOperationKind.uploadAttachment ||
            OutboxOperationKind.createLabel ||
            OutboxOperationKind.updateLabel ||
            OutboxOperationKind.deleteLabel:
          task = null;
      }
    } on VikunjaFailure catch (failure) {
      if (failure case NotFound(taskGone: true) || NotFound(projectGone: true)
          when kind == OutboxOperationKind.deleteTask) {
        await _applyDelete(op);
        return true;
      }
      await _handleSendFailure(op, kind, failure, clients);
      return false;
    } on Object catch (error) {
      // A bug, or an answer the client could not decode after the server
      // took the request.
      await _handleSendFailure(
        op,
        kind,
        UnexpectedResponse(null, message: '${error.runtimeType}'),
        clients,
      );
      return false;
    }
    switch (kind) {
      case OutboxOperationKind.createTask:
        await _applyCreate(op, task!);
      case OutboxOperationKind.updateTask:
        if (task != null) await _applyUpdate(op, task, changes!);
      case OutboxOperationKind.deleteTask:
        await _applyDelete(op);
      case OutboxOperationKind.uploadAttachment ||
          OutboxOperationKind.createLabel ||
          OutboxOperationKind.updateLabel ||
          OutboxOperationKind.deleteLabel:
        break;
    }
    _answeredAt = _now();
    _log.fine('Sent ${op.kind} for task ${op.taskId}');
    return true;
  }

  /// A label's create, edit or delete, as [_send] sends a task's: only the
  /// request is guarded, and an error while applying the answer leaves the
  /// op `sending`. A create that may have reached the server looks first;
  /// a label the server no longer has goes here too.
  Future<bool> _sendLabelOp(OutboxRow op, OutboxOperationKind kind) async {
    final labelId = op.labelId!;
    final Label? answer;
    var takenByTitle = false;
    var looking = false;
    final clients = _clients;
    try {
      switch (kind) {
        case OutboxOperationKind.createLabel:
          if (await _db.labelOpsDao.cancelDeletedCreate(op.id)) {
            _log.info('Label $labelId was deleted here; its create goes');
            return false;
          }
          final queued = decodeLabelCreate(op.payload);
          looking = true;
          final (:found, :seen) = await _recoverLabelCreate(op, queued);
          final taken =
              found ??
              (queued.adopt ? await _labelTitled(queued.label.title) : null);
          looking = false;
          if (taken != null) {
            takenByTitle = true;
            answer = taken;
          } else {
            // What the server had before this request cannot be what it
            // makes of it.
            await _db.labelOpsDao.markCreatePosted(
              op.id,
              at: _now(),
              alsoKnown: seen,
            );
            answer = await _write.labels.create(queued.label);
          }
        case OutboxOperationKind.updateLabel:
          answer = await _write.labels.update(
            labelId,
            decodeLabelChanges(op.payload),
          );
        case OutboxOperationKind.deleteLabel:
          await _write.labels.delete(labelId);
          answer = null;
        case OutboxOperationKind.createTask ||
            OutboxOperationKind.updateTask ||
            OutboxOperationKind.deleteTask ||
            OutboxOperationKind.uploadAttachment:
          throw StateError('not a label op: ${op.kind}');
      }
    } on VikunjaFailure catch (failure) {
      if (failure case NotFound(code: _labelMissingCode)
          when kind != OutboxOperationKind.createLabel && !_disposed) {
        await _db.labelOpsDao.completeGone(op);
        _log.info('Label $labelId was gone from the server');
        return true;
      }
      if (looking && await _refusedLookup(op, failure)) return false;
      await _handleSendFailure(op, kind, failure, clients);
      return false;
    } on Object catch (error) {
      await _handleSendFailure(
        op,
        kind,
        UnexpectedResponse(null, message: '${error.runtimeType}'),
        clients,
      );
      return false;
    }
    if (_disposed) return true;
    switch (answer) {
      case final label? when kind == OutboxOperationKind.createLabel:
        await _db.labelOpsDao.completeCreate(
          op.id,
          label,
          at: _now(),
          takenByTitle: takenByTitle,
        );
      case final label?:
        await _db.labelOpsDao.completeUpdate(op, label);
      case null:
        await _db.labelOpsDao.completeGone(op);
    }
    _log.fine('Sent ${op.kind} for label $labelId');
    return true;
  }

  /// The label an earlier, unanswered attempt of this create left on the
  /// server, if there is one: the newest label of exactly the sent title
  /// that this user created from [lostResponseWindow] before the first such
  /// attempt to as long after the create's request last left the device,
  /// which the device did not have when the create was queued, no other
  /// create of the device took and whose delete is not queued here. Null,
  /// without a request, when no attempt may have reached the server or the
  /// request never left the device, and when nothing is found. Another
  /// member's label of that title, which the search returns once it is on
  /// a task the user sees, is never taken, nor one made on the web after
  /// the requests: an attempt that only looked, offline, moves nothing.
  /// `seen` holds every label of exactly that title the search returned.
  Future<({Label? found, Set<int> seen})> _recoverLabelCreate(
    OutboxRow op,
    QueuedLabelCreate queued,
  ) async {
    final sentAt = op.sentAt;
    final postedAt = postedAtOf(op.payload);
    if (sentAt == null || postedAt == null) {
      return (found: null, seen: const <int>{});
    }
    final title = queued.label.title;
    final (:from, :until) = await _lookupWindow(sentAt, postedAt);
    final userId = _currentUserId();
    final matches = await _labelsTitledOnServer(title);
    final taken = {
      ...queued.known,
      ...await _db.labelsDao.remappedServerIds(),
      ...await _db.labelOpsDao.deletingIds(),
    };
    Label? found;
    for (final label in matches) {
      final created = label.created;
      if (label.title != title ||
          (userId != null && label.createdBy?.id != userId) ||
          taken.contains(label.id) ||
          created == null ||
          created.isBefore(from) ||
          created.isAfter(until)) {
        continue;
      }
      if (found == null || label.id > found.id) found = label;
    }
    _log.info(
      found == null
          ? 'Create of label ${op.labelId} did not reach the server; sent '
                'again'
          : 'Create of label ${op.labelId} had reached the server as '
                '${found.id}; adopted',
    );
    return (
      found: found,
      seen: {
        for (final label in matches)
          if (label.title == title) label.id,
      },
    );
  }

  /// The server's label titled [title], ignoring case; of several the one
  /// with the same case, else the oldest. None whose delete is queued here:
  /// it would leave the tasks of this create.
  Future<Label?> _labelTitled(String title) async {
    final found = await _labelsTitledOnServer(title);
    final deleting = await _db.labelOpsDao.deletingIds();
    final matches = [
      for (final label in found)
        if (!deleting.contains(label.id)) label,
    ]..sort((a, b) => a.id.compareTo(b.id));
    return matches.where((label) => label.title == title).firstOrNull ??
        matches.firstOrNull;
  }

  /// Every label on the server titled [title], ignoring case, from all
  /// pages of a search for it, to the last page or one without a new id
  /// ([_bringsNewId]).
  Future<List<Label>> _labelsTitledOnServer(String title) async {
    final lower = title.toLowerCase();
    final seen = <int>{};
    final matches = <Label>[];
    for (var page = 1; ; page++) {
      final current = await _read.labels.list(page: page, search: title);
      if (!_bringsNewId(current.items.map((label) => label.id), seen)) {
        return matches;
      }
      matches.addAll(
        current.items.where((label) => label.title.toLowerCase() == lower),
      );
      if (!current.hasMore) return matches;
    }
  }

  /// Adds [ids] to [seen]; false when none was new. Without a page count
  /// (a proxy dropped v1's header) every full page has more, and a page
  /// past the end may repeat the last one, so a lookup ends there.
  static bool _bringsNewId(Iterable<int> ids, Set<int> seen) {
    var added = false;
    for (final id in ids) {
      if (seen.add(id)) added = true;
    }
    return added;
  }

  /// A create that never left the device goes with its queued delete.
  Future<bool> _dropDeletedCreate(OutboxRow op) async {
    if (!await _db.outboxDao.cancelDeletedCreate(op.id)) {
      return false;
    }
    await sweepUploads();
    _log.info('Task ${op.taskId} was deleted before the server had it');
    return true;
  }

  /// Whether an unsent create may go. Android's and iOS's HTTP clients fold
  /// the connect phase into one timeout, so a timeout cannot tell a server
  /// that never saw the request from one whose answer was lost, and a
  /// create that may have reached the server is blocked for good. Unless the
  /// server answered within [answeredRecently] with no failure since, the
  /// create's project is read first. A failure that does not count as an
  /// answer of the server's (no network, a timeout, a captive portal, a 5xx, a
  /// rate limit, an ended session) holds the create back unsent; it is
  /// handled like that failure of the create. Any other answer, a refusal
  /// included, shows the server is there.
  Future<bool> _serverAnswers(OutboxRow op, _Clients clients) async {
    final at = _answeredAt;
    final failedAt = _unansweredAt;
    if (at != null &&
        (failedAt == null || at.isAfter(failedAt)) &&
        _now().difference(at) < answeredRecently) {
      return true;
    }
    try {
      await _read.projects.read(decodeNewTask(op.payload).projectId);
    } on VikunjaFailure catch (failure) {
      if (failure is! SessionEnded &&
          _retryOf(op, failure) == FailureRetry.never) {
        return true;
      }
      _log.info(
        'Create of task ${op.taskId} held back: the server did not answer '
        '(${failure.runtimeType})',
      );
      if (await _retryOverRebuiltClients(op, failure, clients)) return false;
      await _handleFailure(op, failure);
      return false;
    } on Object catch (error) {
      // An answer the client could not decode still came from the server.
      _log.fine('Reading the project before a create: ${error.runtimeType}');
      return true;
    }
    _answeredAt = _now();
    return true;
  }

  /// A request that left the device without an answer to rely on.
  void _noteUnanswered(VikunjaFailure failure) {
    if (failedWithoutToken(failure)) return;
    if (failure is NetworkFailure ||
        failure is NotJsonResponse ||
        failure is ServerFailure) {
      _unansweredAt = _now();
    }
  }

  /// [changes] sent as an update of [op], unless they carry a repeating
  /// task's Done whose occurrence is already complete. The first attempt
  /// checks the shown occurrence if known; a retry checks the state before
  /// the first send. Neither proves that our companion edits were applied.
  /// A null task means the server's state was already stored with a notice.
  Future<(TaskChanges, Task?)> _updateOnce(
    OutboxRow op,
    TaskChanges changes,
  ) async {
    if (changes.done != true) return (changes, await _update(op, changes));
    final base = changes.doneBase;
    if (op.sentAt == null) {
      if ((await _db.tasksDao.find(op.taskId))?.repeats ?? false) {
        final fresh = await _readOrGone(op.taskId);
        if (fresh != null && fresh.repeats && !fresh.done) {
          if (base != null && _doneLanded(fresh, base)) {
            _log.info(
              'Task ${op.taskId} was marked done elsewhere for the occurrence '
              'shown here; that done is not sent again',
            );
            return await _updateWithoutDone(op, changes, fresh);
          }
          await _db.outboxDao.markDoneAttempt(
            op.id,
            base: DoneBase.of(fresh),
            sentAt: op.lastAttemptAt ?? _now(),
          );
        }
      }
    } else if (base != null) {
      final fresh = await _readOrGone(op.taskId);
      if (fresh != null && _doneLanded(fresh, base)) {
        _log.info(
          'The occurrence of task ${op.taskId} is already complete; '
          'not sending Done again',
        );
        return await _updateWithoutDone(
          op,
          changes,
          fresh,
          mayHaveLanded: true,
        );
      }
    }
    return (changes, await _update(op, changes));
  }

  /// When our request [mayHaveLanded], fields without a conflict check of
  /// their own are not sent again: one the server shows already landed,
  /// and a differing one may have been changed on the web since, so it
  /// joins the notice.
  Future<(TaskChanges, Task?)> _updateWithoutDone(
    OutboxRow op,
    TaskChanges changes,
    Task fresh, {
    bool mayHaveLanded = false,
  }) async {
    var rest = withoutDoneAndSchedule(changes);
    var unmatched = unmatchedSchedule(changes, fresh);
    var heldBase = const TaskChanges();
    if (mayHaveLanded) {
      final cover = changes.coverImageAttachmentId == null
          ? null
          : (await _read.tasks.readDetails(op.taskId)).coverImageAttachmentId;
      final body = unmatchedBody(changes, fresh, coverImageAttachmentId: cover);
      heldBase = heldBaseOf(body, fresh, coverImageAttachmentId: cover);
      unmatched = unmatched.merge(body);
      rest = withoutBody(rest);
      // Placements of a move that may not have landed name views of a
      // project the task may not be in.
      if (body.projectId != null) rest = withoutPlacements(rest);
    }
    if (_disposed) return (rest, fresh);
    if (rest.isEmpty && unmatched.isEmpty) return (rest, fresh);
    // Retire Done and the old schedule before a companion edit can fail.
    await _db.outboxDao.settleDone(
      op,
      rest,
      fresh,
      unmatched: unmatched,
      heldBase: heldBase,
    );
    return (rest, rest.isEmpty ? null : await _update(op, rest));
  }

  /// A new `done_at` indicates a completion even when the dates look
  /// unchanged: Done can advance an edited date back to its old value.
  /// An Undo may clear the stamp, and a date edit or a change in fractional
  /// precision is not evidence of another completion.
  static bool _doneLanded(Task task, DoneBase base) =>
      task.doneAt != null && !sameSecond(task.doneAt, base.doneAt);

  /// The update of [op]. One refused with code 4020 that sets a cover the
  /// task no longer has (its attachment was deleted meanwhile) is sent once
  /// more without it, and when that leaves nothing the task is read
  /// instead; one whose task still points at a deleted cover is sent once
  /// more with the cover cleared, as the server refuses every update of
  /// that task until then. So it goes at most three times: with the cover
  /// it sets, without it, and with it cleared.
  Future<Task> _update(OutboxRow op, TaskChanges changes) async {
    Future<Task> send(TaskChanges changes) => _write.tasks.update(
      op.taskId,
      changes,
      rebaseDescription: changes.descriptionBase == null
          ? null
          : (current) => _descriptionToSend(op, changes, current),
    );
    var sending = changes;
    while (true) {
      try {
        return await send(sending);
      } on VikunjaFailure catch (failure) {
        final cover = sending.coverImageAttachmentId;
        if (failure.code != _foreignCoverCode || cover == 0) rethrow;
        if (cover == null) {
          _log.info(
            'Task ${op.taskId} points at a deleted cover; clearing it with '
            'the update',
          );
          sending = sending.merge(const TaskChanges(coverImageAttachmentId: 0));
        } else {
          _log.info(
            'The cover set for task ${op.taskId} is no longer its attachment; '
            'the update goes without it',
          );
          sending = withoutCover(sending);
          if (sending.isEmpty) return await _read.tasks.read(op.taskId);
        }
      }
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
    final clients = _clients;
    _uploading[op.id] = cancel;
    _uploadingChanged();
    final TaskAttachment attachment;
    final looking = op.sentAt != null;
    DateTime? postedAt;
    int? attachmentsBefore;
    try {
      final length = await file.length();
      if (looking) {
        final found = await _recoverUpload(op, upload, file, length, cancel);
        if (found == null) {
          if (!cancel.isCancelled && !_disposed) {
            await _db.outboxDao.withUploadRecoveryClaim(
              op,
              () => _blockUnconfirmed(op),
            );
          }
          return;
        }
        attachment = found;
      } else {
        if (_maxUploadBytes() case final limit? when length > limit) {
          // Queued under a larger limit, or before the app had one.
          throw const FileTooLarge(code: _fileTooLargeCode);
        }
        if (attachmentsBeforeOf(op.payload) == null) {
          // A read, so its failure is handled as one the server never saw.
          final details = await _read.tasks.readDetails(op.taskId);
          if (cancel.isCancelled || _disposed) return;
          attachmentsBefore = details.attachments.fold<int>(
            0,
            (highest, attachment) => max(highest, attachment.id),
          );
        }
        postedAt = _now();
        await _db.outboxDao.markPosted(
          op.id,
          at: postedAt,
          attachmentsBefore: attachmentsBefore,
        );
        attachment = await _write.attachments.upload(
          op.taskId,
          fileName: upload.fileName,
          bytes: file.openRead(),
          length: length,
          mimeType: upload.mimeType,
          timeout: uploadTimeoutFor(length),
          cancel: cancel,
        );
      }
    } on VikunjaFailure catch (failure) {
      if (looking) {
        await _handleUploadRecoveryFailure(op, failure, clients);
        return;
      }
      // Before [postedAt] is set, only the read of the fence has been sent.
      if (failure case NotFound(taskGone: true) || NotFound(projectGone: true)
          when !_disposed) {
        await _db.outboxDao.refuseUploadToGoneTask(
          op,
          postedAt: postedAt,
          attachmentsBefore: attachmentsBefore,
          failure: failure,
        );
        _log.warning('Upload to task ${op.taskId} was rejected: $failure');
        return;
      }
      if (postedAt != null && _mayHaveReachedServer(failure) && !_disposed) {
        await _markUncertain(op);
      }
      if (await _retryOverRebuiltClients(op, failure, clients)) return;
      if (failure case NotFound(routeAbsent: true)
          when postedAt != null && !_disposed) {
        await _db.outboxDao.markFailed(op.id, failure);
        _log.warning('Upload to task ${op.taskId} refused: no attachments');
        return;
      }
      await _handleFailure(op, failure);
      return;
    } on FileSystemException {
      await _failMissingCopy(op);
      return;
    } on Object catch (error) {
      // Cancelled by the user, who dropped the op, or by dispose, which
      // leaves it for the next start.
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      // An answer the client could not decode, so the file may be stored,
      // or a bug.
      final failure = UnexpectedResponse(null, message: '${error.runtimeType}');
      if (looking) {
        await _handleUploadRecoveryFailure(op, failure, clients);
      } else {
        if (postedAt != null && !_disposed) await _markUncertain(op);
        await _handleFailure(op, failure);
      }
      return;
    } finally {
      if (_uploading.remove(op.id) != null) _uploadingChanged();
    }
    if (_disposed || cancel.isCancelled) return;
    final stored = await _db.outboxDao.removeUpload(
      op.id,
      ifRecoveryClaim: looking ? op : null,
    );
    if (looking && stored == null) return;
    if (stored != null) await _deleteStoredCopy(stored);
    try {
      await _db.taskDetailsDao.addAttachment(op.taskId, attachment);
    } on Object catch (error) {
      _log.warning('Could not store an uploaded file: ${error.runtimeType}');
    }
    _uploaded.add(attachment);
    _log.fine('Uploaded a file to task ${op.taskId}');
  }

  Future<void> _failMissingCopy(OutboxRow op) async {
    if (_disposed) return;
    Future<void> fail() async {
      await _db.outboxDao.markGivenUp(
        op.id,
        const UnexpectedResponse(null, message: uploadFileMissingMessage),
      );
      _log.warning('The stored copy of an upload to task ${op.taskId} is gone');
    }

    if (op.sentAt == null) {
      await fail();
    } else {
      await _db.outboxDao.withUploadRecoveryClaim(op, fail);
    }
  }

  Future<void> _handleUploadRecoveryFailure(
    OutboxRow op,
    VikunjaFailure failure,
    _Clients clients,
  ) async {
    if (_disposed) return;
    await _db.outboxDao.withUploadRecoveryClaim(op, () async {
      if (await _refusedLookup(op, failure)) return;
      if (await _retryOverRebuiltClients(op, failure, clients)) return;
      await _handleFailure(op, failure);
    });
  }

  /// Metadata only narrows the search. Only an original with the same
  /// bytes can satisfy the upload. The read port caps downloads in memory;
  /// larger uploads and ambiguous matches become sync problems.
  Future<TaskAttachment?> _recoverUpload(
    OutboxRow op,
    QueuedUpload upload,
    File file,
    int length,
    CancelToken cancel,
  ) async {
    if (length > maxAttachmentBytes) return null;
    final details = await _read.tasks.readDetails(op.taskId);
    final userId = _currentUserId();
    final (:from, :until) = await _lostAnswerWindow(op, op.sentAt!);
    final fence = attachmentsBeforeOf(op.payload);
    Digest? queued;
    TaskAttachment? found;
    for (final candidate in details.attachments) {
      if (cancel.isCancelled) return null;
      final created = candidate.created;
      if (candidate.taskId != op.taskId ||
          (fence != null && candidate.id <= fence) ||
          candidate.name != upload.fileName ||
          candidate.size != length ||
          (userId != null && candidate.createdBy?.id != userId) ||
          created == null ||
          created.isBefore(from) ||
          created.isAfter(until)) {
        continue;
      }
      queued ??= await sha256.bind(file.openRead()).single;
      final AttachmentBlob original;
      try {
        original = await _read.attachments.fetch(
          op.taskId,
          candidate.id,
          cancel: cancel,
        );
      } on NotFound catch (failure) {
        if (failure.code != 4011) rethrow;
        // It disappeared between reading the task and opening the file.
        continue;
      }
      if (original.bytes.length != length ||
          sha256.convert(original.bytes) != queued) {
        continue;
      }
      if (found != null && found.id != candidate.id) return null;
      found = candidate;
    }
    if (found != null) _log.info('Verified an upload to task ${op.taskId}');
    return found;
  }

  Future<void> _deleteStoredCopy(String name) async {
    try {
      await _uploads?.delete(name);
    } on FileSystemException catch (error) {
      _log.info('Could not delete an upload copy: ${error.osError?.errorCode}');
    }
  }

  /// The op's changes with every task its relations name and every label
  /// it adds or removes followed to the server id; null while one of them
  /// is still a task or a label created here whose create has not been
  /// answered. Placements that would set the done state back are left out
  /// (see [_placementsUndoingDone]).
  Future<TaskChanges?> _sendableChanges(OutboxRow op) async {
    final (:changes, :waits) = await _db.labelOpsDao.resolveLabels(
      decodeTaskChanges(op.payload),
      taskId: op.taskId,
    );
    if (waits) return null;
    final undoing = await _placementsUndoingDone(op, changes);
    final sendable = undoing.isEmpty
        ? changes
        : withoutPlacementsOn(changes, undoing);
    final relations = sendable.relations;
    if (relations == null) return sendable;
    final resolved = <int, int>{};
    for (final id in relatedTaskIds(sendable)) {
      final serverId = await _db.tasksDao.resolveId(id);
      if (serverId < 0) return null;
      resolved[id] = serverId;
    }
    return withRelations(
      sendable,
      relations.mapTaskIds((id) => resolved[id] ?? id),
    );
  }

  /// The views of [changes]' placements on which the move, sent after the
  /// body, would set their done change back: one out of the done bucket
  /// after a Done that leaves the task done, one into it after anything
  /// that leaves it open (a repeating task's Done reopens it). The merge
  /// keeps a placement on a view that had no done bucket then, and one may
  /// have been chosen on the web since (decision log: Sets, relations,
  /// positions, labels).
  Future<Set<int>> _placementsUndoingDone(
    OutboxRow op,
    TaskChanges changes,
  ) async {
    final done = changes.done;
    final kanban = changes.kanban;
    if (done == null || kanban == null || kanban.isEmpty) return const {};
    final doneBuckets = await _db.projectsDao.doneBucketIds(kanban.keys);
    if (doneBuckets.values.every((id) => id == 0)) return const {};
    final staysDone =
        done && !((await _db.tasksDao.find(op.taskId))?.repeats ?? false);
    final undoing = {
      for (final MapEntry(key: viewId, value: placement) in kanban.entries)
        if (doneBuckets[viewId] case final doneBucket?
            when doneBucket != 0 &&
                (placement.bucketId == doneBucket) != staysDone)
          viewId,
    };
    if (undoing.isNotEmpty) {
      _log.info(
        'Placements of task ${op.taskId} on views $undoing would undo its '
        'done change; not sent',
      );
    }
    return undoing;
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

  Future<void> _blockUnconfirmed(OutboxRow op) async {
    if (_disposed) return;
    _log.warning('Could not verify ${op.kind} for task ${op.taskId}');
    await _db.outboxDao.markGivenUp(op.id, unconfirmedWrite);
  }

  Future<({DateTime from, DateTime until})> _lostAnswerWindow(
    OutboxRow op,
    DateTime sentAt,
  ) {
    // Older uploads may lack a post time; a clock set back between attempts
    // must not end the window before it starts.
    final posted = postedAtOf(op.payload) ?? _now();
    return _lookupWindow(sentAt, posted.isBefore(sentAt) ? sentAt : posted);
  }

  /// The server times from [lostResponseWindow] before [first] to as long
  /// after [last], two device times of the attempts. The stored offset is
  /// the one learned last: a token refresh after the device clock changed
  /// stores a new one the attempts were not made under, so the window
  /// spans their times both moved by it and as they are.
  Future<({DateTime from, DateTime until})> _lookupWindow(
    DateTime first,
    DateTime last,
  ) async {
    final offset = await _clockOffset();
    final earlier = offset.isNegative ? offset : Duration.zero;
    final later = offset.isNegative ? Duration.zero : offset;
    return (
      from: first.add(earlier).subtract(lostResponseWindow),
      until: last.add(later).add(lostResponseWindow),
    );
  }

  /// How far the server's clock is ahead of this device's; zero when no
  /// offset is stored or it cannot be read.
  Future<Duration> _clockOffset() async {
    try {
      return await _serverClockOffset() ?? Duration.zero;
    } on Object catch (error) {
      _log.info('Could not read the server clock offset: ${error.runtimeType}');
      return Duration.zero;
    }
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
  /// task. The task's uploads not yet on the server are set aside for the
  /// Undo first (decision log: Tasks).
  Future<void> _applyDelete(OutboxRow op) async {
    if (_disposed) return;
    await _db.transaction(() async {
      final now = _now();
      await _db.outboxDao.setAsideUploadsOf(
        op.taskId,
        until: now.add(setAsideFor),
        now: now,
      );
      await _db.outboxDao.removeAllOf(op.taskId);
      await _db.tasksDao.deleteRow(op.taskId);
    });
    await sweepUploads();
  }

  /// A task create that may have landed cannot be retried safely. Labels
  /// retain their own existing recovery rules.
  Future<void> _handleSendFailure(
    OutboxRow op,
    OutboxOperationKind kind,
    VikunjaFailure failure,
    _Clients clients,
  ) async {
    _noteUnanswered(failure);
    if (kind.createsOnServer && _mayHaveReachedServer(failure) && !_disposed) {
      await _markUncertain(op);
      if (kind == OutboxOperationKind.createTask) {
        await _blockUnconfirmed(op);
        return;
      }
    }
    if (await _retryOverRebuiltClients(op, failure, clients)) return;
    await _handleFailure(op, failure);
  }

  /// A changed server version rebuilds the account's clients and closes the
  /// replaced ones, so a later request of a replaced client fails as
  /// offline without leaving the device. The op goes back as it was and
  /// goes again at once over the new ones, nothing counted, subject to the
  /// operation's recovery rules. False for any other failure.
  Future<bool> _retryOverRebuiltClients(
    OutboxRow op,
    VikunjaFailure failure,
    _Clients clients,
  ) async {
    if (failure is! NetworkFailure ||
        _disposed ||
        (identical(clients.write, _write) && identical(clients.read, _read))) {
      return false;
    }
    _log.info(
      '${op.kind} for task ${op.taskId} went over replaced clients; sent '
      'again over the new ones',
    );
    await _db.outboxDao.unclaim(op.id);
    return true;
  }

  /// A lookup the server refuses for good is no refusal of the original
  /// write, which an earlier attempt may have made: it becomes a sync
  /// problem that keeps its mark, so Retry looks again first. False, with
  /// nothing done, for any other failure.
  Future<bool> _refusedLookup(OutboxRow op, VikunjaFailure failure) async {
    if (failure is SessionEnded ||
        _retryOf(op, failure) != FailureRetry.never ||
        _disposed) {
      return false;
    }
    _log.warning('The lookup for ${op.kind} was refused: $failure');
    await _db.outboxDao.markGivenUp(op.id, failure);
    return true;
  }

  /// A retry must not assume this write failed.
  Future<void> _markUncertain(OutboxRow op) =>
      _db.outboxDao.markUncertain(op.id, sentAt: op.lastAttemptAt ?? _now());

  /// A counted failure after one that is not counted starts again from
  /// one, so a day offline uses up none of the op's answers.
  Future<void> _handleFailure(OutboxRow op, VikunjaFailure failure) async {
    _noteUnanswered(failure);
    if (_disposed) return;
    final retry = _retryOf(op, failure);
    if (retry != FailureRetry.never) {
      final failed = retry == FailureRetry.counted && !_followsCounted(op)
          ? 1
          : op.attempts + 1;
      final limit = op.kind == OutboxOperationKind.uploadAttachment.name
          ? maxFailedUploadAnswersInARow
          : maxFailedAnswersInARow;
      if (retry == FailureRetry.counted && failed >= limit) {
        _log.warning(
          '${op.kind} for task ${op.taskId} failed with '
          '${failure.runtimeType} $failed times in a row; given up',
        );
        await _markFailed(op, failure, givenUp: true);
        return;
      }
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
      _laneOf(op).blockedBy = failure;
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
    _log.warning('${op.kind} for task ${op.taskId} was rejected: $failure');
    await _markFailed(op, failure);
  }

  Future<void> _markFailed(
    OutboxRow op,
    VikunjaFailure failure, {
    bool givenUp = false,
  }) async {
    if (givenUp) {
      await _db.outboxDao.markGivenUp(op.id, failure);
    } else {
      await _db.outboxDao.markFailed(op.id, failure);
    }
    // A refused create with a delete queued behind it went with its row.
    if (op.kind == OutboxOperationKind.createTask.name &&
        await _db.outboxDao.find(op.id) == null) {
      await sweepUploads();
    }
  }

  /// A request the server may have processed without this device seeing
  /// the answer: the connection broke or timed out, a proxy answered for
  /// an upstream that was still at work, or an answer came that could not
  /// be read (a 2xx whose body is not what was asked for, or an exception
  /// without a status). A 2xx that is not JSON is a captive portal's page
  /// in the server's place, which stopped the request.
  static bool _mayHaveReachedServer(VikunjaFailure failure) =>
      switch (failure) {
        _ when failedWithoutToken(failure) => false,
        final NetworkFailure network => !neverReachedServer(network),
        ServerFailure() => true,
        NotJsonResponse() => false,
        UnexpectedResponse(:final statusCode) =>
          statusCode == null || statusCode < 300,
        _ => false,
      };

  /// An answer that cannot be read is no final word on a create or an
  /// upload: the server may have stored it, so its recovery policy applies.
  static FailureRetry _retryOf(OutboxRow op, VikunjaFailure failure) =>
      failureRetry(
        failure,
        unreadableIsFinal: !OutboxDao.createKinds.contains(op.kind),
      );

  static bool _followsCounted(OutboxRow op) => switch (op.lastError) {
    final json? => _retryOf(op, decodeFailure(json)) == FailureRetry.counted,
    null => false,
  };

  /// [attempts] failed so far: 2 s, 4 s, 8 s, … up to [maxBackoff], each
  /// shortened by up to half at random.
  Duration _backoff(int attempts) {
    final doubled = initialBackoff * pow(2, attempts.clamp(0, 30));
    final ceiling = doubled > maxBackoff ? maxBackoff : doubled;
    return ceiling - ceiling * (_random.nextDouble() / 2);
  }

  /// The sync status reports the outcome; a failed refresh does not fail
  /// the drain. A run under way may have read a task before its send and
  /// store that again over the answer, so this one runs after it.
  Future<void> _refreshQuietly() async {
    if (_disposed) return;
    try {
      await _sync.refreshAfterWrite();
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

  void _drainAfterWait() => unawaited(
    drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Drain after backoff failed: ${error.runtimeType}'),
    ),
  );

  void _drainInBackground() => unawaited(
    drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Drain after a discard failed: ${error.runtimeType}'),
    ),
  );

  void _uploadingChanged() {
    if (!_disposed) _uploadingChanges.add({..._uploading.keys});
  }

  _Lane _laneOf(OutboxRow op) =>
      op.kind == OutboxOperationKind.uploadAttachment.name
      ? _uploadLane
      : _queueLane;

  void _publish() {
    final lanes = {_queueLane.state, _uploadLane.state};
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

typedef _Clients = ({VikunjaWriteClient write, VikunjaReadClient read});

/// The run of one lane, the queue or the uploads: idle, draining or
/// waiting on its own, with the timer of its next pass.
final class _Lane {
  new(this._publish, this._createTimer, this._onDue);

  final void Function() _publish;
  final CreateTimer _createTimer;
  final void Function() _onDue;

  OutboxSenderState state = OutboxSenderState.idle;

  /// What the lane waits out while it is `waiting`.
  VikunjaFailure? blockedBy;

  /// Set by [request]; the run clears it before each pass and passes once
  /// more while it is set again.
  bool requested = false;
  Future<void>? _running;
  var _exiting = false;
  Timer? _timer;

  Future<void>? get running => _running;

  /// Starts [run], or makes the one under way pass once more. A run on its
  /// way out (paused, or just done) no longer looks; a new one does.
  Future<void> request(Future<void> Function() run) {
    requested = true;
    if (_running case final running? when !_exiting) return running;
    _exiting = false;
    late final Future<void> started;
    started = run().whenComplete(() {
      if (identical(_running, started)) _running = null;
    });
    return _running = started;
  }

  void begin() {
    cancelTimer();
    _set(OutboxSenderState.draining);
  }

  /// Idle without a [wait]; else waiting, and the timer calls `onDue` once
  /// it is over.
  void settle(Duration? wait) {
    if (wait == null) {
      blockedBy = null;
      _set(OutboxSenderState.idle);
      return;
    }
    cancelTimer();
    _timer = _createTimer(wait, () {
      _timer = null;
      _onDue();
    });
    _set(OutboxSenderState.waiting);
  }

  /// The run ends; one that a database error left has not looked.
  void exit() {
    _exiting = true;
    if (state == OutboxSenderState.draining) _set(OutboxSenderState.idle);
  }

  /// Without publishing: pause emits its own state.
  void stop() {
    cancelTimer();
    state = OutboxSenderState.idle;
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _set(OutboxSenderState state) {
    this.state = state;
    _publish();
  }
}
