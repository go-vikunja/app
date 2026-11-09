import 'package:dio/dio.dart';
import 'package:vikunja_api/src/read/read_ports.dart';
import 'package:vikunja_api/src/write/user_settings_write_api.dart';
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
  /// request. A missing other task, deleted or in the trash itself or with
  /// its project, fails with `RelatedTaskMissing` carrying the server's code,
  /// never with the plain `NotFound` that means this task is gone. A remove
  /// meeting such a task counts as done when this task no longer lists the
  /// edge; on 2.8.0 the edge comes back if the other task is restored.
  ///
  /// [TaskChanges.kanban] goes last, per view: the move (v2 `PUT`, v1
  /// `POST /projects/{task's project}/views/{v}/buckets/{b}/tasks`), then,
  /// with a position and only when the server put the task into that
  /// bucket (a repeating task moved into the done bucket reopens in the
  /// default bucket), the position (v2 `PUT`, v1 `POST
  /// /tasks/{id}/position`). A move into the bucket the task is in already
  /// changes nothing, so a repeated call is harmless. A move that changed
  /// the task (done, `done_at`, a repeating task's dates) is read back. A
  /// full bucket is a `DomainError` code 10004, a bucket that is gone or
  /// not one of a manual view's (filter mode) a `NotFound` code 10001 or a
  /// `DomainError` code 10002.
  ///
  /// [TaskChanges.positions] follow, per view: the position (v2 `PUT`, v1
  /// `POST /tasks/{id}/position`) without a read-back. The server may store
  /// another value (it spreads equal positions, below 0.01 it renumbers the
  /// view). A view the task cannot be placed in (a read share, another
  /// project's view, a saved filter's view the task does not match) is a
  /// `Forbidden`, a view that is gone a `NotFound` code 3014.
  ///
  /// [TaskChanges.coverImageAttachmentId] goes into the body like the other
  /// fields. The server keeps the cover id when that attachment is deleted
  /// and then refuses every update that does not clear it (v2 patches and
  /// v1 full replaces alike) with a `DomainError` code 4020, which is also
  /// the answer for an id that is not one of the task's attachments.
  ///
  /// [TaskChanges.descriptionBase] and [TaskChanges.checklistToggles] are
  /// never sent. With [rebaseDescription] and a [TaskChanges.description],
  /// the description sent is what [rebaseDescription] returns for the one
  /// the server has right before the write; what it throws ends the call
  /// before any write. v1 passes the description of the read its full
  /// replace makes anyway, v2 reads the task first. The server has no
  /// preconditions, so a change on the web between that read and the write
  /// is still overwritten.
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  });

  /// A task that is already gone counts as deleted and does not throw: 404
  /// code 4002, or from 2.8.0 on code 4040 for a task in the trash and 3001
  /// for one whose project is in the trash.
  Future<void> delete(int id);

  /// v2 `POST /tasks/{id}/duplicate`, v1 `PUT`: the server copies the task
  /// with its labels, assignees, attachments and reminders and adds a
  /// `copiedfrom` relation; returns the copy. Not idempotent.
  Future<Task> duplicate(int id);

  /// v2 `PUT /tasks/{id}/read`, v1 `POST`: clears the task's unread flag.
  /// Idempotent and unconditional on the server (a read, missing or
  /// inaccessible task all answer 200), so there is nothing to tolerate.
  Future<void> markRead(int id);
}

/// Changing or deleting a label is for its creator alone: anyone else is
/// `Forbidden` without a code. A label that is gone, or that the user can
/// no longer see, is a `NotFound` code 8002.
abstract interface class LabelsWritePort {
  /// v2 `POST /labels`, v1 `PUT /labels`.
  Future<Label> create(NewLabel label);

