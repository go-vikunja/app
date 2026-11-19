import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import '../helpers/budgets.dart';
import '../helpers/sample_data.dart';
import '../helpers/test_database.dart';

// What the lists of an account with 5,000 tasks cost on this machine. The
// numbers go into the step's report; the budgets hold only with
// VIKUNJA_BENCHMARK=1.
void main() {
  late AppDatabase db;
  const urgent = Label(id: 1, title: 'urgent');
  const later = Label(id: 2, title: 'later');
  const alice = User(id: 7, username: 'alice');
  final monday = DateTime.utc(2026, 11, 16, 9);

  setUp(() async {
    db = testDatabase();
    await db.projectsDao.upsertAll([
      for (var id = 1; id <= 20; id++) sampleProject(id: id, title: 'P$id'),
    ]);
    await db.labelsDao.upsertAll([urgent, later]);
    await db.tasksDao.upsertAll([
      for (var id = 1; id <= 5000; id++)
        sampleTask(
          id: id,
          title: 'Task $id',
          projectId: id % 20 + 1,
          done: id % 4 == 0,
          due: id % 3 == 0 ? monday.add(Duration(hours: id % 400)) : null,
          labels: [if (id % 5 == 0) urgent, if (id % 7 == 0) later],
          assignees: id % 6 == 0 ? const [alice] : const [],
        ),
    ], syncRunId: 'run');
  });
  tearDown(() => db.close());

  Future<int> fastestOf(Future<Object?> Function() run) async {
    await run();
    var fastest = 1 << 30;
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      await run();
      final ms = watch.elapsedMilliseconds;
      if (ms < fastest) fastest = ms;
    }
    return fastest;
  }

  test('the lists of 5,000 tasks', () async {
    expectWithinBudget(
      await fastestOf(db.tasksDao.loadActiveOpenTasks),
      200,
      'Open tasks of active projects (Overview, Upcoming)',
    );
    expectWithinBudget(
      await fastestOf(db.tasksDao.loadSearchableTasks),
      300,
      'Every searchable task (search)',
    );
    expectWithinBudget(
      await fastestOf(db.tasksDao.loadFavoriteTasks),
      100,
      'Favourites',
    );
    expectWithinBudget(await fastestOf(db.projectsDao.loadAll), 50, 'Projects');
  });

  test('one write reloads a watched list once, in its time', () async {
    final reloads = <int>[];
    var watch = Stopwatch()..start();
    final subscription = db.tasksDao.watchActiveOpenTasks().listen((_) {
      reloads.add(watch.elapsedMilliseconds);
    });
    addTearDown(subscription.cancel);
    Future<void> nextReload() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (reloads.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(reloads, isNotEmpty, reason: 'a reload within 5 s');
    }

    await nextReload();
    reloads.clear();
    watch = Stopwatch()..start();
    await db.tasksDao.upsertAll([
      sampleTask(id: 3, title: 'Renamed', projectId: 4),
    ], syncRunId: 'run');
    await nextReload();
    // A second reload would follow the first one's load.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(reloads, hasLength(1));
    expectWithinBudget(reloads.single, 300, 'A write until the list reloaded');
  });
}
