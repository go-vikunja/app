import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Routing keeps the shell away until the engine has reported (null) and
/// the account has completed one full pull.
bool needsFirstSync(SyncStatus? status) => switch (status) {
  SyncIdle() ||
  SyncRunning(initial: false) ||
  SyncFailed(lastSyncedAt: DateTime()) => false,
  _ => true,
};

bool isSyncingQuietly(SyncStatus? status) =>
    status is SyncRunning && !status.initial;

/// The last run could not reach the server; the saved data is what there is.
bool isOffline(SyncStatus? status) =>
    status is SyncFailed && status.failure is NetworkFailure;
