import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Keys of the `sync_state` table.
abstract final class SyncStateKeys {
  /// When the last run completed, ISO 8601 UTC. Absent until the first run
  /// completes.
  static const lastSyncedAt = 'last_synced_at';

  /// When the last full run completed, ISO 8601 UTC. A refresh runs a full
  /// pull again once this is a day old.
  static const lastFullSyncAt = 'last_full_sync_at';

  /// The newest task `updated` the database holds, server time, ISO 8601
  /// UTC; an incremental run pulls what changed from shortly below it.
  /// Absent in a database written before incremental sync existed.
  static const watermark = 'watermark';

  /// Ids of the projects whose tasks still have to be pulled whole, comma
  /// separated: an incremental run writes them with the project rows, so a
  /// run that fails afterwards leaves the pull to the next one; a completed
  /// run clears the key.
  static const pendingWholePull = 'pending_whole_pull';

  /// The account's `UserSettings` from the account phase of the last run,
  /// see `encodeUserSettings`. Absent before the first run.
  static const userSettings = 'user_settings';

  /// When the activity sync last completed, ISO 8601 UTC. Absent until its
  /// first run, which stores what it finds without showing any of it.
  static const activitySyncedAt = 'activity_synced_at';

  /// When an activity sync last pulled far enough back to cover the
  /// stored notifications that are unread here, ISO 8601 UTC.
  static const activityWindowCheckedAt = 'activity_window_checked_at';

  /// The sync run that holds the account, `{"owner", "until"}` with
  /// `until` ISO 8601 UTC; absent while none does. Every isolate's engine
  /// takes it before a run and renews it while the run makes progress.
  static const syncLease = 'sync_lease';

  static const runId = 'run_id';
  static const runNewestUpdated = 'run_newest_updated';
  static const phase = 'phase';
  static const phaseDone = 'phase_done';
  static const phaseTotal = 'phase_total';
  static const lastId = 'last_id';
  static const doneFilter = 'done_filter';
  static const archivedProjectId = 'archived_project_id';

  static const List<String> checkpoint = [
    runId,
    runNewestUpdated,
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
/// pulled; [newestUpdatedAtStart] is the newest task `updated` the server
/// had when the task phase began, a server time that bounds the catch-up
/// pass before the purge (null for an account without tasks).
@immutable
final class SyncCheckpoint {
  const new({
    required this.runId,
    required this.phase,
    this.newestUpdatedAtStart,
    this.done = 0,
    this.total,
    this.lastId = 0,
    this.doneFilter = DoneFilter.open,
    this.archivedProjectId = 0,
  });

  final String runId;
  final DateTime? newestUpdatedAtStart;
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
      newestUpdatedAtStart: DateTime.tryParse(
        state[SyncStateKeys.runNewestUpdated] ?? '',
      )?.toUtc(),
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
    SyncStateKeys.runNewestUpdated: newestUpdatedAtStart?.toIso8601String(),
    SyncStateKeys.phase: phase.name,
    SyncStateKeys.phaseDone: '$done',
    SyncStateKeys.phaseTotal: total?.toString(),
    SyncStateKeys.lastId: '$lastId',
    SyncStateKeys.doneFilter: doneFilter.name,
    SyncStateKeys.archivedProjectId: '$archivedProjectId',
  };

  SyncCheckpoint copyWith({
    DateTime? newestUpdatedAtStart,
    int? done,
    int? total,
    int? lastId,
    DoneFilter? doneFilter,
    int? archivedProjectId,
  }) => SyncCheckpoint(
    runId: runId,
    newestUpdatedAtStart: newestUpdatedAtStart ?? this.newestUpdatedAtStart,
    phase: phase,
    done: done ?? this.done,
    total: total ?? this.total,
    lastId: lastId ?? this.lastId,
    doneFilter: doneFilter ?? this.doneFilter,
    archivedProjectId: archivedProjectId ?? this.archivedProjectId,
  );

  /// The same run at the start of [next].
  SyncCheckpoint advanceTo(SyncPhase next) => SyncCheckpoint(
    runId: runId,
    newestUpdatedAtStart: newestUpdatedAtStart,
    phase: next,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncCheckpoint &&
      other.runId == runId &&
      other.newestUpdatedAtStart == newestUpdatedAtStart &&
      other.phase == phase &&
      other.done == done &&
      other.total == total &&
      other.lastId == lastId &&
      other.doneFilter == doneFilter &&
      other.archivedProjectId == archivedProjectId;

  @override
  int get hashCode => Object.hash(
    runId,
    newestUpdatedAtStart,
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
      'newest updated at start: $newestUpdatedAtStart)';
}
