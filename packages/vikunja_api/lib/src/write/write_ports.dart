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
  ///
  /// [TaskChanges.reminders] replace the reminder list in the same request;
  /// the task is read back, because the server answers with the list as
  /// sent but stores only the last reminder per instant. A date change is
  /// read back too: relative reminders it moves onto one instant (all those
  /// of a cleared date) are merged the same way.
  /// [TaskChanges.labels] and [TaskChanges.assignees] go through the
  /// task's label and assignee endpoints afterwards, only for the ids
  /// whose state on the server differs, so a repeated call after a lost
  /// answer changes nothing twice; the result is then read back.
  Future<Task> update(int id, TaskChanges changes);

  /// A task that is already gone (404 with Vikunja code 4002) counts as
  /// deleted and does not throw.
  Future<void> delete(int id);
}

abstract interface class LabelsWritePort {
  /// v2 `POST /labels`, v1 `PUT /labels`.
  Future<Label> create(NewLabel label);
}

abstract interface class NotificationsWritePort {
  /// v2 `PUT /notifications/{id}`, v1 `POST /notifications/{id}`, body
  /// `{read}`. A notification that is gone (403, or a 404 with a Vikunja
  /// code) counts as done and does not throw.
  Future<void> markRead(int id, {bool read = true});

  /// `POST /notifications` on both versions.
  Future<void> markAllRead();
}

abstract interface class VikunjaWriteClient {
  TasksWritePort get tasks;
  LabelsWritePort get labels;
  NotificationsWritePort get notifications;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaWriteClient createWriteClient({
  required Dio dio,
  required ServerConnection connection,
}) => WriteClient(dio: dio, connection: connection);
