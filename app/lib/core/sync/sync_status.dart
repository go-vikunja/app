import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// `account` to `archivedTasks` belong to a full run, `delta` and `reconcile`
/// to an incremental one; `projects`, `labels` and `finishing` are shared.
enum SyncPhase {
  account,
  projects,
  labels,
  tasks,
  archivedTasks,
  delta,
  reconcile,
  finishing,
}

/// What the sync engine of one account is doing. A running sync counts the
/// items of its current phase; the total is null while the server has not
/// told us.
@immutable
sealed class SyncStatus {
  const new();
}

/// Nothing has ever been synced for this account.
final class SyncNeverRun extends SyncStatus {
  const new();

  @override
  bool operator ==(Object other) => other is SyncNeverRun;

  @override
  int get hashCode => (SyncNeverRun).hashCode;

  @override
  String toString() => 'SyncNeverRun';
}

final class SyncRunning extends SyncStatus {
  const new({
    required this.phase,
    required this.done,
    required this.initial,
    this.total,
  });

  final SyncPhase phase;
  final int done;
  final int? total;

  /// True until the account has been synced completely once; the UI shows a
  /// blocking progress screen then, a quiet indicator afterwards.
  final bool initial;

  @override
  bool operator ==(Object other) =>
      other is SyncRunning &&
      other.phase == phase &&
      other.done == done &&
      other.total == total &&
      other.initial == initial;

  @override
  int get hashCode => Object.hash(phase, done, total, initial);

  @override
  String toString() =>
      'SyncRunning(${phase.name} $done/${total ?? '?'}'
      '${initial ? ', initial' : ''})';
}

final class SyncIdle extends SyncStatus {
  const new({required this.lastSyncedAt});

  final DateTime lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncIdle && other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => lastSyncedAt.hashCode;

  @override
  String toString() => 'SyncIdle($lastSyncedAt)';
}

/// The last run failed; data from earlier runs stays readable. [lastSyncedAt]
/// is null when no run ever completed.
final class SyncFailed extends SyncStatus {
  const new({required this.failure, required this.lastSyncedAt});

  final VikunjaFailure failure;
  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncFailed &&
      other.failure == failure &&
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => Object.hash(failure, lastSyncedAt);

  @override
  String toString() => 'SyncFailed($failure, lastSyncedAt: $lastSyncedAt)';
}
