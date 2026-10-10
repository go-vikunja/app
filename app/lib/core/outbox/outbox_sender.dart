import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
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
/// A create has no idempotency key, so a request that may have reached the
/// server without an answer (a network failure, a 5xx a proxy answers for
/// a slow upstream, a kill while the request was in flight) is not simply
/// sent again: the next attempt first looks for a task with the sent title
/// created since [lostResponseWindow] before that attempt and adopts it.
final class OutboxSender {
  new({
    required this._db,
    required VikunjaWriteClient writeClient,
    required VikunjaReadClient readClient,
    required this._sync,
    DateTime Function()? now,
    this._createTimer = Timer.new,
    Random? random,
  }) : _write = writeClient,
       _read = readClient,
       _now = now ?? DateTime.now,
       _random = random ?? Random() {
    _syncStatus = _sync.status.listen(_onSyncStatus);
  }

  static const initialBackoff = Duration(seconds: 2);
  static const maxBackoff = Duration(minutes: 15);

  /// How far before an unanswered create's attempt the lookup reaches: the
  /// server's `created` is its clock, the attempt time this device's, and
  /// the sync engine tolerates the same hour of skew between the two. The
  /// exact title and project keep the match narrow.
  static const lostResponseWindow = Duration(hours: 1);

  /// A delete of a task that is already gone.
  static const _taskGoneCode = 4002;

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final SyncEngine _sync;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  final Random _random;
  // Synchronous, so a state has reached its subscribers when a drain's
  // future resolves.
  final _changes = StreamController<OutboxSenderState>.broadcast(sync: true);
  late final StreamSubscription<SyncStatus> _syncStatus;

  OutboxSenderState _state = OutboxSenderState.idle;

  /// What the oldest op waits out while the state is `waiting`.
  VikunjaFailure? _blockedBy;
  Future<void>? _running;
  var _exiting = false;
  var _requested = false;
  var _recovered = false;
  var _paused = false;
  var _disposed = false;
  Timer? _timer;

  OutboxSenderState get state => _state;

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

  /// Sends what is queued, oldest first, and returns once the queue is
  /// empty, blocked by a backoff, or paused. A call during a drain makes
  /// that drain look at the queue once more before it returns. Database
  /// errors propagate; a failed request never does.
  Future<void> drain() {
    if (_disposed) return Future.value();
    _requested = true;
    // A run on its way out (paused, or just done) no longer looks at the
    // queue; a new one does.
    if (_running case final running? when !_exiting) return running;
    _exiting = false;
    late final Future<void> run;
    run = _run().whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
    return _running = run;
  }

  /// A drain that skips every backoff: "Send now". Returns the failure
  /// that still blocks the queue afterwards, null when nothing does.
  Future<VikunjaFailure?> sendNow() async {
    if (_disposed) return null;
    await _db.outboxDao.clearBackoff();
    await drain();
    return _state == OutboxSenderState.waiting ? _blockedBy : null;
  }

