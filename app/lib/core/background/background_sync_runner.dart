import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

final _log = Logger('BackgroundSync');

typedef BackgroundContainerFactory = Future<ProviderContainer> Function();

typedef CreateTimer = Timer Function(
  Duration duration,
  void Function() callback,
);

enum BackgroundRunKind {
  /// The periodic run: every account synced, its outbox drained, its
  /// activity fetched and its notifications refilled.
  sync,

  /// Only the outboxes, soon after a change that waited for a token
  /// refresh.
  drain,
}

/// One background run over every signed-in account, in a container of its
/// own built like the app's, whose session managers refresh (D26 makes
/// that safe across isolates). Never throws.
///
/// Skips everything while the app is in front (its heartbeat is younger
/// than [heartbeatFreshness]), and stops before the next account once the
/// app came to the front: the app keeps its accounts fresh itself.
/// Otherwise the accounts take turns, the one whose last turn is oldest
/// first, so one that never gets through (an unreachable server, a slow
/// one) does not keep the others waiting; each starts only while at least
/// [minimumTimeToStart] of the [deadline] remains, because the first
/// request of a sync may rotate the refresh token and a rotation whose
/// answer is lost when the OS suspends the process ends the session. At
/// the deadline, or when the OS stops the run ([stop]), a token refresh
/// still on its way gets up to [settleGrace] to be stored, then the
/// container is disposed, which aborts a sync between two requests.
final class BackgroundSyncRunner {
  new({
    required this._createContainer,
    required this.deadline,
    DateTime Function()? now,
    this._createTimer = Timer.new,
    this.heartbeatFreshness = const Duration(minutes: 2),
    this.minimumTimeToStart = const Duration(seconds: 10),
    this.settleGrace = const Duration(seconds: 3),
  }) : _now = now ?? DateTime.now;

  final BackgroundContainerFactory _createContainer;
  final Duration deadline;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  final Duration heartbeatFreshness;
  final Duration minimumTimeToStart;
  final Duration settleGrace;
  final _stopped = Completer<BackgroundRunOutcome>();
  final _finished = Completer<void>();

