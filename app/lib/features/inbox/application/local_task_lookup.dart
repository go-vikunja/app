import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/async/first_value.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

/// The task as this device holds it, or null when it is not here (never
/// synced, deleted, or in a project the account cannot see any more).
Future<Task?> findLocalTask(TaskRepository repository, int taskId) =>
    firstValue(repository.watchTask(taskId), orElse: null);