  /// Writes only what [changes] set and returns the label as stored: v2 a
  /// merge-patch (an unchanged label answers 304 and is read), v1 a read
  /// posted back whole with [changes] overlaid, keeping a colour or
  /// description another client wrote that this one does not parse. A
  /// title the server refuses (above 250 code points, v2 an empty one) is a
  /// `ValidationFailed`; v1 stores an empty title, so callers check it.
  /// The tasks carrying the label show the change at once, without a bump
  /// of their `updated`. The server refuses a label that is gone like
  /// someone else's (the read both writes start with is a 403), so after a
  /// `Forbidden` the port looks the id up in the label list: absent, it is
  /// the `NotFound`. Empty changes are a read.
  Future<Label> update(int id, LabelChanges changes);

  /// `DELETE /labels/{id}`; from 2.7.0 the server also takes it off every
  /// task, without a bump of their `updated`. One that is gone already
  /// (404 code 8002) counts as deleted.
  Future<void> delete(int id);
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

/// The buckets of a manual kanban view: project write permission, refused
/// with 403 for a read share and with `DomainError` code 3008 while the
/// project is archived. The view id must be the bucket's own view: the
/// server counts and re-points by the URL's view. A bucket that does not
/// exist is a `NotFound` code 10001; a title the server refuses (empty) a
/// `ValidationFailed`.
abstract interface class BucketsWritePort {
  /// v2 `POST`, v1 `PUT /projects/{p}/views/{v}/buckets` with `{title,
  /// limit, position}`. Without a [position] the server picks `id × 65536`,
  /// usually the rightmost. Not idempotent. The answer has `count` 0.
  /// From 2.7.1 a view holds at most 100 buckets; one more is a
  /// `DomainError` 412 code 10007.
  Future<Bucket> create(
    int projectId,
    int viewId, {
    required String title,
    int limit = 0,
    double? position,
  });

  /// v2 `PUT`, v1 `POST /projects/{p}/views/{v}/buckets/{b}`: the server
  /// replaces title, limit and position together, so all three are sent.
  /// Returns what was sent with `count` 0: the answer's count and dates are
  /// not the stored ones.
  Future<Bucket> update(
    int projectId,
    int viewId, {
    required int bucketId,
    required String title,
    required int limit,
    required double position,
  });

  /// `DELETE /projects/{p}/views/{v}/buckets/{b}`. The server moves the
  /// bucket's tasks to the view's default bucket (else its leftmost),
  /// positions kept, and clears the view's done or default bucket when it
  /// was this one. The last bucket of a view is a `DomainError` code 10003.
  /// A bucket that is gone already (404 code 10001) counts as deleted.
  Future<void> delete(int projectId, int viewId, int bucketId);
}

abstract interface class ProjectViewsWritePort {
  /// Changes only the given bucket ids of a kanban view, 0 clearing one,
  /// and returns the view as stored. Project admin permission (403 for
  /// write shares too); allowed on an archived project. Setting or clearing
  /// the done bucket changes no task. A bucket of another view is a
  /// `DomainError` code 10002; an id that does not exist is stored as 0.
  ///
  /// v2 sends a merge-patch with only these ids (an unchanged view answers
  /// 304 and is read). v1 has only a full replace, which turns a view sent
  /// without its kind into a list view: the adapter reads the view and
  /// posts every field back with the change.
  Future<ProjectView> setBuckets(
    int projectId,
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  });

  /// v2 `POST`, v1 `PUT /projects/{p}/views`; never with a `project_id` in
  /// the body (v1 would create the view in that project). A new board
  /// without a manual or filter mode gets To-Do, Doing and Done. Not
  /// idempotent.
  ///
  /// The view writes need project admin permission (`Forbidden` for write
  /// shares too) and are allowed on archived projects. A filter the server
  /// cannot parse is a `DomainError` code 4024, a bad value code 4019, an
  /// unknown field code 4016; references to other projects, labels or users
  /// are not checked. A view that does not exist, or one of another project,
  /// is a `NotFound` code 3014.
  Future<ProjectView> create(int projectId, ViewDraft view);

