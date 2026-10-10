import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/sync/application/startup_sync.dart';

import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);
  late StartupSync startupSync;

  setUp(() {
    startupSync = StartupSync(clock: () => now);
  });

  FakeSyncEngine engineAt(SyncStatus status) =>
      FakeSyncEngine(initialStatus: status, clock: () => now);

  test('refreshes an account synced more than a minute ago', () async {
    final engine = engineAt(
      SyncIdle(lastSyncedAt: now.subtract(const Duration(minutes: 2))),
    );

    await startupSync.run(engine);

    expect(engine.refreshCalls, 1);
    expect(engine.currentStatus, isA<SyncIdle>());
  });

  test('skips an account synced within the last minute', () async {
    final engine = engineAt(
      SyncIdle(lastSyncedAt: now.subtract(const Duration(seconds: 59))),
    );

    await startupSync.run(engine);

    expect(engine.refreshCalls, 0);
  });

  test('skips a run in progress', () async {
    final engine = engineAt(
      const SyncRunning(phase: SyncPhase.tasks, done: 3, initial: false),
    );

    await startupSync.run(engine);

    expect(engine.refreshCalls, 0);
  });

  test('retries after a failed run', () async {
    final engine = engineAt(
      SyncFailed(
        failure: const ServerFailure(500),
        lastSyncedAt: now.subtract(const Duration(seconds: 5)),
      ),
    );

    await startupSync.run(engine);

    expect(engine.refreshCalls, 1);
  });

  test('leaves an account without a completed first sync to the first-sync '
      'screen, which resumes its checkpoint', () async {
    for (final status in [
      const SyncNeverRun(),
      const SyncFailed(failure: ServerFailure(500), lastSyncedAt: null),
    ]) {
      final engine = engineAt(status);

      await startupSync.run(engine);

      expect(engine.refreshCalls, 0, reason: '$status');
    }
  });

  test('waits for the engine to report before deciding', () async {
    final engine = FakeSyncEngine(restored: false, clock: () => now);

    final run = startupSync.run(engine);
    await pumpEventQueue();
    expect(engine.refreshCalls, 0);

    engine.emit(SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 1))));
    await run;

    expect(engine.refreshCalls, 1);
  });

  test('a failing refresh is only the status', () async {
    final engine =
        engineAt(SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 1))))
          ..onRefresh = () async =>
              throw const NetworkFailure(NetworkProblem.unreachable);

    await startupSync.run(engine);

    expect(engine.currentStatus, isA<SyncFailed>());
  });
}
