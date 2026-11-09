import 'package:dio/dio.dart';
import 'package:vikunja_api/src/trash/trash_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The server's trash of deleted tasks and projects, Vikunja 2.8.0 and
/// newer on `/api/v2` only. Online only: nothing here is stored. Without
/// [Capability.trash] every call throws `NotFound` without a code (route
/// absent) before any request. The server deletes an item for good 30 days
/// after it was moved there. Link shares get `Forbidden` code 1 from the
/// lists, counts and empties. Lists read every page, at most 20, in the
/// server's order: newest deletion first.
abstract interface class TrashPort {
  /// `GET /tasks/deleted`: trashed tasks of the projects the user may write
  /// to. Tasks whose project is archived or in the trash are left out; a
  /// user who may only read gets none.
  Future<List<TrashedTask>> tasks();

  /// `GET /projects/deleted`: the topmost trashed projects the user is
  /// admin of, each with its trashed subprojects. Everyone else gets none.
  Future<List<TrashedProject>> projects();

  /// `GET /tasks/deleted/count`: what [emptyTasks] would delete, which is
  /// only the tasks in projects the user is admin of.
  Future<TrashCount> taskCount();

  /// `GET /projects/deleted/count`: what [emptyProjects] would delete.
  Future<TrashCount> projectCount();

  /// `DELETE /tasks/deleted`: deletes for good the trashed tasks in the
  /// projects the user is admin of; without [includeOthers] only those the
  /// user moved there. The server answers 204 and changes nothing for a
  /// user who is admin nowhere.
  Future<void> emptyTasks({bool includeOthers = true});

  /// `DELETE /projects/deleted`, like [emptyTasks].
  Future<void> emptyProjects({bool includeOthers = true});

  /// `POST /tasks/{id}/restore`, which needs write permission. The task
  /// comes back with its labels, assignees, reminders, attachments and
  /// relations, into its project's default bucket (the Done bucket if
  /// done). A task that is not in the trash (409 code 4042) is read and
  /// returned, so a repeated restore succeeds. `Forbidden` without a code
  /// without write permission; `NotFound` 4002 for a task that is gone,
  /// unknown or unreadable; `DomainError` 412 code 3008 when its project,
  /// or one above it, is archived; `NotFound` 3018 when its project is in
  /// the trash.
  Future<Task> restoreTask(int id);

  /// `POST /projects/{id}/restore`, admin only: brings back its trashed
  /// subprojects and the tasks they held, with views and permission. The
  /// server answers a live project with `NotFound` 3001 too, so a 3001 is
  /// followed by a read: the project is returned when that read succeeds,
  /// else the 3001 is thrown. `Forbidden` without a code for non-admins;
  /// `DomainError` 412 code 3019 when a parent is in the trash, 3016 when
  /// the parent is archived. The user's default project stays unset.
  Future<Project> restoreProject(int id);

  /// `DELETE /tasks/{id}/permanent`, admin only, every link share refused
  /// (`Forbidden` without a code). Not idempotent: a task someone restored
  /// meanwhile answers `NotFound` 4002, like one that is gone. `DomainError`
  /// 412 code 3008 in an archived project; `NotFound` 3018 for a task in a
  /// trashed project.
  Future<void> deleteTaskForever(int id);

  /// `DELETE /projects/{id}/permanent`, admin only: deletes the whole
  /// subtree with every task. Not idempotent: a live project answers
  /// `NotFound` 3001, like one that is gone.
  Future<void> deleteProjectForever(int id);
}

/// Over [dio] and [connection] like `createTeamsPort`.
TrashPort createTrashPort({
  required Dio dio,
  required ServerConnection connection,
}) => TrashApi(dio: dio, connection: connection);