  /// Stops sending until [resume]; the op being sent still completes.
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _cancelTimer();
    _emit(OutboxSenderState.paused);
  }

  Future<void> resume() {
    if (!_paused || _disposed) return Future.value();
    _paused = false;
    _emit(OutboxSenderState.idle);
    return drain();
  }

  /// A failed op goes back to the queue and the drain starts.
  Future<void> retry(String operationId) async {
    await _db.outboxDao.retry(operationId);
    await drain();
  }

  /// Drops the op and restores the task from the server; a task the
  /// server no longer has, or no longer shows this user, is removed here.
  /// Throws the `VikunjaFailure` of the read and changes nothing then, so
  /// the user can try again later. An op that went meanwhile (a retry that
  /// succeeded, a delete that was sent) leaves the row as it is. A
  /// rejected create is dropped with its row: the server never had it.
  Future<void> discard(String operationId) async {
    final op = await _db.outboxDao.find(operationId);
    if (op == null) return;
    if (op.kind == OutboxOperationKind.createTask.name) {
      await _db.outboxDao.cancelCreate(op.taskId);
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

  Future<void> dispose() async {
    _disposed = true;
    _cancelTimer();
    await _syncStatus.cancel();
    await _changes.close();
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
    if (status is! SyncIdle ||
        _state != OutboxSenderState.waiting ||
        _blockedBy is! NetworkFailure) {
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
    if (!_recovered) {
      // Ops a killed app left in flight.
      await _db.outboxDao.resetSending(now: _now());
      _recovered = true;
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
      if (_state == OutboxSenderState.draining) _emit(OutboxSenderState.idle);
    }
  }

  /// Sends until the queue is empty, the oldest op waits for its backoff,
  /// or the sender is paused; returns how many ops the server accepted.
  Future<int> _sendUntilBlocked() async {
    _cancelTimer();
    _emit(OutboxSenderState.draining);
    var sent = 0;
    while (!_disposed && !_paused) {
      final next = await _db.outboxDao.nextPending();
      if (next == null) {
        _blockedBy = null;
        _emit(OutboxSenderState.idle);
        return sent;
      }
      final wait = next.nextAttemptAt?.difference(_now());
      if (wait != null && wait > Duration.zero) {
        _arm(wait);
        _emit(OutboxSenderState.waiting);
        return sent;
      }
      // Claimed as it is now: an edit merged in since the read goes too.
      final op = await _db.outboxDao.claim(next.id, at: _now());
      if (op == null) continue;
      if (await _send(op)) sent++;
    }
    if (_paused) _emit(OutboxSenderState.paused);
    return sent;
  }

  /// True when the server accepted the op. Only the request is guarded:
  /// once the server has stored the change, an error while applying it
  /// propagates and leaves the op `sending`, so nothing is re-sent on the
  /// spot; the next start resets it and sends an update or delete again
  /// (at least once), while a create is looked up first.
  Future<bool> _send(OutboxRow op) async {
    final kind = OutboxOperationKind.values.asNameMap()[op.kind];
    if (kind == null) {
      await _db.outboxDao.markFailed(
        op.id,
        UnexpectedResponse(null, message: 'unknown op ${op.kind}'),
      );
      return false;
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
          task = await _write.tasks.update(
            op.taskId,
            decodeTaskChanges(op.payload),
          );
        case OutboxOperationKind.deleteTask:
          await _write.tasks.delete(op.taskId);
          task = null;
      }
    } on VikunjaFailure catch (failure) {
      if (failure case NotFound(code: _taskGoneCode)
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
        await _applyUpdate(op, task!);
      case OutboxOperationKind.deleteTask:
        await _applyDelete(op);
    }
    _log.fine('Sent ${op.kind} for task ${op.taskId}');
    return true;
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
    final adopted = await _db.tasksDao.remappedServerIds();
    Task? found;
    for (final candidate in page.items) {
      if (candidate.title != newTask.title || adopted.contains(candidate.id)) {
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
  /// of the task still carries. Nothing is written after dispose: sign-out
  /// closes the database behind a request in flight, and an op left in
  /// `sending` is reset at the next start and sent again.
  Future<void> _applyUpdate(OutboxRow op, Task task) async {
    if (_disposed) return;
    await _db.transaction(() async {
      await _db.outboxDao.remove(op.id);
      await _db.tasksDao.upsertAll([task]);
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
  }

  Future<void> _handleFailure(OutboxRow op, VikunjaFailure failure) async {
    if (_disposed) return;
    if (_isTransient(failure)) {
      final attempts = op.attempts + 1;
      // A Retry-After of 0 (the last second of a rate-limit window) would
      // make the next attempt immediate.
      final delay = switch (failure) {
        RateLimited(:final retryAfter?) when retryAfter > Duration.zero =>
          retryAfter > maxBackoff ? maxBackoff : retryAfter,
        _ => _backoff(op.attempts),
      };
      await _db.outboxDao.scheduleRetry(
        op.id,
        attempts: attempts,
        failure: failure,
        nextAttemptAt: _now().add(delay),
      );
      _blockedBy = failure;
      _log.info(
        '${op.kind} for task ${op.taskId} failed with '
        '${failure.runtimeType}, attempt $attempts; next in $delay',
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

  void _arm(Duration wait) {
    _cancelTimer();
    _timer = _createTimer(wait, () {
      _timer = null;
      unawaited(
        drain().then<void>(
          (_) {},
          onError: (Object error) =>
              _log.warning('Drain after backoff failed: ${error.runtimeType}'),
        ),
      );
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit(OutboxSenderState state) {
    if (_disposed || _state == state) return;
    _state = state;
    _changes.add(state);
  }
}
