import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/read/read_client.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Read access to the resources the first screens need. Implementations
/// throw `VikunjaFailure` and rethrow a cancelled request's `DioException`.
abstract interface class ProjectsPort {
  /// Real projects plus the pseudo projects (Favorites, saved filters),
  /// which the server repeats on every page.
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  });

  /// Every page, pseudo projects de-duplicated.
  Future<List<Project>> listAll({bool includeArchived = false});

  /// Includes the project's views.
  Future<Project> read(int id);
}

abstract interface class LabelsPort {
  Future<Page<Label>> list({int page = 1, int? perPage, String? search});

  Future<List<Label>> listAll();
}

abstract interface class TasksPort {
  /// All tasks the user can see, across projects (`GET /tasks`).
  Future<Page<Task>> list(TaskQuery query);

  /// Tasks of one project, without any view filter.
  Future<Page<Task>> listInProject(int projectId, TaskQuery query);

  /// Tasks through a view: the view's own filter and sort apply server-side
  /// on top of [query]. Never used with kanban views here.
  Future<Page<Task>> listInView(int projectId, int viewId, TaskQuery query);

  Future<Task> read(int id, {Set<TaskExpand> expand = const {}});

  /// What only a single read carries: `GET /tasks/{id}` with the repeated
  /// `expand=reactions`, `comment_count` and `is_unread`.
  Future<TaskDetails> readDetails(int id);

  /// `GET /projects/{project}/tasks/by-index/{index}`: [project] is a
  /// numeric project id, or a project identifier (any case, percent-encoded
  /// by the port). A v2 307 for an index the task had before it moved to
  /// another project is followed once, keeping the authorization and
  /// re-attaching the root-relative `Location` (it hard-codes `/api/v2`) to
  /// the configured base; v1 never redirects. Unknown project and unknown
  /// index are `NotFound`, an unreadable project `Forbidden`. The
  /// identifiers `.` and `..` cannot be put in a path and are `NotFound`
  /// without a request.
  Future<Task> readByIndex(String project, int index);
}

abstract interface class CommentsPort {
  /// `GET /tasks/{id}/comments`, one page (default and cap: the server's
  /// `max_items_per_page`). The server sorts by `created` with second
  /// resolution, so the caller sorts a page by `(created, id)` itself.
  /// Each comment carries its reactions. A task with comments disabled on
  /// the server answers `NotFound`.
  Future<Page<TaskComment>> list(
    int taskId, {
    int page = 1,
    int? perPage,
    bool newestFirst = false,
  });
}

enum AttachmentPreviewSize {
  small('sm'),
  medium('md'),
  large('lg'),
  extraLarge('xl');

  new(this.wireName);

  final String wireName;
}

/// The largest attachment body [AttachmentsPort.fetch] takes.
const int maxAttachmentBytes = 25 * 1024 * 1024;

abstract interface class AttachmentsPort {
  /// `GET /tasks/{task}/attachments/{id}`: the original, or with [preview]
  /// a PNG of that width (100, 200, 400 or 800 px, height proportional,
  /// small images upscaled). For files the server cannot preview
  /// (anything but decodable images) it answers the original, so check
  /// [AttachmentBlob.contentType]. A missing attachment is `NotFound`, a
  /// foreign one `Forbidden`; a body above [maxAttachmentBytes] is refused
  /// while it arrives, with `UnexpectedResponse`.
  Future<AttachmentBlob> fetch(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  });
}

final class AttachmentBlob {
  const new({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// The response's media type without parameters, e.g. `image/png`.
  final String contentType;

  bool get isSvg => contentType == 'image/svg+xml';
}

abstract interface class UsersPort {
  /// The users who can be assigned to tasks of [projectId]: owner, shares
  /// and team members, matched by [query] on username and name (and email
  /// where the user allows it); an empty query lists them all. v2
  /// `GET /projects/{id}/users/search?q=`, v1
  /// `GET /projects/{id}/projectusers?s=`. One page, never paged.
  Future<List<User>> searchProjectUsers(int projectId, {String query = ''});
}

abstract interface class NotificationsPort {
  /// The user's notifications, newest first: v2 envelope, v1 bare array
  /// with paging headers. Only notifications of projects the user can
  /// still read come back.
  Future<Page<ServerNotification>> list({int page = 1, int? perPage});
}

abstract interface class SubscriptionsPort {
  /// The subscription covering the task (its own or a parent project's),
  /// from `GET /tasks/{id}`; null when not subscribed.
  Future<Subscription?> forTask(int taskId);

  /// From `GET /projects/{id}`; null when not subscribed.
  Future<Subscription?> forProject(int projectId);
}

abstract interface class AvatarsPort {
  /// `GET /avatar/{username}?size=`: the user's avatar in whatever format
  /// their avatar provider makes (PNG, JPEG, or SVG for some providers).
  /// An unknown username gets the server's placeholder; an answer that is
  /// not an image (`image/*` or `application/octet-stream`) or is empty
  /// throws `UnexpectedResponse`.
  Future<AvatarImage> fetch(String username, {required int size});
}

final class AvatarImage {
  const new({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// The response's media type without parameters, e.g. `image/png`.
  final String contentType;

  bool get isSvg => contentType == 'image/svg+xml';
}

abstract interface class VikunjaReadClient {
  ProjectsPort get projects;
  LabelsPort get labels;
  TasksPort get tasks;
  UsersPort get users;
  NotificationsPort get notifications;
  SubscriptionsPort get subscriptions;
  AvatarsPort get avatars;
  CommentsPort get comments;
  AttachmentsPort get attachments;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaReadClient createReadClient({
  required Dio dio,
  required ServerConnection connection,
}) => ReadClient(dio: dio, connection: connection);
