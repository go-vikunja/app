import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

void main() {
  test('round trips through the state map', () {
    final checkpoint = SyncCheckpoint(
      runId: 'run-1',
      newestUpdatedAtStart: DateTime.utc(2026, 10, 10, 12),
      wholePullMarks: 3,
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

  test('advancing keeps the run, its bound and its marks, and resets the '
      'counters', () {
    final newest = DateTime.utc(2026, 10, 10, 12);
    final checkpoint = SyncCheckpoint(
      runId: 'run-1',
      newestUpdatedAtStart: newest,
      wholePullMarks: 2,
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
        wholePullMarks: 2,
        phase: SyncPhase.archivedTasks,
      ),
    );
    expect(SyncCheckpoint.cleared.keys, SyncStateKeys.checkpoint);
    expect(SyncCheckpoint.cleared.values, everyElement(isNull));
  });

  test('a lease round trips with its process; one an older version wrote '
      'names none', () {
    final until = DateTime.utc(2026, 10, 10, 12, 3);
    final back = SyncLease.parse(
      SyncLease(owner: 'a', until: until, run: 'r', process: 7).encode(),
    );

    expect(
      (back?.owner, back?.until, back?.run, back?.process),
      ('a', until, 'r', 7),
    );
    for (final raw in [
      '{"owner":"a","until":"${until.toIso8601String()}"}',
      '{"owner":"a","until":"${until.toIso8601String()}","process":"x"}',
    ]) {
      expect(
        SyncLease.parse(raw),
        isA<SyncLease>()
            .having((lease) => lease.owner, 'owner', 'a')
            .having((lease) => lease.process, 'process', isNull),
      );
    }
  });

  test('runStartedAt reads the time a run id or its write mark starts with, '
      'and nothing else', () {
    final at = DateTime.utc(2026, 11, 19, 8, 30);
    final id = '${at.millisecondsSinceEpoch.toRadixString(36)}-k3j9';
    expect(runStartedAt(id), at);
    expect(runStartedAt('$id+'), at);
    expect(runStartedAt('not an id'), isNull);
    expect(runStartedAt(null), isNull);
    expect(runStartedAt('zzzzzzzzzzzz-k3j9'), isNull);
  });
}
