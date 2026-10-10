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

  /// A full re-pull that upserts everything and purges rows the server no
  /// longer returns. Throws the `VikunjaFailure` of the first request that
  /// failed; data from before the run stays readable.
  Future<void> refresh();

  Future<void> dispose();
}
