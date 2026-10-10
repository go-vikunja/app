/// Offered by a task repository that knows which tasks still have a queued
/// change, so their rows can carry the "not yet synced" mark.
abstract interface class PendingTaskIdsSource {
  Stream<Set<int>> watchPendingTaskIds();
}
