import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/time/timers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_taps.dart';

final _log = Logger('BackgroundSync');

typedef BackgroundContainerFactory = Future<ProviderContainer> Function();

enum BackgroundRunKind {
  /// The periodic run: every account's outbox sent first, then every
  /// account synced, its activity fetched and its notifications refilled.
  sync,

  /// Only the outboxes, soon after a change that waited for a token
  /// refresh.
  drain,
}

/// One background run over every signed-in account, in a container of its
/// own built like the app's, whose session managers refresh, which is safe
/// across isolates (decision log: Sessions). Never throws.
///
/// Skips everything while the app is in front (its heartbeat is younger
/// than [heartbeatFreshness]), and stops before the next account once the
/// app came to the front: the app keeps its accounts fresh itself.
/// Otherwise the accounts take turns, the one whose last attempt is oldest
/// first, so one that never gets through (an unreachable server, a slow
/// one) does not keep the others waiting. A sync run sends every account's
/// queue before any account syncs, in the same order, so the user's own
/// changes go out even when the OS ends the run early; that drain counts
/// as the account's attempt. The queue of an account whose last attempt
/// the server left unanswered, or the deadline or the OS cut short, waits
/// for the account's turn instead: a server that never answers would
/// otherwise use up every run before any turn. Each drain and turn
/// starts only while at least [minimumTimeToStart] of the [deadline]
/// remains and the container's `RefreshCutoff` still lets a refresh start.
///
/// The first request of a sync may rotate the refresh token, and a
/// rotation whose answer is never stored ends the session. So every
/// token answer must arrive within [settleGrace] after the deadline, less
/// [answerMargin], which bounds when a refresh may start and how long it
/// waits; none starts once the OS stopped the run ([stop]). After every
/// run the container waits up to [settleGrace] (after a stop [stopGrace])
/// for a refresh on its way and for tokens still to be stored, then it is
/// disposed, which aborts a sync between two requests. Meanwhile its sync
/// engines stop and let go of their leases while the databases are still
/// open, within [leaseReleaseGrace]: a sync the deadline cut short would
/// otherwise hold its account for minutes, and the app wait for it.
final class BackgroundSyncRunner {
  new({
    required this._createContainer,
    required this.deadline,
    DateTime Function()? now,
    this._createTimer = Timer.new,
    this.heartbeatFreshness = const Duration(minutes: 2),
    this.minimumTimeToStart = const Duration(seconds: 10),
    this.settleGrace = const Duration(seconds: 5),
    this.stopGrace = const Duration(seconds: 10),
    this.answerMargin = const Duration(seconds: 2),
    this.leaseReleaseGrace = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final BackgroundContainerFactory _createContainer;
  final Duration deadline;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  final Duration heartbeatFreshness;
  final Duration minimumTimeToStart;
  final Duration settleGrace;
  final Duration stopGrace;
  final Duration answerMargin;
  final Duration leaseReleaseGrace;
  final _stopped = Completer<BackgroundRunOutcome>();
  final _finished = Completer<void>();
  RefreshCutoff? _cutoff;
  int? _stopReason;

  /// The OS stops the run, for [reason] as Android's `WorkInfo` numbers it:
  /// no refresh starts any more, it ends as at the deadline, and this
  /// completes once the run has noted its outcome and let go of its
  /// container (or after a bound, as the OS tears the engine down when it
  /// returns).
  Future<void> stop({required int reason}) async {
    _stopReason ??= reason;
    _cutoff?.closeNow();
    if (!_stopped.isCompleted) _stopped.complete(BackgroundRunOutcome.stopped);
    await _finished.future.timeout(
      stopGrace + const Duration(seconds: 1),
      onTimeout: () {},
    );
  }

  Future<BackgroundRunOutcome> run({
    BackgroundRunKind kind = BackgroundRunKind.sync,
  }) async {
    try {
      return await _runOnce(kind);
    } finally {
      if (!_finished.isCompleted) _finished.complete();
    }
  }

  Future<BackgroundRunOutcome> _runOnce(BackgroundRunKind kind) async {
    final startedAt = _now();
    final ProviderContainer container;
    final RefreshCutoff cutoff;
    try {
      container = await _createContainer();
      cutoff = container.read(refreshCutoffProvider)
        ..answerWithin(
          deadline + settleGrace - answerMargin - _now().difference(startedAt),
        );
    } on Object catch (error) {
      _log.severe('Could not start a background run: ${error.runtimeType}');
      return BackgroundRunOutcome.nothing;
    }
    _cutoff = cutoff;
    if (_stopped.isCompleted) cutoff.closeNow();
    final run = _Run(
      container: container,
      kind: kind,
      deadlineAt: startedAt.add(deadline),
      now: _now,
      minimumTimeToStart: minimumTimeToStart,
      refreshAllowed: () => cutoff.allowsRefresh,
      appInFront: () async =>
          await _appInFront(container.read(backgroundRunLogProvider), _now()),
      stopReason: () => _stopReason,
    );
    final channel = BackgroundRunnerChannel.open(run.release);
    final timedOut = Completer<BackgroundRunOutcome>();
    final remaining = run.deadlineAt.difference(_now());
    final timer = _createTimer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!timedOut.isCompleted) {
          timedOut.complete(BackgroundRunOutcome.deadline);
        }
      },
    );
    BackgroundRunOutcome outcome;
    try {
      final log = container.read(backgroundRunLogProvider);
      if (await _appInFront(log, startedAt)) {
        _log.info('The app is in front; background run skipped');
        outcome = BackgroundRunOutcome.skipped;
      } else {
        outcome = await Future.any([
          run.accounts(),
          timedOut.future,
          _stopped.future,
        ]);
      }
      run.stop();
      cutoff.closeNow();
      await run.noteInterruptedTurn();
      await Future.wait([
        _settle(
          container,
          outcome == BackgroundRunOutcome.stopped ? stopGrace : settleGrace,
        ),
        run.releaseLeases(leaseReleaseGrace),
      ]);
      await _record(log, outcome);
    } on Object catch (error) {
      _log.warning('Background run failed: ${error.runtimeType}');
      outcome = BackgroundRunOutcome.nothing;
    } finally {
      run.stop();
      timer.cancel();
      channel?.close();
      container.dispose();
    }
    _log.info(
      'Background ${kind.name} run: ${outcome.name} after '
      '${_now().difference(startedAt).inSeconds} s',
    );
    return outcome;
  }

  /// A refresh whose answer is dropped ends the session
  /// (decision log: Sessions).
  Future<void> _settle(ProviderContainer container, Duration grace) async {
    try {
      await Future.wait([
        container.read(sessionManagersProvider).settle(),
        container.read(linkShareSessionsProvider).settle(),
      ]).timeout(grace);
    } on Object catch (error) {
      _log.warning(
        'A token refresh or write was still pending: ${error.runtimeType}',
      );
    }
  }

  Future<bool> _appInFront(BackgroundRunLog log, DateTime now) async {
    final heartbeat = await log.lastHeartbeat();
    if (heartbeat == null) return false;
    final age = now.difference(heartbeat);
    return !age.isNegative && age < heartbeatFreshness;
  }

  Future<void> _record(
    BackgroundRunLog log,
    BackgroundRunOutcome outcome,
  ) async {
    try {
      await log.recordResult(outcome, _now());
    } on Object catch (error) {
      _log.info('Could not note the run: ${error.runtimeType}');
    }
  }
}

