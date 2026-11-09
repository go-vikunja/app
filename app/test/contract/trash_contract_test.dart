@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// A drain whose transient failures are retried: the SQLite test server
/// answers a lost write race with a 500, which the sender retries on its
/// own timer.
Future<void> _drainFully(OutboxSender sender, AppDatabase db) async {
  await sender.drain();
  await _until(() async => await db.outboxDao.count() == 0);
}

// Undo of a task delete (the outbox, then the server's trash) and a project
// restore, through the repositories against a 2.8 server on /api/v2.
void main() {
  group('the trash against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late Seeder seeder;
    late VikunjaReadClient reads;
    late AppDatabase db;
    late DefaultSyncEngine engine;
    late OutboxSender sender;
    late LocalTaskRepository tasks;
    late LocalProjectRepository projects;
    late TrashPort trash;
    late int projectId;

    bool hasTrash() => connection.capabilities.has(Capability.trash);

    bool skippedBelow28() {
      if (hasTrash()) return false;
      markTestSkipped('The trash needs Vikunja 2.8 on /api/v2');
      return true;
    }

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      if (!hasTrash()) return;
      user = await registerAndLogin(dio, connection);
      seeder = Seeder(dio, connection, user);
      projectId = await seeder.create('/projects', {'title': 'Trash'});
      final only = onlyApiVersion(connection, ApiVersion.v2);
      final authenticated = createAuthenticatedDio(
        base: dio,
        connection: only,
        tokens: StaticJwt(user.jwt),
      );
      reads = createReadClient(dio: authenticated, connection: only);
      final writes = createWriteClient(dio: authenticated, connection: only);
      trash = createTrashPort(dio: authenticated, connection: only);
      db = testDatabase();
      engine = DefaultSyncEngine(
        db: db,
        client: reads,
        perPage: only.info.maxItemsPerPage,
        currentUser: AccountApi(authenticated, only).currentUserWithSettings,
      );
      addTearDown(engine.dispose);
      sender = OutboxSender(
        db: db,
        writeClient: writes,
        readClient: reads,
        sync: engine,
      );
      addTearDown(sender.dispose);
      tasks = LocalTaskRepository(db, engine, sender, writes, trash: trash);
      addTearDown(tasks.dispose);
      projects = LocalProjectRepository(db, engine, writes, trash: trash);
      addTearDown(projects.dispose);
      await engine.ensureInitialSync();
    });

    tearDownAll(() => dio.close(force: true));

    Future<int> seedTask(String title) async {
      final id = await seeder.create('/projects/$projectId/tasks', {
        'title': title,
      });
      // A restore's quiet run may still be going; refresh() would join it.
      await engine.refreshAfterWrite();
      expect((await db.tasksDao.find(id))!.title, title);
      return id;
    }

    Matcher inTrash() => throwsA(
      isA<NotFound>().having((failure) => failure.code, 'code', 4040),
    );

    test('Undo while the delete is queued never reaches the server', () async {
      if (skippedBelow28()) return;
      final id = await seedTask('Kept here');
      sender.pause();

      expect(await tasks.deleteTask(id), TaskDeletion.queued);
      expect(await db.tasksDao.find(id), isNull);
      final restored = await tasks.restoreTask(id);
      await sender.resume();
      await _drainFully(sender, db);

      expect(restored.title, 'Kept here');
      expect((await db.tasksDao.find(id))!.title, 'Kept here');
      expect((await reads.tasks.read(id)).title, 'Kept here');
      expect(
        (await trash.tasks()).map((item) => item.task.id),
        isNot(contains(id)),
      );
    });

    test('Undo after the delete was sent restores from the trash, and the '
        'row is back', () async {
      if (skippedBelow28()) return;
      final id = await seedTask('Back from the trash');

      await tasks.deleteTask(id);
      await _drainFully(sender, db);
      expect(await db.tasksDao.findRow(id), isNull);
      await expectLater(reads.tasks.read(id), inTrash());

      final restored = await tasks.restoreTask(id);

      expect(restored.id, id);
      expect(restored.title, 'Back from the trash');
      expect((await db.tasksDao.find(id))!.title, 'Back from the trash');
      expect((await reads.tasks.read(id)).title, 'Back from the trash');
      await engine.refreshAfterWrite();
      expect((await db.tasksDao.find(id))!.title, 'Back from the trash');

      // Undo twice: the server answers 4042, which reads the live task.
      expect((await tasks.restoreTask(id)).id, id);
    });

    test(
      'an edit queued before a delete is on the server after the restore',
      () async {
        if (skippedBelow28()) return;
        final id = await seedTask('Before the edit');
        sender.pause();

        await tasks.updateTask(
          id,
          const TaskChanges(title: 'Edited, then deleted', isFavorite: true),
        );
        await tasks.deleteTask(id);
        await sender.resume();
        await _drainFully(sender, db);
        await expectLater(reads.tasks.read(id), inTrash());

        final restored = await tasks.restoreTask(id);

        expect(restored.title, 'Edited, then deleted');
        final onServer = await reads.tasks.read(id);
        expect(onServer.title, 'Edited, then deleted');
        expect(onServer.isFavorite, isTrue);
        expect((await db.tasksDao.find(id))!.title, 'Edited, then deleted');
      },
    );

    test('a deleted project restored comes back with its subproject and '
        'their tasks after the run', () async {
      if (skippedBelow28()) return;
      final gardenId = await seeder.create('/projects', {'title': 'Garden'});
      final bedsId = await seeder.create('/projects', {
        'title': 'Beds',
        'parent_project_id': gardenId,
      });
      final seedsId = await seeder.create('/projects/$gardenId/tasks', {
        'title': 'Seeds',
      });
      final digId = await seeder.create('/projects/$bedsId/tasks', {
        'title': 'Dig',
      });
      await engine.refreshAfterWrite();
      expect(await db.tasksDao.find(digId), isNotNull);

      await projects.deleteProject(gardenId);
      expect(await db.projectsDao.loadProject(gardenId), isNull);
      expect(await db.projectsDao.loadProject(bedsId), isNull);
      expect(await db.tasksDao.findRow(seedsId), isNull);

      final restored = await projects.restoreProject(gardenId);

      expect(restored.id, gardenId);
      expect(restored.title, 'Garden');
      expect((await db.projectsDao.loadProject(gardenId))!.title, 'Garden');
      expect(
        (await db.projectsDao.loadProject(bedsId))!.parentProjectId,
        gardenId,
      );
      expect((await db.tasksDao.find(seedsId))!.projectId, gardenId);
      expect((await db.tasksDao.find(digId))!.projectId, bedsId);
    });
  });
}
