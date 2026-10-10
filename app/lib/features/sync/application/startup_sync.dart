import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'startup_sync.g.dart';

final _log = Logger('StartupSync');

@Riverpod(keepAlive: true)
StartupSync startupSync(Ref ref) =>
    StartupSync(clock: ref.watch(clockProvider));

/// The quiet incremental sync when the shell opens. Skipped while a run is
/// in progress and right after one, so the first sync is not followed by a
/// second run. An account without a completed first run is the first-sync
/// screen's, which resumes its checkpoint instead of starting over.
final class StartupSync {
  new({required this._clock, this._minInterval = const Duration(minutes: 1)});

  final DateTime Function() _clock;
  final Duration _minInterval;

  /// Never throws; the engine's status reports the outcome. Decides on the
  /// engine's first reported status, because a freshly built engine reports
  /// a placeholder until it has read its stored state.
  Future<void> run(SyncEngine engine) async {
    switch (await _firstStatus(engine)) {
      // Null: disposed before it reported.
      case null || SyncNeverRun() || SyncRunning():
      case SyncFailed(lastSyncedAt: null):
        return;
      case SyncIdle(:final lastSyncedAt)
          when _clock().difference(lastSyncedAt) < _minInterval:
        return;
      case _:
        try {
          await engine.refresh();
        } on Object catch (error) {
          _log.info('Startup sync failed: ${error.runtimeType}');
        }
    }
  }

  // Not `first`: that resolves only after the subscription's cancel future,
  // which a replaying stream completes outside the caller's zone.
  Future<SyncStatus?> _firstStatus(SyncEngine engine) {
    final first = Completer<SyncStatus?>();
    late final StreamSubscription<SyncStatus> subscription;
    subscription = engine.status.listen(
      (status) {
        if (!first.isCompleted) first.complete(status);
        unawaited(subscription.cancel());
      },
      onDone: () {
        if (!first.isCompleted) first.complete(null);
      },
    );
    return first.future;
  }
}
