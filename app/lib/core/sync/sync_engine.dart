import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Pulls one account's data from the server into its local database. Works
/// without a widget tree. Runs are serialized per account: a call while a run
/// is in progress joins that run, except for [refreshInNewRun] and
/// [refreshAfterWrite].
abstract interface class SyncEngine {
  /// Replays the current status on subscription.
  Stream<SyncStatus> get status;

  SyncStatus get currentStatus;

  /// Completes the first full pull, resuming an interrupted one from its
  /// checkpoint. Returns normally when the account is already synced.
  Future<void> ensureInitialSync();

  /// Pulls what changed since the last run, for the app's own triggers (the
  /// timer, a resume, a background run). Throws the `VikunjaFailure` of
  /// the first request that failed; data from before the run stays readable.
  Future<SyncOutcome> refresh();

  /// [refresh] in a run that starts after this call, for a refresh the
  /// user started (pull to refresh, Sync now): a run that has already
  /// started may have read the server before a change the user expects to
  /// see. Calls while such a run waits share it.
  Future<void> refreshInNewRun();

  /// [refreshInNewRun] for a write the app has just made or a change the
  /// server has just announced: a run that has already started may have
  /// read the server before it, and would then put back (a full one also
  /// purge) what the write stored.
  Future<void> refreshAfterWrite();

  /// A full re-pull that upserts everything and purges rows the server no
  /// longer returns. Fails like [refresh].
  Future<void> fullResync();

  Future<void> dispose();
}

enum SyncOutcome {
  synced,

  /// The run ended without syncing: a headless engine gave way to a run
  /// another isolate holds, another run took the lease, or the engine was
  /// disposed.
  skipped,
}
