import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/guest_read_client.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  const sharedId = 5;
  late AppDatabase db;
  late FakeSyncClient server;
  late DateTime now;

  DefaultSyncEngine guestEngine() {
    final engine = DefaultSyncEngine(
      db: db,
      client: GuestReadClient(server, sharedProjectId: sharedId),
      perPage: 50,
      now: () => now,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  int singleReads() =>
      server.requests.where((request) => request == 'project $sharedId').length;

  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    now = DateTime.utc(2026, 10, 26, 12);
    server = FakeSyncClient()
      ..allProjects = [sampleProject(id: sharedId, title: 'Shared')]
      ..allTasks = [sampleTask(id: 1, title: 'Look', projectId: sharedId)]
      ..singleReadPermissions[sharedId] = Permission.read;
  });

  test('a full run stores the permission from one single read', () async {
    await guestEngine().ensureInitialSync();

    final stored = await db.projectsDao.loadProject(sharedId);
    expect(stored?.maxPermission, Permission.read);
    expect(ProjectAccess.of(stored!).canWrite, isFalse);
    expect(singleReads(), 1);
    expect((await db.tasksDao.find(1))?.title, 'Look');
  });

  test(
    'an incremental run follows a changed permission with one more read',
    () async {
      final engine = guestEngine();
      await engine.ensureInitialSync();
      server.singleReadPermissions[sharedId] = Permission.write;
      now = now.add(const Duration(minutes: 5));

      await engine.refresh();

      final stored = await db.projectsDao.loadProject(sharedId);
      expect(stored?.maxPermission, Permission.write);
      expect(ProjectAccess.of(stored!).canAddTasks, isTrue);
      expect(ProjectAccess.of(stored).isAdmin, isFalse);
      expect(singleReads(), 2);
    },
  );

  test('a list that carries the permission is not read again', () async {
    server.allProjects = [
      sampleProject(
        id: sharedId,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.write),
    ];
    final client = GuestReadClient(server, sharedProjectId: sharedId);

    final page = await client.projects.list(includeArchived: true);
    final all = await client.projects.listAll();

    expect(page.items.single.maxPermission, Permission.write);
    expect(all.single.maxPermission, Permission.write);
    expect(singleReads(), 0);
  });

  test('every list fills the shared project only', () async {
    server.allProjects = [
      sampleProject(id: sharedId, title: 'Shared'),
      sampleProject(id: 6, title: 'Other'),
    ];
    final client = GuestReadClient(server, sharedProjectId: sharedId);

    final all = await client.projects.listAll();

    expect(
      {for (final p in all) p.id: p.maxPermission},
      {sharedId: Permission.read, 6: null},
    );
  });

  test("every list hands on the shared project's title", () async {
    server.allProjects = [
      sampleProject(id: sharedId, title: 'Garden 2026'),
      sampleProject(id: 6, title: 'Other'),
    ];
    final titles = <String>[];
    final client = GuestReadClient(
      server,
      sharedProjectId: sharedId,
      onSharedProjectTitle: (title) async => titles.add(title),
    );

    await client.projects.listAll();
    await client.projects.list();

    expect(titles, ['Garden 2026', 'Garden 2026']);
  });

  test('a failed single read fails the list instead of storing null', () async {
    server.beforeRequest = (request) async {
      if (request == 'project $sharedId') {
        throw const NetworkFailure(NetworkProblem.unreachable);
      }
    };
    final client = GuestReadClient(server, sharedProjectId: sharedId);

    await expectLater(client.projects.list(), throwsA(isA<NetworkFailure>()));
  });
}
