import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Keys of the `sync_state` table.
abstract final class SyncStateKeys {
  /// When the last run completed, ISO 8601 UTC. Absent until the first run
  /// completes.
  static const lastSyncedAt = 'last_synced_at';

  static const runId = 'run_id';
  static const runStartedAt = 'run_started_at';
  static const phase = 'phase';
  static const phaseDone = 'phase_done';
  static const phaseTotal = 'phase_total';
  static const lastId = 'last_id';
  static const doneFilter = 'done_filter';
  static const archivedProjectId = 'archived_project_id';

  static const List<String> checkpoint = [
    runId,
    runStartedAt,
    phase,
    phaseDone,
    phaseTotal,
    lastId,
    doneFilter,
    archivedProjectId,
  ];
}

/// Open tasks are pulled before done ones, so the first screens fill first.
enum DoneFilter {
  open('done = false'),
  done('done = true');

  new(this.filter);

  final String filter;
}

/// Where a sync run is, written after every page so that a killed app
/// continues where it stopped. [lastId] is the keyset cursor of the current
/// task list; [archivedProjectId] the archived project whose tasks are being
/// pulled; [startedAt] bounds the catch-up pass before the purge.
@immutable
final class SyncCheckpoint {
  const new({
    required this.runId,
    required this.phase,
    this.startedAt,
    this.done = 0,
    this.total,
    this.lastId = 0,
    this.doneFilter = DoneFilter.open,
    this.archivedProjectId = 0,
  });

  final String runId;
  final DateTime? startedAt;
  final SyncPhase phase;
  final int done;
  final int? total;
  final int lastId;
  final DoneFilter doneFilter;
  final int archivedProjectId;

  static SyncCheckpoint? fromState(Map<String, String> state) {
    final runId = state[SyncStateKeys.runId];
    final phase = SyncPhase.values.asNameMap()[state[SyncStateKeys.phase]];
    if (runId == null || phase == null) return null;
    return SyncCheckpoint(
      runId: runId,
      startedAt: DateTime.tryParse(state[SyncStateKeys.runStartedAt] ?? '')
          ?.toUtc(),
      phase: phase,
      done: int.tryParse(state[SyncStateKeys.phaseDone] ?? '') ?? 0,
      total: int.tryParse(state[SyncStateKeys.phaseTotal] ?? ''),
      lastId: int.tryParse(state[SyncStateKeys.lastId] ?? '') ?? 0,
      doneFilter:
          DoneFilter.values.asNameMap()[state[SyncStateKeys.doneFilter]] ??
          DoneFilter.open,
      archivedProjectId:
          int.tryParse(state[SyncStateKeys.archivedProjectId] ?? '') ?? 0,
    );
  }

  /// Null values remove the key, so a map of nulls clears the checkpoint.
  static final Map<String, String?> cleared = {
    for (final key in SyncStateKeys.checkpoint) key: null,
  };

  Map<String, String?> toState() => {
    SyncStateKeys.runId: runId,
    SyncStateKeys.runStartedAt: startedAt?.toIso8601String(),
    SyncStateKeys.phase: phase.name,
    SyncStateKeys.phaseDone: '$done',
    SyncStateKeys.phaseTotal: total?.toString(),
    SyncStateKeys.lastId: '$lastId',
    SyncStateKeys.doneFilter: doneFilter.name,
    SyncStateKeys.archivedProjectId: '$archivedProjectId',
  };

  SyncCheckpoint copyWith({
    int? done,
    int? total,
    int? lastId,
    DoneFilter? doneFilter,
    int? archivedProjectId,
  }) => SyncCheckpoint(
    runId: runId,
    startedAt: startedAt,
    phase: phase,
    done: done ?? this.done,
    total: total ?? this.total,
    lastId: lastId ?? this.lastId,
    doneFilter: doneFilter ?? this.doneFilter,
    archivedProjectId: archivedProjectId ?? this.archivedProjectId,
  );

  /// The same run at the start of [next].
  SyncCheckpoint advanceTo(SyncPhase next) =>
      SyncCheckpoint(runId: runId, startedAt: startedAt, phase: next);

  @override
  bool operator ==(Object other) =>
      other is SyncCheckpoint &&
      other.runId == runId &&
      other.startedAt == startedAt &&
      other.phase == phase &&
      other.done == done &&
      other.total == total &&
      other.lastId == lastId &&
      other.doneFilter == doneFilter &&
      other.archivedProjectId == archivedProjectId;

  @override
  int get hashCode => Object.hash(
    runId,
    startedAt,
    phase,
    done,
    total,
    lastId,
    doneFilter,
    archivedProjectId,
  );

  @override
  String toString() =>
      'SyncCheckpoint($runId, ${phase.name}, done: $done/$total, '
      'lastId: $lastId, ${doneFilter.name}, archived: $archivedProjectId, '
      'started: $startedAt)';
}
