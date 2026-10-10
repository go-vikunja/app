import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

void main() {
  test('round trips through the state map', () {
    final checkpoint = SyncCheckpoint(
      runId: 'run-1',
      newestUpdatedAtStart: DateTime.utc(2026, 10, 10, 12),
      phase: SyncPhase.archivedTasks,
      done: 120,
      total: 300,
      lastId: 77,
      doneFilter: DoneFilter.done,
      archivedProjectId: 9,
    );

    final state = checkpoint.toState();
    final back = SyncCheckpoint.fromState({
      for (final MapEntry(:key, :value) in state.entries) key: ?value,
    });

    expect(back, checkpoint);
    expect(state.keys, containsAll(SyncStateKeys.checkpoint));
  });

  test('is absent without a run id or phase, and lenient otherwise', () {
    expect(SyncCheckpoint.fromState({}), isNull);
    expect(SyncCheckpoint.fromState({'run_id': 'x'}), isNull);
    expect(
      SyncCheckpoint.fromState({
        'run_id': 'x',
        'phase': 'tasks',
        'last_id': 'bad',
      }),
      const SyncCheckpoint(runId: 'x', phase: SyncPhase.tasks),
    );
  });

  test('advancing keeps the run and its bound, and resets the counters', () {
    final newest = DateTime.utc(2026, 10, 10, 12);
    final checkpoint = SyncCheckpoint(
      runId: 'run-1',
      newestUpdatedAtStart: newest,
      phase: SyncPhase.tasks,
      done: 5,
      total: 9,
      lastId: 77,
      doneFilter: DoneFilter.done,
    );

    expect(
      checkpoint.advanceTo(SyncPhase.archivedTasks),
      SyncCheckpoint(
        runId: 'run-1',
        newestUpdatedAtStart: newest,
        phase: SyncPhase.archivedTasks,
      ),
    );
    expect(SyncCheckpoint.cleared.keys, SyncStateKeys.checkpoint);
    expect(SyncCheckpoint.cleared.values, everyElement(isNull));
  });
}
