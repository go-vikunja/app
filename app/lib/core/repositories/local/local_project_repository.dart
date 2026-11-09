import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/incremental_run.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Below it the server renumbers every sibling of the project, at the top
/// level those of every user on the instance.
const _lowestPosition = 0.1;

const _maxIdentifierLength = 10;
const _defaultProjectNotArchivable = 3013;
const _parentArchived = 3016;

/// Projects from the account's database; a refresh is a full sync run. A
/// write goes straight to the server and into the stored projects once
/// answered; the sync that follows quietly brings what else the server
/// changed. Without `trash` a restore is refused as on a server without
/// the trash.
final class LocalProjectRepository implements ProjectRepository {
  new(this._db, this._sync, this._write, {this._trash});

  final AppDatabase _db;
  final SyncEngine _sync;
  final VikunjaWriteClient _write;
  final TrashPort? _trash;
  List<Project> _latest = const [];

  @override
  Stream<List<Project>> watchAll() =>
      _db.projectsDao.watchAll().map((projects) => _latest = projects);

  @override
  Future<void> refresh() => _sync.refresh();

  /// From the last list a subscriber received; null before the first one.
  @override
  Project? find(int id) {
    for (final project in _latest) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Stream<List<SavedFilterRef>> watchSavedFilters() => _db.syncStateDao
      .watchValue(SyncStateKeys.savedFilters)
      .map((stored) => sortedByTitle(decodeSavedFilters(stored)))
      .distinct(listEquals);

  @override
  Future<void> moveProject(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) async {
    if (!(position >= _lowestPosition) || position.isInfinite) {
      throw ArgumentError.value(position, 'position');
    }
    final moved = await _write.projects.move(
      projectId,
      position: position,
      parentProjectId: parentProjectId,
    );
    await _db.projectsDao.moveProject(
      projectId,
      position: moved.position,
      parentProjectId: moved.parentProjectId,
    );
    _log.fine('Moved project $projectId');
    unawaited(
      _sync.refresh().then<void>(
        (_) {},
        onError: (Object error) => _log.fine(
          'Sync after moving project $projectId failed: ${error.runtimeType}',
        ),
      ),
    );
  }

  @override
  Future<int> createProject(NewProject project) async {
    final created = await _write.projects.create(
      NewProject(
        title: _checkedTitle(project.title),
        parentProjectId: project.parentProjectId,
        hexColor: project.hexColor,
      ),
    );
    await _db.projectsDao.upsertAll([created]);
    _settle('Created project ${created.id}');
    return created.id;
  }

  @override
  Future<void> updateProject(int projectId, ProjectChanges changes) =>
      _update(projectId, changes);

  @override
  Future<String?> updateDescription(
    int projectId,
    String html, {
    required String base,
  }) async {
    String? changed;
    try {
      await _update(
        projectId,
        ProjectChanges(description: html),
        rebaseDescription: (current) {
          if (current == base ||
              current == html ||
              (isRichTextEmpty(current) && isRichTextEmpty(base))) {
            return html;
          }
          changed = current;
          throw const DescriptionConflict();
        },
      );
    } on DescriptionConflict {
      final current = changed;
      if (current == null) rethrow;
      _log.info('The description of project $projectId changed on the server');
      await _db.projectsDao.updateProject(projectId, description: current);
      return current;
    }
    return null;
  }

  Future<void> _update(
    int projectId,
    ProjectChanges changes, {
    String Function(String current)? rebaseDescription,
  }) async {
    final identifier = changes.identifier?.trim();
    if (identifier != null && identifier.runes.length > _maxIdentifierLength) {
      throw ArgumentError.value(changes.identifier, 'identifier');
    }
    final requested = ProjectChanges(
      title: switch (changes.title) {
        final title? => _checkedTitle(title),
        null => null,
      },
      description: changes.description,
      identifier: identifier,
      hexColor: changes.hexColor,
      parentProjectId: changes.parentProjectId,
      isFavorite: changes.isFavorite,
      isArchived: changes.isArchived,
    );
    if (requested.isEmpty) return;
    final stored = await _db.projectsDao.loadProject(projectId);
    if (requested.isArchived case final archived?) {
      await _checkArchiving(stored, projectId, archived: archived);
    }
    final sent = stored != null && stored.position < _lowestPosition
        ? _withPosition(
            requested,
            await _liftedPosition(
              stored,
              parentId: requested.parentProjectId ?? stored.parentProjectId,
            ),
          )
        : requested;
    final answered = await _write.projects.update(
      projectId,
      sent,
      rebaseDescription: rebaseDescription,
    );
    await _db.transaction(() async {
      await _db.projectsDao.updateProject(
        projectId,
        title: sent.title == null ? null : answered.title,
        description: sent.description == null ? null : answered.description,
        identifier: sent.identifier == null ? null : answered.identifier,
        hexColor: sent.hexColor == null ? null : answered.hexColor,
        parentProjectId: sent.parentProjectId == null
            ? null
            : answered.parentProjectId,
        isFavorite: sent.isFavorite == null ? null : answered.isFavorite,
        position: answered.position,
      );
      if (sent.isArchived == null) return;
      final cascaded = await _db.projectsDao.setArchived(
        projectId,
        archived: answered.isArchived,
      );
      if (!answered.isArchived && (stored?.isArchived ?? false)) {
        await pullWholeOnNextRun(_db, cascaded);
      }
    });
    _settle('Updated project $projectId: $sent');
  }

  /// A position of 0.1 or more for [project] between its neighbours under
  /// [parentId], in the server's order. Any update that leaves a project
  /// below 0.1 renumbers its siblings, at the top level those of every user;
  /// a project gets there through a create or a duplicate, which keep any
  /// position.
  Future<double> _liftedPosition(
    Project project, {
    required int parentId,
  }) async {
    final siblings = [
      for (final other in await _db.projectsDao.loadAll())
        if (other.id == project.id || other.parentProjectId == parentId) other,
    ];
    final at = siblings.indexWhere((other) => other.id == project.id);
    return math.max(
      calculateItemPosition(
        at > 0 ? siblings[at - 1].position : null,
        at + 1 < siblings.length ? siblings[at + 1].position : null,
      ),
      _lowestPosition,
    );
  }

  static ProjectChanges _withPosition(
    ProjectChanges changes,
    double position,
  ) => ProjectChanges(
    title: changes.title,
    description: changes.description,
    identifier: changes.identifier,
    hexColor: changes.hexColor,
    parentProjectId: changes.parentProjectId,
    isFavorite: changes.isFavorite,
    isArchived: changes.isArchived,
    position: position,
  );

  /// The server's refusals, known here before a request.
  Future<void> _checkArchiving(
    Project? stored,
    int projectId, {
    required bool archived,
  }) async {
    if (archived) {
      final settings = decodeUserSettings(
        (await _db.syncStateDao.readAll())[SyncStateKeys.userSettings],
      );
      if (settings.defaultProjectId == projectId) {
        throw const DomainError(412, code: _defaultProjectNotArchivable);
      }
      return;
    }
    final parentId = stored?.parentProjectId ?? 0;
    if (parentId == 0) return;
    final parent = await _db.projectsDao.loadProject(parentId);
    if (parent?.isArchived ?? false) {
      throw const DomainError(412, code: _parentArchived);
    }
  }

  @override
  Future<void> deleteProject(int projectId) async {
    await _write.projects.delete(projectId);
    await _db.transaction(() async {
      final purged = await _db.projectsDao.purgeSubtree(projectId);
      await LocalListPreferences(_db)
          .forget(projectIds: purged.projectIds, viewIds: purged.viewIds);
    });
    _settle('Deleted project $projectId');
  }

  /// Like a duplicate, the project comes with a run that starts after the
  /// restore, which finds it new and pulls it whole.
  @override
  Future<Project> restoreProject(int projectId) async {
    final trash = _trash ?? (throw const NotFound());
    final project = await trash.restoreProject(projectId);
    _log.fine('Restored project $projectId');
    try {
      await _sync.refreshAfterWrite();
    } on Object catch (error) {
      _log.fine(
        'Sync after restoring project $projectId failed: '
        '${error.runtimeType}',
      );
    }
    if (await _db.projectsDao.loadProject(project.id) == null) {
      await _db.transaction(() async {
        await _db.projectsDao.upsertAll([project]);
        await pullWholeOnNextRun(_db, {project.id});
      });
    }
    return project;
  }

  /// The copy comes with a run that starts after the duplicate: it finds
  /// the copy new and pulls it whole. When that run fails before storing
  /// it, the answer is stored and the next run pulls the tasks.
  @override
  Future<int> duplicateProject(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  }) async {
    final copy = await _write.projects.duplicate(
      projectId,
      parentProjectId: parentProjectId,
      copyShares: copyShares,
    );
    _log.fine('Duplicated project $projectId as ${copy.id}');
    try {
      await _sync.refreshAfterWrite();
    } on Object catch (error) {
      _log.fine(
        'Sync after duplicating project $projectId failed: '
        '${error.runtimeType}',
      );
    }
    if (await _db.projectsDao.loadProject(copy.id) == null) {
      await _db.transaction(() async {
        await _db.projectsDao.upsertAll([copy]);
        await pullWholeOnNextRun(_db, {copy.id});
      });
    }
    return copy.id;
  }

  void _settle(String done) {
    _log.fine(done);
    unawaited(
      _sync.refreshAfterWrite().then<void>(
        (_) {},
        onError: (Object error) => _log.fine(
          'Sync after a project change failed: ${error.runtimeType}',
        ),
      ),
    );
  }

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }

  @override
  void dispose() {}
}
