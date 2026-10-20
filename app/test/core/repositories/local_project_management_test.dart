import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient server;
  late LocalProjectRepository repository;
  final work = Project(
    id: 1,
    title: 'Work',
    description: '<p>Office</p>',
    identifier: 'WRK',
    hexColor: '1973ff',
    position: 65536,
    isFavorite: true,
    views: [
      sampleListView(id: 11, projectId: 1),
      sampleKanbanView(id: 12, projectId: 1),
    ],
    updated: DateTime.utc(2026, 10, 2),
  );
  final reports = sampleProject(
    id: 2,
    title: 'Reports',
    parent: 1,
    position: 10,
    views: [sampleListView(id: 21, projectId: 2)],
  );
  final drafts = sampleProject(id: 3, title: 'Drafts', parent: 2);
  final home = sampleProject(id: 4, title: 'Home', position: 131072);

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    server = FakeWriteClient(clock: () => DateTime.utc(2026, 10, 20, 12));
    repository = LocalProjectRepository(db, sync, server);
    addTearDown(repository.dispose);
    final all = [work, reports, drafts, home];
    await db.projectsDao.upsertAll(all);
    server.serverProjects.addAll({for (final p in all) p.id: p});
  });

  Future<Project?> stored(int id) => db.projectsDao.loadProject(id);

  Future<String?> pendingWholePull() async =>
      (await db.syncStateDao.readAll())[SyncStateKeys.pendingWholePull];

  void offline() =>
      server.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

  group('creating a project', () {
    test('goes to the server, is stored with its views before the id '
        'returns, then a sync follows quietly', () async {
      final id = await repository.createProject(
        const NewProject(
          title: '  Garden ',
          parentProjectId: 4,
          hexColor: 'ff851b',
        ),
      );

      expect(server.requests, ['create project Garden under 4']);
      final created = (await stored(id))!;
      expect(created.title, 'Garden');
      expect(created.parentProjectId, 4);
      expect(created.hexColor, 'ff851b');
      expect(created.position, id * 65536.0);
      expect(created.views.map((v) => v.kind), [
        ProjectViewKind.list,
        ProjectViewKind.gantt,
        ProjectViewKind.table,
        ProjectViewKind.kanban,
      ]);
      expect(sync.refreshAfterWriteCalls, 1);
      expect(sync.refreshCalls, 0);
    });

    test('a blank title is refused before any request', () async {
      await expectLater(
        repository.createProject(const NewProject(title: '   ')),
        throwsArgumentError,
      );

      expect(server.requests, isEmpty);
    });

    test('a refusal or no connection changes nothing', () async {
      server.serverProjects[4] = copyProject(home, isArchived: true);
      await expectLater(
        repository.createProject(
          const NewProject(title: 'Garden', parentProjectId: 4),
        ),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 3008)),
      );
      offline();
      await expectLater(
        repository.createProject(const NewProject(title: 'Garden')),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await db.projectsDao.loadAll(), hasLength(4));
      expect(sync.refreshAfterWriteCalls, 0);
    });
  });

  group('editing a project', () {
    test('sends only what changed and stores the answer for those '
        'fields', () async {
      await repository.updateProject(
        1,
        const ProjectChanges(title: ' Office ', hexColor: '#00ff00'),
      );

      expect(server.requests, [
        'update project 1 ProjectChanges(title, hexColor)',
      ]);
      final edited = (await stored(1))!;
      expect(edited.title, 'Office');
      expect(edited.hexColor, '00ff00');
      expect(edited.identifier, 'WRK');
      expect(edited.description, '<p>Office</p>');
      expect(edited.isFavorite, isTrue);
      expect(edited.position, 65536);
      expect(edited.views.map((v) => v.id), [11, 12]);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a new identifier is stored as answered and renames the stored '
        'tasks of the project', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 31,
          title: 'One',
          identifier: 'WRK-7',
        ).copyWith(index: 7),
        sampleTask(id: 41, title: 'Elsewhere', projectId: 4),
      ]);
      server.serverTasks[31] = (await db.tasksDao.findAll({31}))[31]!;

      await repository.updateProject(
        1,
        const ProjectChanges(identifier: ' ofc '),
      );

      expect((await stored(1))!.identifier, 'OFC');
      expect((await db.tasksDao.findRow(31))!.identifier, 'OFC-7');
      expect((await db.tasksDao.findRow(41))!.identifier, '-41');
      expect(server.serverTasks[31]!.identifier, 'OFC-7');

      await repository.updateProject(1, const ProjectChanges(identifier: ''));

      expect((await stored(1))!.identifier, '');
      expect((await db.tasksDao.findRow(31))!.identifier, '#7');
    });

    test('an identifier longer than 10 characters is refused before any '
        'request, one in use elsewhere by the server', () async {
      await expectLater(
        repository.updateProject(
          1,
          const ProjectChanges(identifier: 'ABCDEFGHIJK'),
        ),
        throwsArgumentError,
      );
      expect(server.requests, isEmpty);
      await expectLater(
        repository.updateProject(1, const ProjectChanges(title: '  ')),
        throwsArgumentError,
      );
      expect(server.requests, isEmpty);

      server.serverProjects[4] = copyProject(home, identifier: 'HOME');
      await expectLater(
        repository.updateProject(1, const ProjectChanges(identifier: 'home')),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 3007)),
      );
      expect((await stored(1))!.identifier, 'WRK');
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test(
      'a favourite and a new parent are stored; the position stays',
      () async {
        await repository.updateProject(
          4,
          const ProjectChanges(isFavorite: true, parentProjectId: 1),
        );

        final edited = (await stored(4))!;
        expect(edited.isFavorite, isTrue);
        expect(edited.parentProjectId, 1);
        expect(edited.position, 131072);
      },
    );

    test('a project stored below 0.1 is sent a position between its '
        'neighbours with the change, so the server renumbers no sibling, and '
        'the answered position is stored', () async {
      final copy = sampleProject(id: 5, title: 'Copy', position: -1);
      await db.projectsDao.upsertAll([copy]);
      server.serverProjects[5] = copy;

      await repository.updateProject(
        5,
        const ProjectChanges(isFavorite: true, position: 7),
      );

      expect(server.requests, [
        'update project 5 ProjectChanges(isFavorite: true, position: 32768.0)',
      ]);
      expect(server.serverProjects[1], same(work));
      expect(server.serverProjects[4], same(home));
      expect((await stored(5))!.position, 32768);
      expect((await stored(5))!.isFavorite, isTrue);

      server.requests.clear();
      await repository.updateProject(5, const ProjectChanges(title: 'Kept'));
      expect(server.requests, ['update project 5 ProjectChanges(title)']);
    });

    test('a project below 0.1 moved under another parent is placed among '
        'its new siblings, at 0.1 at least', () async {
      final copy = sampleProject(id: 5, title: 'Copy', position: 0.05);
      final first = sampleProject(
        id: 6,
        title: 'First',
        parent: 4,
        position: 0.15,
      );
      await db.projectsDao.upsertAll([copy, first]);
      server.serverProjects.addAll({5: copy, 6: first});

      await repository.updateProject(
        5,
        const ProjectChanges(parentProjectId: 4),
      );

      expect(server.requests.single, contains('position: 0.1)'));
      expect(server.serverProjects[6], same(first));
      final moved = (await stored(5))!;
      expect(moved.parentProjectId, 4);
      expect(moved.position, 0.1);
    });

    test('a refusal or no connection changes nothing', () async {
      server.refusedProjects[1] = const Forbidden();
      await expectLater(
        repository.updateProject(1, const ProjectChanges(title: 'Office')),
        throwsA(isA<Forbidden>()),
      );
      server.refusedProjects.clear();
      offline();
      await expectLater(
        repository.updateProject(1, const ProjectChanges(title: 'Office')),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await stored(1), work);
    });
  });

  group('archiving', () {
    test('cascades to the stored subprojects at once, keeping updated for '
        'the sync to see', () async {
      await repository.updateProject(1, const ProjectChanges(isArchived: true));

      for (final id in [1, 2, 3]) {
        expect((await stored(id))!.isArchived, isTrue, reason: '$id');
      }
      expect((await stored(1))!.updated, work.updated);
      expect((await stored(4))!.isArchived, isFalse);
      expect(server.serverProjects[3]!.isArchived, isTrue);
      expect(await pendingWholePull(), isNull);
    });

    test('the default project is refused before any request', () async {
      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(defaultProjectId: 1),
        ),
      });

      await expectLater(
        repository.updateProject(1, const ProjectChanges(isArchived: true)),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 3013)),
      );

      expect(server.requests, isEmpty);
      expect((await stored(1))!.isArchived, isFalse);
    });

    test('unarchiving cascades too, and the next sync pulls the '
        "projects' tasks whole", () async {
      await repository.updateProject(1, const ProjectChanges(isArchived: true));
      await repository.updateProject(
        1,
        const ProjectChanges(isArchived: false),
      );

      for (final id in [1, 2, 3]) {
        expect((await stored(id))!.isArchived, isFalse, reason: '$id');
      }
      expect(await pendingWholePull(), '1,2,3');
    });

    test('unarchiving under an archived parent is refused before any '
        'request', () async {
      await repository.updateProject(1, const ProjectChanges(isArchived: true));
      server.requests.clear();

      await expectLater(
        repository.updateProject(2, const ProjectChanges(isArchived: false)),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 3016)),
      );

      expect(server.requests, isEmpty);
      expect((await stored(2))!.isArchived, isTrue);
    });
  });

  group('deleting a project', () {
    test('purges the stored subtree with its tasks and list preferences, '
        'then a sync follows quietly', () async {
      final preferences = LocalListPreferences(db);
      await db.tasksDao.upsertAll([
        sampleTask(id: 31, title: 'In work'),
        sampleTask(id: 32, title: 'In drafts', projectId: 3),
        sampleTask(id: 41, title: 'At home', projectId: 4),
      ]);
      await db.outboxDao.queueUpdate(
        32,
        const TaskChanges(title: 'Unsent'),
        now: DateTime.utc(2026, 10, 20),
      );
      const sorted = ViewPreferences(showDone: true);
      await preferences.saveView('view:11', sorted);
      await preferences.saveView('view:21', sorted);
      await preferences.saveView('project:3', sorted);
      await preferences.saveView('project:4', sorted);
      await preferences.rememberView(1, 12);
      await preferences.rememberView(4, 41);
      await preferences.saveProjectTree(
        const ProjectTreePreferences(showArchived: true, collapsed: {1, 2, 4}),
      );

      await repository.deleteProject(1);

      expect(server.requests, ['delete project 1']);
      expect((await db.projectsDao.loadAll()).map((p) => p.id), [4]);
      expect(await db.tasksDao.findRow(31), isNull);
      expect(await db.tasksDao.findRow(32), isNull);
      expect(await db.tasksDao.findRow(41), isNotNull);
      expect(await db.outboxDao.all(), isEmpty);
      expect(await preferences.watchView('view:11').first, isNot(sorted));
      expect(await preferences.watchView('view:21').first, isNot(sorted));
      expect(await preferences.watchView('project:3').first, isNot(sorted));
      expect(await preferences.watchView('project:4').first, sorted);
      expect(await preferences.lastViewOf(1), isNull);
      expect(await preferences.lastViewOf(4), 41);
      expect(
        await preferences.watchProjectTree().first,
        const ProjectTreePreferences(showArchived: true, collapsed: {4}),
      );
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a refusal or no connection changes nothing', () async {
      server.refusedProjects[1] = const DomainError(412, code: 3012);
      await expectLater(
        repository.deleteProject(1),
        throwsA(isA<DomainError>()),
      );
      offline();
      await expectLater(
        repository.deleteProject(2),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await db.projectsDao.loadAll(), hasLength(4));
      expect(sync.refreshAfterWriteCalls, 0);
    });
  });

  group('duplicating a project', () {
    test("returns the copy's id once a sync started after the duplicate "
        'has stored it', () async {
      final gate = Completer<void>();
      sync
        ..gate = gate
        ..onRefreshAfterWrite = () async {
          await db.projectsDao.upsertAll(server.serverProjects.values);
        };

      int? copyId;
      final duplicated = repository
          .duplicateProject(1, parentProjectId: 4, copyShares: true)
          .then((id) => copyId = id);
      await pumpEventQueue();

      expect(server.requests, ['duplicate project 1 under 4 shares true']);
      expect(copyId, isNull);

      gate.complete();
      await duplicated;

      final copy = (await stored(copyId!))!;
      expect(copy.title, 'Work - duplicate');
      expect(copy.parentProjectId, 4);
      expect(copy.identifier, '');
      expect(copy.isFavorite, isFalse);
      expect(copy.views, hasLength(2));
      expect(sync.refreshAfterWriteCalls, 1);
      expect(await pendingWholePull(), isNull);
    });

    test('when that sync fails, the answer is stored and the next sync '
        'pulls its tasks', () async {
      sync.error = const NetworkFailure(NetworkProblem.unreachable);

      final copyId = await repository.duplicateProject(
        1,
        parentProjectId: 0,
        copyShares: false,
      );

      final copy = (await stored(copyId))!;
      expect(copy.title, 'Work - duplicate');
      expect(copy.views.map((v) => v.kind), [
        ProjectViewKind.list,
        ProjectViewKind.kanban,
      ]);
      expect(await pendingWholePull(), '$copyId');
    });

    test(
      'a refusal or no connection stores nothing and runs no sync',
      () async {
        server.serverProjects[4] = copyProject(home, isArchived: true);
        await expectLater(
          repository.duplicateProject(1, parentProjectId: 4, copyShares: true),
          throwsA(isA<DomainError>().having((e) => e.code, 'code', 3008)),
        );
        offline();
        await expectLater(
          repository.duplicateProject(1, parentProjectId: 0, copyShares: true),
          throwsA(isA<NetworkFailure>()),
        );
        await expectLater(
          repository.duplicateProject(-1, parentProjectId: 0, copyShares: true),
          throwsArgumentError,
        );

        expect(await db.projectsDao.loadAll(), hasLength(4));
        expect(sync.refreshAfterWriteCalls, 0);
      },
    );
  });
}
