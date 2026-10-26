@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_sharing_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';

import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// The writes are paced, so the SQLite server keeps up with the files
/// running in parallel.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

// The acceptance of step 28: a share changed on the web reaches the other
// user's app with its next sync, and the gating follows the stored
// permission. Two users: the owner shares, the other syncs.
void main() {
  group(
    'project permissions in the sync against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser owner;
      late TestUser guest;

      setUpAll(() async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        owner = await registerAndLogin(dio, connection);
        guest = await registerAndLogin(dio, connection);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        test("a share is read, raised and removed through the guest's "
            'syncs over ${apiVersion.pathSegment}', () async {
          final only = onlyApiVersion(connection, apiVersion);
          Dio authenticatedAs(TestUser user) => createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );
          final ownerDio = authenticatedAs(owner);
          final sharing = OnlineProjectSharingRepository(
            port: createProjectSharingPort(dio: ownerDio, connection: only),
            sync: RecordingSyncEngine(),
            currentUsername: () => owner.username,
          );
          final seeder = Seeder(dio, connection, owner);
          final name = apiVersion.pathSegment;
          final parentId = await seeder.create('/projects', {
            'title': 'Shared over $name',
          });
          await _pace();
          final childId = await seeder.create('/projects', {
            'title': 'Child over $name',
            'parent_project_id': parentId,
          });
          await _pace();
          final taskId = await seeder.create('/projects/$parentId/tasks', {
            'title': 'Look, do not touch',
          });
          await _pace();

          final guestDio = authenticatedAs(guest);
          final db = testDatabase();
          addTearDown(db.close);
          final engine = DefaultSyncEngine(
            db: db,
            client: createReadClient(dio: guestDio, connection: only),
            perPage: only.info.maxItemsPerPage,
            currentUser: AccountApi(guestDio, only).currentUserWithSettings,
          );
          addTearDown(engine.dispose);
          await engine.ensureInitialSync();
          final ownInbox = (await db.projectsDao.loadAll()).single;
          expect(ownInbox.maxPermission, Permission.admin);
          expect(ProjectAccess.of(ownInbox).canManageShares, isTrue);

          await sharing.shareWithUser(
            parentId,
            guest.username,
            Permission.read,
          );
          await _pace();
          await engine.refresh();

          Future<Project?> stored(int id) => db.projectsDao.loadProject(id);
          final shared = (await stored(parentId))!;
          expect(shared.maxPermission, Permission.read);
          final access = ProjectAccess.of(shared);
          expect(access.isReadOnly, isTrue);
          expect(access.canWrite, isFalse);
          expect(access.canAddTasks, isFalse);
          expect(access.canManageShares, isFalse);
          expect((await stored(childId))!.maxPermission, Permission.read);
          expect((await db.tasksDao.find(taskId))?.title, 'Look, do not touch');

          await sharing.setUserPermission(
            parentId,
            guest.username,
            Permission.write,
          );
          await _pace();
          await engine.refresh();

          final raised = (await stored(parentId))!;
          expect(raised.maxPermission, Permission.write);
          expect(ProjectAccess.of(raised).canAddTasks, isTrue);
          expect(ProjectAccess.of(raised).canDelete, isFalse);
          expect(
            (await stored(childId))!.maxPermission,
            Permission.write,
            reason: "the child's own updated did not move",
          );

          await sharing.removeUserShare(parentId, guest.username);
          await _pace();
          await engine.refresh();

          expect(await stored(parentId), isNull);
          expect(await stored(childId), isNull);
          expect(await db.tasksDao.find(taskId), isNull);
          expect((await db.projectsDao.loadAll()).map((p) => p.id), [
            ownInbox.id,
          ]);
        });
      }
    },
  );
}