final class _Run {
  new({
    required this.container,
    required this.kind,
    required this.deadlineAt,
    required this.now,
    required this.minimumTimeToStart,
    required this.refreshAllowed,
    required this.appInFront,
    required this.stopReason,
  });

  final ProviderContainer container;
  final BackgroundRunKind kind;
  final DateTime deadlineAt;
  final DateTime Function() now;
  final Duration minimumTimeToStart;

  /// False once a token refresh may no longer start: a turn then could not
  /// renew the session that its first request needs.
  final bool Function() refreshAllowed;
  final Future<bool> Function() appInFront;

  /// Null unless the OS stopped the run.
  final int? Function() stopReason;
  final _released = <String>{};
  final _accountIds = <String>{};
  final _queueInTurn = <String>{};
  var _stopped = false;
  var _failed = false;

  /// The account whose turn, or whose drain before the turns, has not
  /// noted its outcome yet.
  Account? _inTurn;

  void stop() => _stopped = true;

  /// Another isolate signed the account out: let go of it.
  void release(String accountId) {
    if (!_released.add(accountId)) return;
    _log.info('Account $accountId was signed out; the run lets go of it');
    unawaited(() async {
      try {
        await container.read(sessionManagersProvider).retire(accountId);
        await container.read(linkShareSessionsProvider).retire(accountId);
        await container.read(openDatabasesProvider).close(accountId);
      } on Object catch (error) {
        _log.fine('Releasing account $accountId: ${error.runtimeType}');
      }
    }());
  }

