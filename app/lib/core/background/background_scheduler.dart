/// The OS side of background work: Android WorkManager, iOS BGTaskScheduler
/// (through the `workmanager` plugin). Registered once per app start.
abstract interface class BackgroundScheduler {
  /// The periodic sync of every signed-in account; replaces an existing
  /// registration with the same settings (no duplicate work).
  Future<void> registerPeriodicSync();

  /// A one-off run soon, for a change that waits for a token refresh (a
  /// notification's Done whose access token had expired). Android only;
  /// a no-op on iOS, which has no on-demand background runs.
  Future<void> enqueueDrain();

  /// Everything off; after the last account signed out.
  Future<void> cancelAll();
}
