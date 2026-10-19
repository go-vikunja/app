import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';

import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late LocalProjectRepository repository;
  final work = sampleProject(id: 1, title: 'Work');
  final home = sampleProject(id: 2, title: 'Home', position: 1);

  setUp(() {
    db = testDatabase();
    sync = RecordingSyncEngine();
    repository = LocalProjectRepository(db, sync);
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