  bool _goesOn(String accountId) => !_stopped && !_released.contains(accountId);

  /// A turn or a drain before the turns that the deadline or the OS cut
  /// short before its sync went through notes so before the container
  /// goes; the turn itself may never get that far.
  Future<void> noteInterruptedTurn() async {
    final account = _inTurn;
    if (account == null || kind != BackgroundRunKind.sync) return;
    await _noteOutcome(account, BackgroundAccountOutcome.stopped);
  }

  /// Without waiting for a sync under way: a request can take its whole
  /// receive timeout.
  Future<void> releaseLeases(Duration within) async {
    final disposals = <Future<void>>[];
    for (final id in _accountIds) {
      if (_released.contains(id) || !container.exists(syncEngineProvider(id))) {
        continue;
      }
      try {
        disposals.add(container.read(syncEngineProvider(id)).dispose());
      } on Object catch (error) {
        _log.fine('No sync engine of account $id: ${error.runtimeType}');
      }
    }
    try {
      await Future.wait(disposals).timeout(within);
    } on Object catch (error) {
      _log.info('A sync lease was not released: ${error.runtimeType}');
    }
  }

  Future<BackgroundRunOutcome> accounts() async {
    try {
      final state = await container.read(accountsProvider.future);
      if (state.accounts.isEmpty) return BackgroundRunOutcome.nothing;
      _accountIds.addAll(state.accounts.map((entry) => entry.id));
      // The widgets' Done taps go into the outboxes the run then sends.
      await importWidgetTaps(container, drains: false);
      final log = container.read(backgroundRunLogProvider);
      final ordered = await _longestWaitingFirst(state.accounts, log);
      final labelled = state.accounts.length > 1;
      final sent = <String, _Step>{};
      if (kind == BackgroundRunKind.sync) {
        if (await _sendQueues(ordered, sent, log) case final outcome?) {
          return outcome;
        }
      }
      for (final (entry, lastSyncedAt) in ordered) {
        if (_stopped) break;
        if (_tooLate) {
          _log.info('Too little time left for account ${entry.id}');
          return BackgroundRunOutcome.deadline;
        }
        if (await appInFront()) {
          _log.info('The app came to the front; the run stops');
          return BackgroundRunOutcome.skipped;
        }
        await log.recordAttempt(entry.id, now());
        _inTurn = entry.account;
        await _account(
          entry,
          lastSyncedAt,
          labelled: labelled,
          queueSent: sent[entry.id],
        );
        _inTurn = null;
      }
      if (_stopped) return BackgroundRunOutcome.deadline;
      return _failed
          ? BackgroundRunOutcome.partial
          : BackgroundRunOutcome.completed;
    } on Object catch (error) {
      if (_stopped) return BackgroundRunOutcome.deadline;
      _log.warning('Background run stopped: ${error.runtimeType}');
      return BackgroundRunOutcome.nothing;
    }
  }

