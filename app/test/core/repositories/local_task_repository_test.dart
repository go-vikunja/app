import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';

import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late LocalTaskRepository repository;
  final monday = DateTime.utc(2026, 10, 12, 9);

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    repository = LocalTaskRepository(db, sync);
    addTearDown(repository.dispose);
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Undated', projectId: 7),
      sampleTask(id: 2, title: 'Monday', projectId: 7, due: monday),
      sampleTask(id: 3, title: 'Done', projectId: 7, done: true),
      sampleTask(id: 4, title: 'Elsewhere', projectId: 8),
    ], syncRunId: 'run');
  });

  test('open tasks come from the database, nearest due date first', () async {
    final seen = <List<Task>>[];
    repository.watchOpenTasks().listen(seen.add);
    await pumpEventQueue();
    expect(seen.single.map((t) => t.id), [2, 4, 1]);

    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Undated', projectId: 7, done: true),
    ], syncRunId: 'run');
    await pumpEventQueue();

    expect(seen.last.map((t) => t.id), [2, 4]);
  });

  test('project tasks are one unpaged list per show-done setting', () async {
    final open = <PagedList<Task>>[];
    final all = <PagedList<Task>>[];
    repository.watchProjectTasks(7, showDone: false).listen(open.add);
    repository.watchProjectTasks(7, showDone: true).listen(all.add);
    await pumpEventQueue();

    expect(open.single.items.map((t) => t.id), [2, 1]);
    expect(all.single.items.map((t) => t.id), [3, 2, 1]);
    expect(open.single.hasMore, isFalse);
    expect(all.single.hasMore, isFalse);

    await repository.loadMoreProjectTasks(7, showDone: false);
    await pumpEventQueue();
    expect(open, hasLength(1));
    expect(sync.refreshCalls, 0);
  });

  test('every refresh is a sync run whose failure passes through', () async {
    final errors = <Object>[];
    repository.watchOpenTasks().listen((_) {}, onError: errors.add);
    await pumpEventQueue();

    await repository.refreshOpenTasks();
    await repository.refreshProjectTasks(7, showDone: true);
    expect(sync.refreshCalls, 2);

    sync.error = const ServerFailure(502);
    await expectLater(
      repository.refreshOpenTasks(),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      repository.refreshProjectTasks(7, showDone: false),
      throwsA(isA<ServerFailure>()),
    );

    expect(sync.refreshCalls, 4);
    expect(errors, isEmpty);
  });
}