  /// Writes the draft's fields and returns the view as stored; kind changes
  /// keep the board's buckets. v2 sends a merge-patch (an unchanged view
  /// answers 304 and is read), v1 reads the view and posts every field back
  /// with the draft overlaid.
  Future<ProjectView> update(int projectId, int viewId, ViewDraft view);

  /// Changes only the view's position (any value, never renumbered) and
  /// returns the view as stored: v2 a merge-patch of the position, v1 a
  /// fresh read posted back with it. A draft of the view as the app last
  /// synced it would bring back a kind, filter or bucket mode changed
  /// elsewhere, and a board's mode switched back to manual gets new default
  /// buckets with every task in the first.
  Future<ProjectView> move(
    int projectId,
    int viewId, {
    required double position,
  });

  /// `DELETE /projects/{p}/views/{v}`. The server allows deleting the last
  /// view. A view that is gone already (404 code 3014) counts as deleted.
  Future<void> delete(int projectId, int viewId);
}

/// The projects these answer carry no [Project.maxPermission]: write
/// answers never have it computed (servers before 2.6 send 0 for that).
abstract interface class ProjectsWritePort {
  /// Puts the project at [position] under [parentProjectId] (0 for the top
  /// level) and returns it as stored; every other field stays. A position
  /// below 0.1 is an [ArgumentError] before any request: the server would
  /// renumber all siblings, for the top level those of every user.
  ///
  /// v2 sends a merge-patch with both fields (an unchanged project answers
  /// 304 and is read). v1 has only a full replace, which clears what it is
  /// not sent: the adapter reads the project and posts it back whole.
  ///
  /// Reordering needs write permission (`Forbidden` otherwise), a parent
  /// change admin permission on the project and the new parent
  /// (`Forbidden` code 1). An archived project or parent is a
  /// `DomainError` code 3008; the project itself as the parent code 3010,
  /// one of its descendants code 3011, a pseudo project code 3009. A
  /// project or parent that does not exist is a `NotFound` code 3001.
  Future<Project> move(
    int projectId, {
    required double position,
    required int parentProjectId,
  });

  /// v2 `POST`, v1 `PUT /projects` with only the fields set; returns the
  /// project with its four default views. Not idempotent. An archived parent
  /// is a `DomainError` code 3008, a pseudo one code 3009, a parent without
  /// write permission `Forbidden`, one that does not exist `NotFound` code
  /// 3001.
  Future<Project> create(NewProject project);

  /// Applies [changes] and returns the project as stored. v2 sends a
  /// merge-patch with only the set fields (an unchanged project answers 304
  /// and is read); v1 reads the project and posts it back whole with the
  /// changes overlaid, keeping position, favourite, archive state,
  /// identifier, colour and description. Empty changes are a read.
  ///
  /// A [ProjectChanges.position] below 0.1 is an `ArgumentError` before any
  /// request, as for [move]. The server renumbers the siblings after any
  /// update that leaves the project below 0.1, so a project stored there
  /// needs a position of 0.1 or more in the same changes.
  ///
  /// Needs write permission (`Forbidden` otherwise); a parent change admin
  /// permission, refused as for [move]. An identifier used by any project on
  /// the instance is a `DomainError` code 3007. While the project is
  /// archived everything but unarchiving is code 3008; unarchiving under an
  /// archived parent is code 3016, archiving the owner's default project
  /// code 3013.
  ///
  /// An identifier change renames every task's identifier without bumping
  /// the tasks' `updated`; archiving and unarchiving cascade to every
  /// descendant and bump theirs.
  ///
  /// With [rebaseDescription] and a [ProjectChanges.description], the
  /// description sent is what [rebaseDescription] returns for the one the
  /// server has right before the write, as for a task's; what it throws
  /// ends the call before any write. v1 passes the description of the read
  /// its full replace makes anyway, v2 reads the project first.
  Future<Project> update(
    int projectId,
    ProjectChanges changes, {
    String Function(String current)? rebaseDescription,
  });