  /// Every account's queue goes before any account syncs: the user's own
  /// changes are worth more than fresh data when the OS ends the run early.
  /// Null to go on with the turns, else the outcome the run ends with.
  Future<BackgroundRunOutcome?> _sendQueues(
    List<(RegisteredAccount, DateTime?)> ordered,
    Map<String, _Step> sent,
    BackgroundRunLog log,
  ) async {
    for (final (entry, lastSyncedAt) in ordered) {
      if (_stopped) return null;
      final account = entry.account;
      if (account.needsReauth ||
          lastSyncedAt == null ||
          !_goesOn(entry.id) ||
          !await _hasQueue(entry.id)) {
        continue;
      }
      if (await _lastAttemptCut(log, entry.id)) {
        _queueInTurn.add(entry.id);
        continue;
      }
      if (_tooLate) {
        _log.info(
          'Too little time left to send the queue of account ${entry.id}',
        );
        return BackgroundRunOutcome.deadline;
      }
      if (await appInFront()) {
        _log.info('The app came to the front; the run stops');
        return BackgroundRunOutcome.skipped;
      }
      await log.recordAttempt(entry.id, now());
      _inTurn = account;
      final step = sent[entry.id] = await _network(account, 'drain', _drain);
      if (step.skipsNetwork && !_stopped) {
        await _noteOutcome(
          account,
          step.outcome,
          timedOut: step == _Step.timedOut,
        );
      } else if (identical(_inTurn, account)) {
        _inTurn = null;
      }
    }
    return null;
  }

  /// The server left the account's last attempt unanswered, or the
  /// deadline or the OS cut it short. One that failed at once (offline, a
  /// refused connection) took none of the run's time.
  Future<bool> _lastAttemptCut(BackgroundRunLog log, String accountId) async {
    try {
      return (await log.lastOutcome(accountId))?.outcome ==
              BackgroundAccountOutcome.stopped ||
          await log.lastOutcomeTimedOut(accountId);
    } on Object catch (error) {
      _log.info('Could not read the last turn: ${error.runtimeType}');
      return false;
    }
  }

  bool get _tooLate =>
      deadlineAt.difference(now()) < minimumTimeToStart || !refreshAllowed();

  /// An empty queue builds no sender and costs no request.
  Future<bool> _hasQueue(String accountId) async {
    try {
      return await container
              .read(appDatabaseProvider(accountId))
              .outboxDao
              .count() >
          0;
    } on Object catch (error) {
      _log.info(
        'Could not count the queue of account $accountId: '
        '${error.runtimeType}',
      );
      return false;
    }
  }

