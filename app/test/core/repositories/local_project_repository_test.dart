import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';

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
}