  /// `DELETE /projects/{id}`: the server deletes the project's tasks and its
  /// whole subtree, also projects of other users in it (from 2.8.0 on into
  /// the trash, from where they can be restored for 30 days). Admin permission
  /// (`Forbidden` otherwise); another user's default project is a
  /// `DomainError` code 3012, the owner may delete their own. A project that
  /// is gone already (404 code 3001, also when it is in the trash) counts as
  /// deleted.
  Future<void> delete(int projectId);

  /// v2 `POST`, v1 `PUT /projects/{id}/duplicate`; returns the copy, which
  /// the server fills in the same request: "<title> - duplicate" with no
  /// identifier, the source's position, tasks (done ones too), views,
  /// buckets and positions, but no child projects and not the favourite.
  /// [copyShares] copies the user, team and link shares. Read permission on
  /// the source and write permission on the parent (0 for the top level)
  /// are enough. Not idempotent.
  ///
  /// A pseudo project (an id below 1) is an [ArgumentError] before any
  /// request: the server would copy its tasks into a broken real project.
  Future<Project> duplicate(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  });
}

/// Saved filters of the signed-in user. There is no list endpoint: the
/// project list names them as pseudo projects. The server checks the filter
/// on every write: one it cannot parse is a `DomainError` code 4024, a bad
/// value code 4019, an unknown field code 4016; a filter without text,
/// search, sort or include-nulls is code 2002 (v1 a 412 `DomainError`, v2 a
/// 422 `ValidationFailed`), and so is a title outside 1 to 250 characters.
/// Another user's saved filter is `Forbidden`, one that does not exist a
/// `NotFound` code 11001. The answers of create and update have no owner.
abstract interface class SavedFiltersPort implements SavedFiltersReadPort {
  /// v2 `POST`, v1 `PUT /filters`. Not idempotent.
  Future<SavedFilter> create(SavedFilterDraft draft);

  /// Writes every field of the draft and returns the saved filter as
  /// stored: v2 a merge-patch (an unchanged one answers 304 and is read),
  /// v1 a read posted back whole with the draft overlaid, which keeps what
  /// this client does not model.
  Future<SavedFilter> update(int id, SavedFilterDraft draft);

  /// Changes only the favourite, like [update].
  Future<SavedFilter> setFavorite(int id, {required bool favorite});

  /// `DELETE /filters/{id}`; one that is gone already (404 code 11001)
  /// counts as deleted. The server keeps the views of the saved filter.
  Future<void> delete(int id);
}

/// A task's attachments; the cover is set through [TasksWritePort.update]
/// with [TaskChanges.coverImageAttachmentId]. Both writes need project
/// write permission (`Forbidden` for a read share) and are a `DomainError`
/// code 3008 while the project is archived. A task that is gone is a
/// `NotFound` with `taskGone`, or `projectGone` when its project is in the
/// trash; a server with attachments switched off answers every attachment
/// route with a `NotFound` without a code.
abstract interface class AttachmentsWritePort {
  /// v2 `POST`, v1 `PUT /tasks/{id}/attachments`: one multipart part
  /// `files` with [bytes], which must be exactly [length] bytes long and is
  /// read once; a request the server refuses with 401 code 11 is not
  /// repeated, the token is refreshed for the next one. Not idempotent:
  /// every call adds an attachment, also under a name the task already has.
  ///
  /// The server keeps [fileName] as sent apart from what precedes a `/`; a
  /// blank one would mean no file, so it is sent as `file`. It sniffs the
  /// type from the bytes, so [mimeType] only labels the part.
  ///
  /// A file above the limit is [FileTooLarge]: the server's per-file code
  /// 4012, a 413 from the server or a proxy, or a connection closed while a
  /// body longer than the server takes (its file limit plus 2 MiB) was being
  /// sent; a closed connection with a shorter body is a `NetworkFailure`.
  /// [timeout] bounds sending the body and, again, waiting for the answer;
  /// null keeps the client's defaults, which suit only small files. An
  /// error of [bytes] is rethrown as it is.
  Future<TaskAttachment> upload(
    int taskId, {
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    String? mimeType,
    Duration? timeout,
    CancelToken? cancel,
  });

