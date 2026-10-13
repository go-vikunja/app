import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

/// The task as this device holds it, or null when it is not here (never
/// synced, deleted, or in a project the account cannot see any more).
///
/// `Stream.first` waits for the cancel; this does not, so a source whose
/// cancel never completes cannot hold the caller.
Future<Task?> findLocalTask(TaskRepository repository, int taskId) {
  final completer = Completer<Task?>();
  late final StreamSubscription<Task?> subscription;
  subscription = repository
      .watchTask(taskId)
      .listen(
        (value) {
          if (!completer.isCompleted) completer.complete(value);
          unawaited(subscription.cancel());
        },
        onError: (Object error, StackTrace stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
          unawaited(subscription.cancel());
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(null);
        },
      );
  return completer.future;
}
