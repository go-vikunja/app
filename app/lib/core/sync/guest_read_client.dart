import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A link-share guest's reads. The project list sends a guest no permission
/// (null even with `expand=permissions`), and before 2.6.0 read whatever
/// the share's permission, so the shared project's is read from its single
/// read (`x-max-permission` on v1, the body on v2) whenever a list brings
/// it without one or the server is older than 2.6.0 or of an unknown
/// version: one request per sync run, and the stored permission shapes the
/// screens as for users (decision log: Projects). The shared project's title in
/// a list goes to `onSharedProjectTitle`, for the name of a guest whose share
/// has none.
final class GuestReadClient implements VikunjaReadClient {
  new(
    this._client, {
    required int sharedProjectId,
    required ServerVersion? serverVersion,
    Future<void> Function(String title)? onSharedProjectTitle,
  }) : projects = _GuestProjects(
         _client.projects,
         sharedProjectId,
         onSharedProjectTitle,
         listsPermission: serverVersion?.isAtLeast(2, 6) ?? false,
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
  new(
    this._projects,
    this._sharedProjectId,
    this._onSharedProjectTitle, {
    required this._listsPermission,
  });

  final ProjectsPort _projects;
  final int _sharedProjectId;
  final Future<void> Function(String title)? _onSharedProjectTitle;
  final bool _listsPermission;

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
    if (!projects.any(_needsPermission)) return null;
    return (await _projects.read(_sharedProjectId)).maxPermission;
  }

  bool _needsPermission(Project project) =>
      project.id == _sharedProjectId &&
      (project.maxPermission == null || !_listsPermission);

  Project _withPermission(Project project, Permission permission) =>
      _needsPermission(project)
      ? project.copyWith(maxPermission: permission)
      : project;
}