  /// `DELETE /tasks/{task}/attachments/{id}`. One that is gone already
  /// (404 code 4011) counts as deleted. The server bumps the task's
  /// `updated` but leaves a cover pointing at a deleted attachment set.
  Future<void> delete(int taskId, int attachmentId);
}

/// A task's comments, in the web editor's HTML, which the server stores as
/// sent. Writing needs project write permission (`Forbidden` for a read
/// share) and is a `DomainError` code 3008 while the project is archived;
/// changing or deleting a comment is for its author alone, `Forbidden` even
/// for the project's owner. A task that is gone is a `NotFound` with
/// `taskGone`, or `projectGone` when its project is in the trash; a comment
/// that does not exist (or belongs to another task) is code 4015. A server
/// with comments switched off answers every route with a `NotFound` without
/// a code.
///
/// The server reports any update or delete it could not apply as 4015, so
/// before throwing that the comment is read again: when it is still there
/// the write is a `ServerFailure` with status 404 and no code, worth
/// repeating.
abstract interface class CommentsWritePort {
  /// v2 `POST`, v1 `PUT /tasks/{id}/comments` with `{comment}`; returns the
  /// comment as stored. Not idempotent. An empty body is a
  /// `ValidationFailed` code 2002; whitespace and `<p></p>` are not, so the
  /// caller checks for them. A body above the server's limit (1 MiB, 65,000
  /// bytes on MySQL) is a `ValidationFailed` code 2002 on v1 and an
  /// `UnexpectedResponse` 413 on v2. Bumps the task's `updated` and marks
  /// it unread for everyone else with access.
  Future<TaskComment> create(int taskId, String html);

  /// Replaces the comment's body and returns the comment with its author,
  /// `created` and the new `updated`, without reactions (the server never
  /// sends them for one comment): v2 a merge-patch, whose answer is the
  /// stored comment; v1 a read of the comment followed by `POST` with
  /// `{comment}`, whose answer has neither author nor `created`. Only users
  /// mentioned for the first time are notified.
  Future<TaskComment> update(int taskId, int commentId, String html);

  /// `DELETE /tasks/{task}/comments/{id}`. A comment that is gone already
  /// counts as deleted.
  Future<void> delete(int taskId, int commentId);
}

/// The signed-in user's own reactions to a task or a comment (for a comment
/// the id is the comment's, without its task). Both need write permission
/// on the task (`Forbidden` for a read share and for link shares) and are a
/// `DomainError` code 3008 while the project is archived; a task that is
/// gone is a `NotFound` with `taskGone` (or `projectGone`), a comment that
/// does not exist code 4015. Reactions bump no `updated` and notify nobody.
/// The value is sent as it is: the server compares the bytes.
abstract interface class ReactionsWritePort {
  /// v2 `POST`, v1 `PUT /{tasks|comments}/{id}/reactions` with `{value}`.
  /// Adding a value the user reacted with already changes nothing. An empty
  /// value or one longer than [maxReactionLength] code points is an
  /// [ArgumentError] before any request (v1 would store a longer one).
  Future<void> add(ReactionEntity kind, int id, String value);

  /// `POST /{tasks|comments}/{id}/reactions/delete` with `{value}` on both
  /// versions. Removing a value the user did not react with changes
  /// nothing. v2 refuses a value longer than [maxReactionLength] code points
  /// with a `ValidationFailed` without a code, so such a reaction, stored
  /// through v1, can only be removed through v1.
  Future<void> remove(ReactionEntity kind, int id, String value);
}