  /// By the start of the account's last attempt (its turn, or the drain of
  /// its queue before the turns), one that never had one first, then the
  /// oldest synced; with each its last sync, null for one that never
  /// synced. One whose database cannot be read is left out.
  Future<List<(RegisteredAccount, DateTime?)>> _longestWaitingFirst(
    List<RegisteredAccount> accounts,
    BackgroundRunLog log,
  ) async {
    final dated = <(RegisteredAccount, DateTime?, DateTime?)>[];
    for (final entry in accounts) {
      try {
        final state = await container
            .read(appDatabaseProvider(entry.id))
            .syncStateDao
            .readAll();
        dated.add((
          entry,
          DateTime.tryParse(state[SyncStateKeys.lastSyncedAt] ?? ''),
          await log.lastAttemptAt(entry.id),
        ));
      } on Object catch (error) {
        _failed = true;
        _log.warning(
          'Could not read the sync state of account ${entry.id}: '
          '${error.runtimeType}',
        );
      }
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    int byDate(DateTime? a, DateTime? b) => (a ?? epoch).compareTo(b ?? epoch);
    dated.sort((a, b) {
      final byTurn = byDate(a.$3, b.$3);
      return byTurn != 0 ? byTurn : byDate(a.$2, b.$2);
    });
    return [for (final (entry, syncedAt, _) in dated) (entry, syncedAt)];
  }

  /// The notification window is refilled first, from what the database
  /// holds, so it is never left to the network steps' share of the time.
  /// In a sync run the queue went before the turns ([queueSent], null when
  /// it was not sent); a restored account's goes in its turn, before the
  /// sync, and so does one the queue phase left to the turn. The turn
  /// syncs, then fetches the activity. Once the
  /// server proved unreachable the account's other network steps are
  /// skipped, each would wait for its own timeout. A drain run only drains.
  Future<void> _account(
    RegisteredAccount entry,
    DateTime? lastSyncedAt, {
    required bool labelled,
    _Step? queueSent,
  }) async {
    final account = entry.account;
    final notifier = container.read(activityNoticesProvider);
    final syncing = kind == BackgroundRunKind.sync;
    if (account.needsReauth && !await _tryRestore(account)) {
      await _step(account, 'notice', () => notifier.sessionEnded(account));
      await _remindBeforeSessionEnds(account);
      await _reconcile(account);
      await _publishWidgets(account);
      if (syncing) {
        await _noteOutcome(account, BackgroundAccountOutcome.signInNeeded);
      }
      return;
    }
    await _step(account, 'notice', () => notifier.sessionRestored(account.id));
    if (syncing) await _reconcile(account);
    // The first-sync screen owns an account that never completed a sync.
    if (lastSyncedAt == null) return;
    var sent = queueSent;
    if (syncing &&
        (account.needsReauth || _queueInTurn.contains(account.id)) &&
        await _hasQueue(account.id)) {
      if (_tooLate) {
        _log.info(
          'Too little time left to send the queue of account ${account.id}',
        );
      } else {
        sent = await _network(account, 'drain', _drain);
      }
    }
    var synced = _Step.skipped;
    if (!syncing) {
      await _network(account, 'drain', _drain);
    } else if (sent == null || !sent.skipsNetwork) {
      var outcome = SyncOutcome.synced;
      synced = await _network(account, 'sync', (_) async {
        outcome = await container
            .read(syncEngineProvider(account.id))
            .refresh();
      });
      // Another run holds the account: this turn neither synced it nor
      // notes it as synced.
      if (synced == _Step.done && outcome == SyncOutcome.skipped) {
        synced = _Step.skipped;
      }
      // The deadline or the OS may still cut the activity fetch short.
      if (synced == _Step.done) await _noteSynced(account);
      // The server keeps no activity for a guest and answers 403.
      if (synced != _Step.sessionEnded &&
          !synced.skipsNetwork &&
          !account.isLinkShare) {
        await _network(account, 'activity', (_) async {
          final fresh = await container
              .read(activitySyncProvider(account.id))
              .run();
          if (!_goesOn(account.id)) return;
          await notifier.show(
            account: account,
            db: container.read(appDatabaseProvider(account.id)),
            fresh: fresh,
            labelled: labelled,
          );
        });
      }
    }
    // The sender pauses on an ended session instead of throwing, so the
    // registry tells.
    final ended =
        synced == _Step.sessionEnded || await _needsReauth(account.id);
    if (ended) {
      _failed = true;
      await _step(account, 'notice', () => notifier.sessionEnded(account));
    }
    // A sync another run holds says nothing about this account. An end
    // during the settle after a stop is noted as the end, which a turn of
    // the old session must not outlast once the account signs in again.
    final turn = switch (synced) {
      _ when !syncing => null,
      _Step.done when !ended => null,
      _ when ended => BackgroundAccountOutcome.sessionEnded,
      _ when _stopped => BackgroundAccountOutcome.stopped,
      _Step.skipped => switch (sent) {
        final step? when step.skipsNetwork => step.outcome,
        _ => null,
      },
      _ => synced.outcome,
    };
    if (turn != null) {
      await _noteOutcome(
        account,
        turn,
        timedOut: synced == _Step.timedOut || sent == _Step.timedOut,
      );
    }
    // What the sync brought (a reminder set on the web) is planned too.
    if (synced == _Step.done) await _reconcile(account);
    await _remindBeforeSessionEnds(account);
    await _publishWidgets(account);
  }

  /// Another isolate may have stored a rotation after this one gave up,
  /// and a guest's link may read again.
  Future<bool> _tryRestore(Account account) => account.isLinkShare
      ? container.read(linkShareSessionsProvider).tryRestore(account.id)
      : container.read(sessionManagersProvider).tryRestore(account.id);

  /// Also after a stop, unlike the steps: the data did sync.
  Future<void> _noteSynced(Account account) async {
    await _noteOutcome(account, BackgroundAccountOutcome.synced);
    if (_released.contains(account.id)) return;
    try {
      await container
          .read(backgroundRunLogProvider)
          .recordAccountRun(account.id, now());
    } on Object catch (error) {
      _log.info('Could not note the sync: ${error.runtimeType}');
    }
  }

  Future<void> _noteOutcome(
    Account account,
    BackgroundAccountOutcome outcome, {
    bool timedOut = false,
  }) async {
    if (identical(_inTurn, account)) _inTurn = null;
    if (_released.contains(account.id)) return;
    try {
      await container
          .read(backgroundRunLogProvider)
          .recordAccountOutcome(
            account.id,
            outcome,
            at: now(),
            stopReason: outcome == BackgroundAccountOutcome.stopped
                ? stopReason()
                : null,
            timedOut:
                timedOut && outcome == BackgroundAccountOutcome.unreachable,
          );
    } on Object catch (error) {
      _log.info('Could not note the turn: ${error.runtimeType}');
    }
  }

  Future<bool> _needsReauth(String accountId) async {
    if (!_goesOn(accountId)) return false;
    try {
      final entry = await container
          .read(accountRegistryProvider)
          .find(accountId);
      return entry?.account.needsReauth ?? false;
    } on Object {
      return false;
    }
  }

  /// Every backoff is dropped: a background run comes rarely, and a
  /// backoff another isolate armed (the notification action's attempt
  /// with an expired token) would otherwise make it skip the very op it
  /// was started for. The sender keeps a failed request to itself; one
  /// that could not reach the server is reported here. In a sync run the
  /// turn syncs right after, so the sender does not.
  Future<void> _drain(Account account) async {
    final blockedBy = await container
        .read(outboxSenderProvider(account.id))
        .sendNow(refreshAfter: kind == BackgroundRunKind.drain);
    if (blockedBy is NetworkFailure) throw blockedBy;
  }

  Future<void> _reconcile(Account account) => _step(
    account,
    'notifications',
    () async => await container
        .read(notificationSchedulerProvider(account.id))
        ?.reconcile(),
  );

  /// Moved by the turn's contacts, cancelled once the session ended; it
  /// reads the account's state anew.
  Future<void> _remindBeforeSessionEnds(Account account) => _step(
    account,
    'session reminder',
    () => container.read(sessionRemindersProvider).update(account.id),
  );

  Future<void> _publishWidgets(Account account) => _step(
    account,
    'widgets',
    () => container.read(widgetRefresherProvider).refresh(account.id),
  );

  Future<_Step> _network(
    Account account,
    String what,
    Future<void> Function(Account account) action,
  ) async {
    if (!_goesOn(account.id)) return _Step.skipped;
    try {
      await action(account);
      return _Step.done;
    } on SessionEnded {
      _failed = true;
      _log.info('The session of account ${account.id} has ended');
      return _Step.sessionEnded;
    } on NetworkFailure catch (failure) {
      _failed = true;
      final step = switch (failure.cause) {
        RefreshDeferred() => _Step.deferred,
        SecureStorageUnreadable() => _Step.storageUnreadable,
        _ when failure.problem == NetworkProblem.timeout => _Step.timedOut,
        _ => _Step.unreachable,
      };
      if (!_stopped) {
        _log.info('$what of account ${account.id}: ${step.reason}');
      }
      return step;
    } on Object catch (error) {
      _failed = true;
      if (!_stopped) {
        _log.info(
          '$what of account ${account.id} failed: ${error.runtimeType}',
        );
      }
      return _Step.failed;
    }
  }

  Future<void> _step(
    Account account,
    String what,
    Future<void> Function() action,
  ) => _network(account, what, (_) => action());
}

enum _Step {
  done,
  failed,
  unreachable,

  /// Unreachable: the server left a request unanswered.
  timedOut,
  deferred,
  storageUnreadable,
  sessionEnded,
  skipped;

  /// The account's other network steps would fail the same way.
  bool get skipsNetwork => switch (this) {
    unreachable || timedOut || deferred || storageUnreadable => true,
    done || failed || sessionEnded || skipped => false,
  };

  BackgroundAccountOutcome get outcome => switch (this) {
    done => BackgroundAccountOutcome.synced,
    unreachable || timedOut => BackgroundAccountOutcome.unreachable,
    deferred => BackgroundAccountOutcome.deferred,
    storageUnreadable => BackgroundAccountOutcome.storageUnreadable,
    sessionEnded => BackgroundAccountOutcome.sessionEnded,
    failed || skipped => BackgroundAccountOutcome.failed,
  };

  String get reason => switch (this) {
    deferred => 'the token renewal waits for the next run',
    storageUnreadable => 'secure storage could not be read',
    _ => 'the server is unreachable',
  };
}
