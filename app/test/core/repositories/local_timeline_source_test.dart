import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

/// Table and Gantt views on the list path: a timeline's range as a request
/// filter ANDed with the view's, and downloads only for a view filter the
/// device cannot evaluate.
void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  late StreamController<void> clockTicks;
  final now = DateTime.utc(2026, 10, 26, 12);
  var clock = now;
  const range = GanttRange(
    from: CalendarDate(2026, 11, 1),
    to: CalendarDate(2026, 11, 30),
  );

  ProjectView view(
    int id,
    ProjectViewKind kind, {
    String filter = '',
    bool includeNulls = false,
  }) => ProjectView(
    id: id,
    projectId: 7,
    title: kind.wireName,
    kind: kind,
    position: id.toDouble(),
    filter: filter.isEmpty && !includeNulls
        ? null
        : ViewFilter(filter: filter, includeNulls: includeNulls),
  );

  final views = [
    view(71, ProjectViewKind.gantt),
    view(72, ProjectViewKind.table),
    view(73, ProjectViewKind.gantt, filter: 'done = false'),
    view(74, ProjectViewKind.gantt, filter: 'priority = abc'),
    view(75, ProjectViewKind.table, filter: 'priority = abc'),
    view(76, ProjectViewKind.gantt, filter: 'due_date < now'),
    view(
      77,
      ProjectViewKind.gantt,
      filter: 'priority = abc',
      includeNulls: true,
    ),
  ];
  final tasks = [
    sampleTask(
      id: 1,
      title: 'In range',
      projectId: 7,
      start: DateTime.utc(2026, 11, 3, 9),
      end: DateTime.utc(2026, 11, 5, 9),
      subtaskIds: [9],
    ),
    sampleTask(
      id: 2,
      title: 'Done in range',
      projectId: 7,
      done: true,
      due: DateTime.utc(2026, 11, 10, 9),
    ),
    sampleTask(
      id: 3,
      title: 'Later',
      projectId: 7,
      start: DateTime.utc(2027, 1, 3, 9),
      end: DateTime.utc(2027, 1, 5, 9),
    ),
    sampleTask(id: 4, title: 'Dateless', projectId: 7),
    sampleTask(id: 5, title: 'Done dateless', projectId: 7, done: true),
    sampleTask(
      id: 6,
      title: 'Overdue',
      projectId: 7,
      due: DateTime.utc(2026, 10, 26, 13),
    ),
    // A subtask in another project, outside the range.
    sampleTask(
      id: 9,
      title: 'Elsewhere',
      projectId: 8,
      start: DateTime.utc(2027, 3, 1, 9),
      parentIds: [1],
    ),
  ];

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    clock = now;
    clockTicks = StreamController<void>.broadcast();
    addTearDown(clockTicks.close);
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      now: () => clock,
      clockTicks: clockTicks.stream,
    );
    addTearDown(repository.dispose);
    final projects = [
      sampleProject(id: 7, title: 'Work', views: views),
      sampleProject(id: 8, title: 'Other'),
    ];
    await db.projectsDao.upsertAll(projects);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    await db.syncStateDao.write({
      SyncStateKeys.userSettings: encodeUserSettings(
        const UserSettings(timezone: 'UTC'),
      ),
    });
    read
      ..allProjects = projects
      ..allTasks = tasks;
  });

  ViewFilter timeline({bool withoutDates = false}) =>
      ViewFilter(filter: ganttFilterText(range), includeNulls: withoutDates);

  Future<ProjectListSource> source(int viewId, {bool withoutDates = false}) =>
      repository
          .watchProjectList(
            7,
            viewId: viewId,
            includeDone: false,
            request: timeline(withoutDates: withoutDates),
          )
          .first;

  group('a timeline', () {
    test('matches the range, done tasks included and loaded, with every '
        'subtask at hand in any project', () async {
      final list = await source(71);

      expect(list.matchingIds, {1, 2});
      expect(list.projectTasks.map((task) => task.id), contains(2));
      expect(list.projectTasks.map((task) => task.id), isNot(contains(5)));
      expect(list.tasksById.keys, contains(9));
    });

    test('with tasks without dates adds every task missing one', () async {
      expect((await source(71, withoutDates: true)).matchingIds, {
        1,
        2,
        3,
        4,
        5,
        6,
      });
    });

    test("ANDs the view's own filter", () async {
      expect((await source(73)).matchingIds, {1});
      expect((await source(73, withoutDates: true)).matchingIds, {1, 3, 4, 6});
    });

    test("a view filter only the server evaluates: the range over the view's "
        'last download, none before one', () async {
      expect((await source(74)).matchingIds, isEmpty);

      await db.listSnapshotsDao.replace('view:74', {
        1: 1,
        3: 2,
        4: 3,
      }, loadedAt: now);

      expect((await source(74)).matchingIds, {1});
      expect((await source(74, withoutDates: true)).matchingIds, {1, 3, 4});
    });

    test("a refused view's include-nulls still applies to the range", () async {
      await db.listSnapshotsDao.replace('view:77', {
        1: 1,
        3: 2,
        4: 3,
      }, loadedAt: now);

      expect((await source(77)).matchingIds, {1, 3, 4});
    });

    test('a change made here enters and leaves the timeline at once', () async {
      final seen = <ProjectListSource>[];
      final subscription = repository
          .watchProjectList(
            7,
            viewId: 71,
            includeDone: false,
            request: timeline(),
          )
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.last.matchingIds, {1, 2});

      await repository.updateTask(
        3,
        TaskChanges(startDate: DateChange.set(DateTime.utc(2026, 11, 20, 9))),
      );
      await repository.updateTask(
        1,
        TaskChanges(
          startDate: DateChange.set(DateTime.utc(2026, 12, 20, 9)),
          endDate: DateChange.set(DateTime.utc(2026, 12, 21, 9)),
        ),
      );
      await pumpEventQueue();

      expect(seen.last.matchingIds, {2, 3});
    });

    test('a view filter with a relative date is evaluated again as the '
        'clock moves', () async {
      final seen = <ProjectListSource>[];
      final subscription = repository
          .watchProjectList(
            7,
            viewId: 76,
            includeDone: false,
            request: timeline(),
          )
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.last.matchingIds, isEmpty);

      clock = DateTime.utc(2026, 11, 11, 9);
      clockTicks.add(null);
      await pumpEventQueue();

      expect(seen.last.matchingIds, {2});
    });

    test('in the zone of the timezone setting', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 10,
          title: 'Early on the last day',
          projectId: 7,
          start: DateTime.utc(2026, 11, 30, 5),
        ),
      ], syncRunId: 'run');
      expect((await source(71)).matchingIds, isNot(contains(10)));

      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(timezone: 'America/Los_Angeles'),
        ),
      });

      expect((await source(71)).matchingIds, contains(10));
    });
  });

  group('a table', () {
    test('without a filter lists every task of the project, done ones '
        'included, flat on the list path', () async {
      final list = await repository.watchProjectList(7, viewId: 72).first;

      expect(list.matchingIds, isNull);
      expect(list.projectTasks.map((task) => task.id).toSet(), {
        1,
        2,
        3,
        4,
        5,
        6,
      });
    });

    test('with a filter only the server evaluates is left to its '
        'download', () async {
      await db.listSnapshotsDao.replace('view:75', {4: 1, 3: 2}, loadedAt: now);

      final list = await repository
          .watchProjectList(7, viewId: 75, includeDone: false)
          .first;

      expect(list.matchingIds, isNull);
      expect(list.snapshot.taskIds, [4, 3]);
    });
  });

  group('a refresh', () {
    test('of a table or Gantt view the device evaluates only syncs', () async {
      for (final viewId in [71, 72, 73, 76]) {
        await repository.refreshProjectList(7, viewId: viewId);
      }

      expect(sync.refreshCalls, 4);
      expect(read.requests, isEmpty);
    });

    test('of one whose filter only the server evaluates downloads its '
        'tasks too', () async {
      read.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      for (final viewId in [74, 75]) {
        await expectLater(
          repository.refreshProjectList(7, viewId: viewId),
          throwsA(isA<NetworkFailure>()),
        );
      }

      expect(read.requests, [
        'project 7 view 74 tasks (all) per_page=50 page=1',
        'project 7 view 75 tasks (all) per_page=50 page=1',
      ]);
    });
  });
}
