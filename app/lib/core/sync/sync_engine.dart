import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Pulls one account's data from the server into its local database. Works
/// without a widget tree. Runs are serialized per account: a call while a run
/// is in progress joins that run.
abstract interface class SyncEngine {
  /// Replays the current status on subscription.
  Stream<SyncStatus> get status;

  SyncStatus get currentStatus;

  /// Completes the first full pull, resuming an interrupted one from its
  /// checkpoint. Returns normally when the account is already synced.
  Future<void> ensureInitialSync();

  /// Pulls what changed since the last run. Throws the `VikunjaFailure` of
  /// the first request that failed; data from before the run stays readable.
  Future<void> refresh();

  /// [refresh] in a run that starts after this call, for a write the app
  /// has just made: a run that has already started may have read the
  /// server before it, and a full one would then put back or purge what the
  /// write stored. Calls while such a run waits share it.
  Future<void> refreshAfterWrite();

  /// A full re-pull that upserts everything and purges rows the server no
  /// longer returns. Fails like [refresh].
  Future<void> fullResync();

  Future<void> dispose();
}
