import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';

import 'sample_data.dart';
import 'sync_fakes.dart';

/// View management as the real repository does it, on the views of
/// [projects]: a success changes the project's views in its `all`, like the
/// database would.
///
/// Every call is recorded in [calls] first: `createView 1 Title`,
/// `updateView 1 5 Title`, `moveView 1 5 to 0`, `deleteView 1 5`; the
/// drafts of creates and updates in [drafts]. [beforeCall] can hold one;
/// [failure], or the entry of [failures] for the method name
/// (`createView`, …), is thrown instead while set, and nothing changes.
/// Then the real repository's checks: a blank title is an `ArgumentError`,
/// a project `all` does not have a `NotFound` code 3001, a view it does not
/// have code 3014, the project's only view a [LastViewNotDeletable].
final class FakeProjectViewRepository implements ProjectViewRepository {
  new(this.projects);

  final FakeProjectRepository projects;
  final List<String> calls = [];
  final List<ViewDraft> drafts = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String call)? beforeCall;

  /// Last unless the draft has a position; a board without a manual or
  /// filter mode becomes manual, the other kinds store `none`, as the
  /// server does. The id comes from the projects fake's `nextViewId`.
  @override
  Future<int> createView(int projectId, ViewDraft view) async {
    drafts.add(view);
    await _call('createView', '$projectId ${view.title}');
    final title = _checkedTitle(view.title);
    final project = _project(projectId);
    final id = projects.nextViewId++;
    _replaceViews(project, [
      ...project.views,
      ProjectView(
        id: id,
        projectId: projectId,
        title: title,
        kind: view.kind,
        position:
            view.position ??
            calculateItemPosition(
              sortedViews(project.views).lastOrNull?.position,
              null,
            ),
        filter: view.filter,
        bucketConfigurationMode: storedBucketMode(
          view.kind,
          view.bucketConfigurationMode,
        ),
      ),
    ]);
    return id;
  }

  /// Title, kind and filter as drafted; a mode or position left null stays.
  @override
  Future<void> updateView(int projectId, int viewId, ViewDraft view) async {
    drafts.add(view);
    await _call('updateView', '$projectId $viewId ${view.title}');
    final title = _checkedTitle(view.title);
    final project = _project(projectId);
    final current = _view(project, viewId);
    _replaceView(
      project,
      ProjectView(
        id: viewId,
        projectId: projectId,
        title: title,
        kind: view.kind,
        position: view.position ?? current.position,
        filter: view.filter,
        bucketConfigurationMode: storedBucketMode(
          view.kind,
          view.bucketConfigurationMode ?? current.bucketConfigurationMode,
        ),
        defaultBucketId: current.defaultBucketId,
        doneBucketId: current.doneBucketId,
      ),
    );
  }

  @override
  Future<void> moveView(
    int projectId,
    int viewId, {
    required int toIndex,
  }) async {
    await _call('moveView', '$projectId $viewId to $toIndex');
    final project = _project(projectId);
    final current = _view(project, viewId);
    final position = planViewMove(project.views, viewId, toIndex);
    if (position == null) return;
    _replaceView(project, viewAt(current, position));
  }

  @override
  Future<void> deleteView(int projectId, int viewId) async {
    await _call('deleteView', '$projectId $viewId');
    final project = _project(projectId);
    _view(project, viewId);
    if (project.views.length == 1) throw const LastViewNotDeletable();
    _replaceViews(project, [
      for (final view in project.views)
        if (view.id != viewId) view,
    ]);
  }

  Future<void> _call(String method, String arguments) async {
    final call = '$method $arguments';
    calls.add(call);
    await beforeCall?.call(call);
    if (failures[method] ?? failure case final failure?) throw failure;
  }

  Project _project(int projectId) =>
      projects.find(projectId) ?? (throw const NotFound(code: 3001));

  static ProjectView _view(Project project, int viewId) =>
      project.views.where((view) => view.id == viewId).firstOrNull ??
      (throw const NotFound(code: 3014));

  void _replaceView(Project project, ProjectView view) =>
      _replaceViews(project, [
        for (final existing in project.views)
          if (existing.id == view.id) view else existing,
      ]);

  void _replaceViews(Project project, List<ProjectView> views) {
    projects.all = [
      for (final candidate in projects.all)
        if (candidate.id == project.id)
          copyProject(candidate, views: sortedViews(views))
        else
          candidate,
    ];
  }

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }
}
