import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';

import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient server;
  late LocalProjectRepository repository;
  final work = sampleProject(id: 1, title: 'Work');
  final home = sampleProject(id: 2, title: 'Home', position: 1);

  setUp(() {
    db = testDatabase();
    sync = RecordingSyncEngine();
    server = FakeWriteClient(clock: () => DateTime.utc(2026, 10, 19, 12));
    repository = LocalProjectRepository(db, sync, server);
    addTearDown(repository.dispose);
  });

  test('the stream carries the database and follows its changes', () async {
    await db.projectsDao.upsertAll([work]);
    final seen = <List<Project>>[];
    repository.watchAll().listen(seen.add);
    await pumpEventQueue();
    expect(seen, [
      [work],
    ]);

    await db.projectsDao.upsertAll([home]);
    await pumpEventQueue();

    expect(seen.last, [work, home]);
    expect(repository.find(2), home);
    expect(repository.find(3), isNull);
  });

  test('find knows nothing before the first emission', () async {
    await db.projectsDao.upsertAll([work]);

    expect(repository.find(1), isNull);
  });

  test('a refresh is a sync run, and its failure passes through', () async {
    await db.projectsDao.upsertAll([work]);
    final seen = <List<Project>>[];
    final errors = <Object>[];
    repository.watchAll().listen(seen.add, onError: errors.add);
    await pumpEventQueue();

    await repository.refresh();
    expect(sync.refreshCalls, 1);

    sync.error = const NetworkFailure(NetworkProblem.unreachable);
    await expectLater(repository.refresh(), throwsA(isA<NetworkFailure>()));

    expect(sync.refreshCalls, 2);
    expect(errors, isEmpty);
    expect(seen, hasLength(1));
    expect(repository.find(1), work);
  });

  group('moving a project', () {
    final view = sampleListView(id: 70, projectId: 3);
    final garden = Project(
      id: 3,
      title: 'Garden',
      description: '<p>Beds</p>',
      identifier: 'GRD',
      hexColor: '4caf50',
      parentProjectId: 1,
      isFavorite: true,
      position: 300,
      views: [view],
      updated: DateTime.utc(2026, 10, 2),
    );

    setUp(() async {
      await db.projectsDao.upsertAll([work, home, garden]);
      server.serverProjects.addAll({1: work, 2: home, 3: garden});
    });

    Future<Project?> stored(int id) async {
      for (final project in await db.projectsDao.loadAll()) {
        if (project.id == id) return project;
      }
      return null;
    }

    test('goes to the server, then into the stored project, then a sync '
        'follows quietly', () async {
      await repository.moveProject(3, position: 150, parentProjectId: 2);

      expect(server.requests, ['move project 3 to 150.0 under 2']);
      final moved = (await stored(3))!;
      expect(moved.position, 150);
      expect(moved.parentProjectId, 2);
      expect(moved.title, 'Garden');
      expect(moved.description, '<p>Beds</p>');
      expect(moved.identifier, 'GRD');
      expect(moved.hexColor, '4caf50');
      expect(moved.isFavorite, isTrue);
      expect(moved.views, [view]);
      expect(await stored(2), home);
      expect(sync.refreshCalls, 1);
    });

    test('to the top level', () async {
      await repository.moveProject(3, position: 0.5, parentProjectId: 0);

      expect((await stored(3))!.parentProjectId, 0);
      expect((await stored(3))!.position, 0.5);
    });

    test('a failed sync afterwards does not fail the move', () async {
      sync.error = const NetworkFailure(NetworkProblem.unreachable);

      await repository.moveProject(3, position: 150, parentProjectId: 0);
      await pumpEventQueue();

      expect((await stored(3))!.position, 150);
    });

    test('a refusal changes nothing and passes through', () async {
      server.refusedProjects[3] = const Forbidden(code: 1);

      await expectLater(
        repository.moveProject(3, position: 150, parentProjectId: 2),
        throwsA(isA<Forbidden>()),
      );

      expect(await stored(3), garden);
      expect(sync.refreshCalls, 0);
    });

    test('offline changes nothing', () async {
      server.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.moveProject(3, position: 150, parentProjectId: 0),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await stored(3), garden);
    });

    test('a position below 0.1 is refused before any request: the server '
        'would renumber every sibling', () async {
      for (final position in <double>[
        0.09,
        0,
        -1,
        double.nan,
        double.infinity,
      ]) {
        await expectLater(
          repository.moveProject(3, position: position, parentProjectId: 0),
          throwsArgumentError,
        );
      }

      expect(server.requests, isEmpty);
      expect(await stored(3), garden);
    });
  });

  group('saved filters', () {
    const urgent = SavedFilterRef(projectId: -3, title: 'urgent');
    const mine = SavedFilterRef(
      projectId: -14,
      title: 'My Open Tasks',
      isFavorite: true,
    );
    const archive = SavedFilterRef(projectId: -20, title: 'Archive');

    test('none before a sync named any', () async {
      expect(await repository.watchSavedFilters().first, isEmpty);
    });

    test('come by title, ignoring case, and follow the stored list on '
        'change only', () async {
      final seen = <List<SavedFilterRef>>[];
      final subscription = repository.watchSavedFilters().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await storeSavedFilters(db, [mine, urgent, archive]);
      await pumpEventQueue();
      await db.projectsDao.upsertAll([work]);
      await pumpEventQueue();
      await storeSavedFilters(db, [
        mine,
        const SavedFilterRef(projectId: -3, title: 'urgent', isFavorite: true),
      ]);
      await pumpEventQueue();
      await storeSavedFilters(db, const []);
      await pumpEventQueue();

      expect(seen, const [
        <SavedFilterRef>[],
        [archive, mine, urgent],
        [
          mine,
          SavedFilterRef(projectId: -3, title: 'urgent', isFavorite: true),
        ],
        <SavedFilterRef>[],
      ]);
    });

    test('an umlaut sorts with its letter, as on the web', () async {
      await storeSavedFilters(db, const [
        SavedFilterRef(projectId: -2, title: 'Zuhause'),
        SavedFilterRef(projectId: -3, title: 'Übersicht'),
        SavedFilterRef(projectId: -4, title: 'Bugs'),
        SavedFilterRef(projectId: -5, title: 'Ärger'),
      ]);

      expect(
        [
          for (final filter in await repository.watchSavedFilters().first)
            filter.title,
        ],
        ['Ärger', 'Bugs', 'Übersicht', 'Zuhause'],
      );
    });

    test('the same title is ordered by id', () async {
      await storeSavedFilters(db, const [
        SavedFilterRef(projectId: -9, title: 'Same'),
        SavedFilterRef(projectId: -4, title: 'same'),
      ]);

      expect(
        [
          for (final filter in await repository.watchSavedFilters().first)
            filter.projectId,
        ],
        [-9, -4],
      );
    });
  });
}
