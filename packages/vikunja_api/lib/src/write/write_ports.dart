import 'package:dio/dio.dart';
import 'package:vikunja_api/src/write/write_client.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Task writes. Implementations throw `VikunjaFailure` and rethrow a
/// cancelled request's `DioException`.
abstract interface class TasksWritePort {
  /// v2 `POST /projects/{id}/tasks`, v1 `PUT /projects/{id}/tasks`. Not
  /// idempotent: a lost response leaves a task behind on the server.
  Future<Task> create(NewTask task);

  /// Applies [changes] and returns the task as the server stored it: a
  /// repeating task marked done comes back open with shifted dates, so the
  /// caller must replace its local copy with the result.
  ///
  /// v2 sends a merge-patch with only the set fields. v1 has no partial
  /// update: the adapter reads the task, overlays [changes] and posts the
  /// whole object back, keeping assignees and reminders intact.
  ///
  /// A move ([TaskChanges.projectId]) ends with a read of the task: the
  /// server answers it with the new `project_id` and `index` but the
  /// `identifier` of the old project.
  Future<Task> update(int id, TaskChanges changes);

  /// A task that is already gone (404 with Vikunja code 4002) counts as
  /// deleted and does not throw.
  Future<void> delete(int id);
}

abstract interface class VikunjaWriteClient {
  TasksWritePort get tasks;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaWriteClient createWriteClient({
  required Dio dio,
  required ServerConnection connection,
}) => WriteClient(dio: dio, connection: connection);
