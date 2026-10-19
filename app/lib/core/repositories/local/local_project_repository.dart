import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Below it the server renumbers every sibling of the project, at the top
/// level those of every user on the instance.
const _lowestPosition = 0.1;

/// Projects from the account's database; a refresh is a full sync run. A
/// move goes straight to the server and into the stored project once
/// answered; the sync that follows quietly brings what else the server
/// changed.
final class LocalProjectRepository implements ProjectRepository {
  new(this._db, this._sync, this._write);

  final AppDatabase _db;
  final SyncEngine _sync;
  final VikunjaWriteClient _write;
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
  void dispose() {}
}