  /// The OS stops the run: it ends as at the deadline, and this completes
  /// once the run has noted its outcome and let go of its container (or
  /// after a bound, as the OS tears the engine down when it returns).
  Future<void> stop() async {
    if (!_stopped.isCompleted) _stopped.complete(BackgroundRunOutcome.stopped);
    await _finished.future.timeout(
      settleGrace + const Duration(seconds: 1),
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
    try {
      container = await _createContainer();
    } on Object catch (error) {
      _log.severe('Could not start a background run: ${error.runtimeType}');
      return BackgroundRunOutcome.nothing;
    }
    final run = _Run(
      container: container,
      kind: kind,
      deadlineAt: startedAt.add(deadline),
      now: _now,
      minimumTimeToStart: minimumTimeToStart,
      appInFront: () async =>
          await _appInFront(container.read(backgroundRunLogProvider), _now()),
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
      if (outcome
          case BackgroundRunOutcome.deadline || BackgroundRunOutcome.stopped) {
        await _settle(container);
      }
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

  /// A refresh whose answer is dropped ends the session (D26).
  Future<void> _settle(ProviderContainer container) async {
    try {
      await container
          .read(sessionManagersProvider)
          .settle()
          .timeout(settleGrace);
    } on Object catch (error) {
      _log.info('A token refresh was still on its way: ${error.runtimeType}');
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
    required this.appInFront,
  });

  final ProviderContainer container;
  final BackgroundRunKind kind;
  final DateTime deadlineAt;
  final DateTime Function() now;
  final Duration minimumTimeToStart;
  final Future<bool> Function() appInFront;
  final _released = <String>{};
  var _stopped = false;
  var _failed = false;

  void stop() => _stopped = true;

  /// Another isolate signed the account out: let go of it.
  void release(String accountId) {
    if (!_released.add(accountId)) return;
    _log.info('Account $accountId was signed out; the run lets go of it');
    unawaited(() async {
      try {
        await container.read(sessionManagersProvider).retire(accountId);
        await container.read(openDatabasesProvider).close(accountId);
      } on Object catch (error) {
        _log.fine('Releasing account $accountId: ${error.runtimeType}');
      }
    }());
  }

  bool _goesOn(String accountId) => !_stopped && !_released.contains(accountId);

  Future<BackgroundRunOutcome> accounts() async {
    try {
      final state = await container.read(accountsProvider.future);
      if (state.accounts.isEmpty) return BackgroundRunOutcome.nothing;
      final log = container.read(backgroundRunLogProvider);
      final ordered = await _longestWaitingFirst(state.accounts, log);
      final labelled = state.accounts.length > 1;
      for (final (entry, lastSyncedAt) in ordered) {
        if (_stopped) break;
        if (deadlineAt.difference(now()) < minimumTimeToStart) {
          _log.info('Too little time left for account ${entry.id}');
          return BackgroundRunOutcome.deadline;
        }
        if (await appInFront()) {
          _log.info('The app came to the front; the run stops');
          return BackgroundRunOutcome.skipped;
        }
        await log.recordAttempt(entry.id, now());
        await _account(entry, lastSyncedAt, labelled: labelled);
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

  /// By the start of the account's last turn, one that never had a turn
  /// first, then the oldest synced; with each its last sync, null for one
  /// that never synced. One whose database cannot be read is left out.
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
  /// holds, so it is never left to the network steps' share of the time;
  /// once the server proved unreachable the account's other network steps
  /// are skipped, each would wait for its own timeout.
  Future<void> _account(
    RegisteredAccount entry,
    DateTime? lastSyncedAt, {
    required bool labelled,
  }) async {
    final account = entry.account;
    final notifier = container.read(activityNoticesProvider);
    final syncing = kind == BackgroundRunKind.sync;
    if (account.needsReauth) {
      await _step(account, 'notice', () => notifier.sessionEnded(account));
      await _reconcile(account);
      return;
    }
    await _step(account, 'notice', () => notifier.sessionRestored(account.id));
    if (syncing) await _reconcile(account);
    // The first-sync screen owns an account that never completed a sync.
    if (lastSyncedAt == null) return;
    var synced = _Step.skipped;
    if (!syncing) {
      await _network(account, 'drain', _drain);
    } else {
      synced = await _network(
        account,
        'sync',
        (_) => container.read(syncEngineProvider(account.id)).refresh(),
      );
      if (synced != _Step.sessionEnded && synced != _Step.unreachable) {
        final drained = await _network(account, 'drain', _drain);
        if (drained != _Step.unreachable) {
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
    }
    // The sender pauses on an ended session instead of throwing, so the
    // registry tells.
    if (synced == _Step.sessionEnded || await _needsReauth(account.id)) {
      _failed = true;
      await _step(account, 'notice', () => notifier.sessionEnded(account));
    }
    // What the sync brought (a reminder set on the web) is planned too.
    if (synced == _Step.done) await _reconcile(account);
    if (synced == _Step.done && _goesOn(account.id)) {
      await _step(
        account,
        'log',
        () => container
            .read(backgroundRunLogProvider)
            .recordAccountRun(account.id, now()),
      );
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
  /// that could not reach the server is reported here.
  Future<void> _drain(Account account) async {
    final blockedBy = await container
        .read(outboxSenderProvider(account.id))
        .sendNow();
    if (blockedBy is NetworkFailure) throw blockedBy;
  }

  Future<void> _reconcile(Account account) => _step(
    account,
    'notifications',
    () async => await container
        .read(notificationSchedulerProvider(account.id))
        ?.reconcile(),
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
    } on NetworkFailure {
      _failed = true;
      if (!_stopped) {
        _log.info('$what of account ${account.id}: the server is unreachable');
      }
      return _Step.unreachable;
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

enum _Step { done, failed, unreachable, sessionEnded, skipped }
