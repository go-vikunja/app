import 'package:vikunja_domain/vikunja_domain.dart';

/// Whether the user follows a task or project (comments, changes, …
/// arrive as notifications; on Vikunja 2.8.0 and later also its
/// reminders). Online only: the state is only on single reads, and a
/// toggle goes straight to the server. What a read says is stored for the
/// device's notifications (D80).
abstract interface class SubscriptionRepository {
  /// Throws the `VikunjaFailure` (offline included), and for a task whose
  /// create has not been answered yet `TaskNotSyncedYet`.
  Future<Subscription?> forTask(int taskId);

  Future<Subscription?> forProject(int projectId);

  /// Subscribes, or unsubscribes (an inherited subscription becomes an
  /// opt-out on the server); returns the state read back.
  Future<Subscription?> setTaskSubscribed(
    int taskId, {
    required bool subscribed,
  });

  Future<Subscription?> setProjectSubscribed(
    int projectId, {
    required bool subscribed,
  });
}
