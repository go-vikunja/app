import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

const _projectDoesNotExist = 3001;
const _viewDoesNotExist = 3014;

/// View changes straight to the server, written into the stored project
/// once answered. A sync then runs quietly, and a created or edited list or
/// board is downloaded after it: its stored tasks were picked by the old
/// filter or kind, or there are none yet.
final class LocalProjectViewRepository implements ProjectViewRepository {
  new(
    this._db,
    this._sync,
    this._write,
    this._read, {
    required this._perPage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncEngine _sync;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final int _perPage;
  final DateTime Function() _now;

  @override
  Future<int> createView(int projectId, ViewDraft view) async {
    final title = _checkedTitle(view.title);
    final project = await _stored(projectId);
    final created = await _write.views.create(
      projectId,
      ViewDraft(
        title: title,
        kind: view.kind,
        filter: view.filter,
        bucketConfigurationMode: view.bucketConfigurationMode,
        position:
            view.position ??
            calculateItemPosition(
              sortedViews(project.views).lastOrNull?.position,
              null,
            ),
      ),
    );
    await _db.projectsDao.putView(created);
    _settle('Created view ${created.id}', download: created);
    return created.id;
  }

  @override
  Future<void> updateView(int projectId, int viewId, ViewDraft view) async {
    final title = _checkedTitle(view.title);
    _find(await _stored(projectId), viewId);
    final updated = await _write.views.update(
      projectId,
      viewId,
      ViewDraft(
        title: title,
        kind: view.kind,
        filter: view.filter,
        bucketConfigurationMode: view.bucketConfigurationMode,
        position: view.position,
      ),
    );
    await _db.projectsDao.putView(updated);
    _settle('Updated view $viewId', download: updated);
  }

  @override
  Future<void> moveView(
    int projectId,
    int viewId, {
    required int toIndex,
  }) async {
    final project = await _stored(projectId);
    _find(project, viewId);
    final position = planViewMove(project.views, viewId, toIndex);
    if (position == null) return;
    final moved = await _write.views.move(
      projectId,
      viewId,
      position: position,
    );
    await _db.projectsDao.putView(moved);
    _settle('Moved view $viewId');
  }

  @override
  Future<void> deleteView(int projectId, int viewId) async {
    final project = await _stored(projectId);
    _find(project, viewId);
    if (project.views.length <= 1) throw const LastViewNotDeletable();
    await _write.views.delete(projectId, viewId);
    await _db.transaction(() async {
      await _db.projectsDao.removeView(viewId);
      await LocalListPreferences(_db).forget(viewIds: {viewId});
    });
    _settle('Deleted view $viewId');
  }

  Future<Project> _stored(int projectId) async =>
      await _db.projectsDao.loadProject(projectId) ??
      (throw const NotFound(code: _projectDoesNotExist));

  /// A view the stored project no longer has went with a sync, which only
  /// drops what the server no longer has.
  static ProjectView _find(Project project, int viewId) =>
      project.views.where((view) => view.id == viewId).firstOrNull ??
      (throw const NotFound(code: _viewDoesNotExist));

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }

  void _settle(String done, {ProjectView? download}) {
    _log.fine(done);
    unawaited(_afterWrite(download));
  }

  Future<void> _afterWrite(ProjectView? view) async {
    try {
      await _sync.refreshAfterWrite();
    } on Object catch (error) {
      _log.fine('Sync after a view change failed: ${error.runtimeType}');
    }
    if (view == null) return;
    try {
      switch (view.kind) {
        case ProjectViewKind.list:
          await downloadViewSnapshot(
            db: _db,
            client: _read,
            perPage: _perPage,
            projectId: view.projectId,
            viewId: view.id,
            now: _now,
          );
        case ProjectViewKind.kanban:
          await downloadBoard(
            db: _db,
            client: _read,
            perPage: _perPage,
            projectId: view.projectId,
            viewId: view.id,
            now: _now,
          );
        case ProjectViewKind.gantt || ProjectViewKind.table:
          return;
      }
    } on Object catch (error) {
      _log.fine(
        'Download of view ${view.id} after a change failed: '
        '${error.runtimeType}',
      );
    }
  }
}
