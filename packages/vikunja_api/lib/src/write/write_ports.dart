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
  ///
  /// [TaskChanges.relations] follow the same way through the relation
  /// endpoints (removes, then adds), compared with the task's
  /// `related_tasks`; an edge that already exists (409 code 4008) or is
  /// already gone (404 code 4009) counts as done. Every other task id must
  /// be a server id, else this throws an [ArgumentError] before any
  /// request. A missing other task fails with `RelatedTaskMissing`, never
  /// with the plain `NotFound` code 4002 that means this task is gone.
  Future<Task> update(int id, TaskChanges changes);

  /// A task that is already gone (404 with Vikunja code 4002) counts as
  /// deleted and does not throw.
  Future<void> delete(int id);

  /// v2 `POST /tasks/{id}/duplicate`, v1 `PUT`: the server copies the task
  /// with its labels, assignees, attachments and reminders and adds a
  /// `copiedfrom` relation; returns the copy. Not idempotent.
  Future<Task> duplicate(int id);
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

abstract interface class SubscriptionsWritePort {
  /// v2 `POST`, v1 `PUT` `/subscriptions/{entity}/{id}`; an existing
  /// subscription (412 code 12002) counts as done.
  Future<void> subscribe(SubscriptionEntity entity, int id);

  /// `DELETE /subscriptions/{entity}/{id}`; for a subscription inherited
  /// from a parent project the server stores an opt-out. Nothing to delete
  /// (403 without a code) counts as done when a read of the entity shows
  /// no subscription.
  Future<void> unsubscribe(SubscriptionEntity entity, int id);
}

abstract interface class VikunjaWriteClient {
  TasksWritePort get tasks;
  LabelsWritePort get labels;
  NotificationsWritePort get notifications;
  SubscriptionsWritePort get subscriptions;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaWriteClient createWriteClient({
  required Dio dio,
  required ServerConnection connection,
}) => WriteClient(dio: dio, connection: connection);