/// The settings and the profile as stored after a write, read back from
/// `GET /user`: the write answers carry neither.
typedef UserSettingsWriteResult = ({
  UserProfile profile,
  UserSettings settings,
});

/// The signed-in user's general settings and avatar. The server keeps no
/// order between overlapping writes, so callers send one at a time.
abstract interface class UserSettingsWritePort {
  /// Writes only what [changes] set and returns the stored state.
  ///
  /// With [Capability.userSettingsMergePatch] (2.7.0+) a v2 merge-patch of
  /// the changed fields, the `frontend_settings` keys inside it, which the
  /// server merges deeply (a cleared one is `null`, which removes the key);
  /// an unchanged state answers 304. Older servers replace every setting,
  /// an omitted `frontend_settings` wiping the whole object: the adapter
  /// reads the settings fresh from `GET /user`, applies [changes] to that
  /// JSON, keeping every key it does not know, and writes it back whole
  /// (v2 `PUT`, on 2.3 v1 `POST /user/settings/general`).
  ///
  /// Refusals: a timezone the server cannot load is a `DomainError` code
  /// 1025, a default project that is archived, missing or not writable code
  /// 3017; a week start outside 0–6 or a reminder time the server cannot
  /// parse a `ValidationFailed` (code 2002, or none for v2's own schema
  /// check) naming the field.
  Future<UserSettingsWriteResult> update(UserSettingsChanges changes);

  /// v2 `GET /user/settings/avatar/provider`, v1 `GET
  /// /user/settings/avatar`; null for a value this client does not know.
  Future<AvatarProvider?> avatarProvider();

  /// v2 `PUT /user/settings/avatar/provider`, v1 `POST
  /// /user/settings/avatar`; bumps the user's `updated`. [AvatarProvider.upload]
  /// without an uploaded image makes the server fail every request for
  /// the avatar. The sign-in providers' values are an [ArgumentError]
  /// before any request; a value the server does not know is a
  /// `DomainError` code 1018.
  Future<void> setAvatarProvider(AvatarProvider provider);

  /// v2 `PUT /user/settings/avatar`, v1 `PUT /user/settings/avatar/upload`:
  /// one multipart part `avatar` with [bytes], exactly [length] bytes long
  /// and read once. The server sets the provider to `upload` itself and
  /// bumps the user's `updated`. It sniffs PNG, JPEG, GIF, BMP, TIFF and
  /// WebP from the bytes, fits the image into 1024 × 1024 keeping its
  /// aspect ratio and ignores EXIF orientation, so callers crop and rotate
  /// first.
  ///
  /// Anything else is a `ValidationFailed` naming `avatar`; more than 50
  /// megapixels a `DomainError` code 4032; a body above the server's
  /// request limit [FileTooLarge]. [timeout] bounds sending and, again,
  /// waiting for the answer.
  Future<void> uploadAvatar({
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    Duration? timeout,
  });
}

abstract interface class VikunjaWriteClient {
  TasksWritePort get tasks;
  AttachmentsWritePort get attachments;
  CommentsWritePort get comments;
  ReactionsWritePort get reactions;
  LabelsWritePort get labels;
  NotificationsWritePort get notifications;
  SubscriptionsWritePort get subscriptions;
  BucketsWritePort get buckets;
  ProjectViewsWritePort get views;
  ProjectsWritePort get projects;
  SavedFiltersPort get savedFilters;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaWriteClient createWriteClient({
  required Dio dio,
  required ServerConnection connection,
}) => WriteClient(dio: dio, connection: connection);

/// Over [dio] and [connection] like [createWriteClient].
UserSettingsWritePort createUserSettingsWritePort({
  required Dio dio,
  required ServerConnection connection,
}) => UserSettingsWriteApi(dio: dio, connection: connection);
