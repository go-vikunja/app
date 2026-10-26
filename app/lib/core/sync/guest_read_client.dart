import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A link-share guest's reads. The project list sends no permission to a
/// guest (null even with `expand=permissions`), so the shared project's
/// is read from its single read (`x-max-permission` on v1, the body on
/// v2) whenever a list brings it without one: one request per sync run,
/// and the stored permission shapes the screens as for users (D60). The
/// shared project's title in a list goes to `onSharedProjectTitle`, for
/// the name of a guest whose share has none.
final class GuestReadClient implements VikunjaReadClient {
  new(
    this._client, {
    required int sharedProjectId,
    Future<void> Function(String title)? onSharedProjectTitle,
  }) : projects = _GuestProjects(
         _client.projects,
         sharedProjectId,
         onSharedProjectTitle,
       );

  final VikunjaReadClient _client;

  @override
  final ProjectsPort projects;

  @override
  LabelsPort get labels => _client.labels;

  @override
  TasksPort get tasks => _client.tasks;

  @override
  UsersPort get users => _client.users;

  @override
  NotificationsPort get notifications => _client.notifications;

  @override
  SubscriptionsPort get subscriptions => _client.subscriptions;

  @override
  AvatarsPort get avatars => _client.avatars;

  @override
  CommentsPort get comments => _client.comments;

  @override
  AttachmentsPort get attachments => _client.attachments;

  @override
  BucketsPort get buckets => _client.buckets;

  @override
  SavedFiltersReadPort get savedFilters => _client.savedFilters;
}

final class _GuestProjects implements ProjectsPort {
  new(this._projects, this._sharedProjectId, this._onSharedProjectTitle);

  final ProjectsPort _projects;
  final int _sharedProjectId;
  final Future<void> Function(String title)? _onSharedProjectTitle;

  @override
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  }) async {
    final listed = await _projects.list(
      page: page,
      perPage: perPage,
      includeArchived: includeArchived,
      search: search,
    );
    await _noteTitle(listed.items);
    final permission = await _missingPermission(listed.items);
    if (permission == null) return listed;
    return listed.map((project) => _withPermission(project, permission));
  }

  @override
  Future<List<Project>> listAll({bool includeArchived = false}) async {
    final listed = await _projects.listAll(includeArchived: includeArchived);
    await _noteTitle(listed);
    final permission = await _missingPermission(listed);
    if (permission == null) return listed;
    return [for (final project in listed) _withPermission(project, permission)];
  }

  @override
  Future<Project> read(int id) => _projects.read(id);

  Future<void> _noteTitle(List<Project> projects) async {
    final onTitle = _onSharedProjectTitle;
    if (onTitle == null) return;
    for (final project in projects) {
      if (project.id == _sharedProjectId) await onTitle(project.title);
    }
  }

  /// Null when the list already has it, or does not hold the project.
  Future<Permission?> _missingPermission(List<Project> projects) async {
    final needsIt = projects.any(
      (project) =>
          project.id == _sharedProjectId && project.maxPermission == null,
    );
    if (!needsIt) return null;
    return (await _projects.read(_sharedProjectId)).maxPermission;
  }

  Project _withPermission(Project project, Permission permission) =>
      project.id == _sharedProjectId && project.maxPermission == null
      ? project.copyWith(maxPermission: permission)
      : project;
}
