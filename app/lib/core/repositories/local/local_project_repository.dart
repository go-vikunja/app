import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

/// Projects from the account's database; a refresh is a full sync run.
final class LocalProjectRepository implements ProjectRepository {
  new(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
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
  void dispose() {}
}
