import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

final _log = Logger('SyncEngine');

/// A project's task request that answers "not found" or "forbidden" with
/// any Vikunja code, such as 3001, 3018 from the trash or 7003 for lost
/// access, means the project was deleted, trashed or unshared after the
/// run read the project list; a missing route has no code and is not that
/// (decision log: Sync).
bool meansProjectGone(VikunjaFailure failure) => switch (failure) {
  NotFound(routeAbsent: false) => true,
  Forbidden(code: int()) => true,
  _ => false,
};

/// [holdLease] runs inside the write: a run that lost the account's lease
/// purges nothing.
Future<void> purgeGoneProject(
  AppDatabase db,
  int projectId, {
  required String runId,
  required Future<void> Function() holdLease,
}) async {
  await db.transaction(() async {
    await holdLease();
    await db.projectsDao.purge([projectId]);
    await db.tasksDao.purgeInProjects([projectId]);
  });
  _log.info('Sync run $runId: project $projectId is gone, purged');
}
