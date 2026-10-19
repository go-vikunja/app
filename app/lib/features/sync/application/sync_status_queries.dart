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
