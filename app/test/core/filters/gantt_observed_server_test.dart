import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

// The answers Vikunja 2.7.0 gave the web's exact Gantt request on
// 2026-10-26 (step 29's probe, `observed_server` in gantt-vectors.json),
// identical on v1 and v2: every task the server listed, the matching ones
// and their subtasks (`expand=subtasks`). An empty zone is the server's
// own, GMT, which was also the probe user's timezone setting.
const _project = 7;
const _ganttView = 71;

typedef _Fixture = ({String key, String? start, String? end, String? due});

const List<_Fixture> _fixture = [
  (
    key: 'A',
    start: '2026-10-20T10:00:00Z',
    end: '2026-10-25T10:00:00Z',
    due: null,
  ),
  (key: 'B', start: '2026-11-01T10:00:00Z', end: null, due: null),
  (key: 'C', start: null, end: '2026-11-05T10:00:00Z', due: null),
  (key: 'D', start: null, end: null, due: '2026-11-10T10:00:00Z'),
  (key: 'E', start: null, end: null, due: null),
  (
    key: 'F',
    start: '2026-09-01T10:00:00Z',
    end: '2027-01-31T10:00:00Z',
    due: null,
  ),
  (
    key: 'G',
    start: '2026-10-15T10:00:00Z',
    end: '2026-10-18T10:00:00Z',
    due: null,
  ),
  (
    key: 'H',
    start: '2026-12-15T10:00:00Z',
    end: '2027-01-15T10:00:00Z',
    due: null,
  ),
  (
    key: 'I',
    start: '2026-08-01T10:00:00Z',
    end: '2026-08-10T10:00:00Z',
    due: null,
  ),
  (
    key: 'J',
    start: '2027-02-01T10:00:00Z',
    end: '2027-02-10T10:00:00Z',
    due: null,
  ),
  (key: 'K', start: '2026-12-20T09:00:00Z', end: null, due: null),
  (key: 'M', start: '2026-12-19T23:30:00Z', end: null, due: null),
  (key: 'N', start: null, end: '2026-10-10T23:30:00Z', due: null),
  (
    key: 'O',
    start: '2026-09-01T10:00:00Z',
    end: null,
    due: '2027-01-31T10:00:00Z',
  ),
  (key: 'P', start: '2026-09-15T10:00:00Z', end: null, due: null),
  (key: 'Q', start: null, end: null, due: null),
  (
    key: 'Q1',
    start: '2026-11-02T10:00:00Z',
    end: '2026-11-04T10:00:00Z',
    due: null,
  ),
  (
    key: 'R',
    start: '2026-11-01T10:00:00Z',
    end: '2026-11-20T10:00:00Z',
    due: null,
  ),
  (key: 'R1', start: null, end: null, due: null),
  (
    key: 'R2',
    start: '2027-03-01T10:00:00Z',
    end: '2027-03-05T10:00:00Z',
    due: null,
  ),
  (key: 'S', start: null, end: '2027-01-10T10:00:00Z', due: null),
  (key: 'T', start: null, end: null, due: '2027-01-10T10:00:00Z'),
  (key: 'U', start: '2026-12-20T00:00:00Z', end: null, due: null),
  (key: 'V', start: null, end: null, due: null),
  (
    key: 'W',
    start: '2026-10-20T10:00:00Z',
    end: '2026-10-21T10:00:00Z',
    due: null,
  ),
];

// Created after the runs, for the extras.
const _Fixture _x = (
  key: 'X',
  start: '2026-12-20T05:00:00Z',
  end: null,
  due: null,
);

const _done = {'G', 'V'};
const _subtasks = {
  'Q': ['Q1'],
  'R': ['R1', 'R2'],
};

typedef _Run = ({
  String from,
  String to,
  String zone,
  bool withoutDates,
  String titles,
});

const List<_Run> _runs = [
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: '',
    withoutDates: false,
    titles: 'F G W A R B Q1 H M U D C R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: '',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'UTC',
    withoutDates: false,
    titles: 'F G W A R B Q1 H M U D C R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'UTC',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'Europe/Berlin',
    withoutDates: false,
    titles: 'F G W A R B Q1 H N D C R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'Europe/Berlin',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'America/Los_Angeles',
    withoutDates: false,
    titles: 'F G W A R B Q1 H M U D C R1 R2',
  ),
  (
    from: '2026-10-11',
    to: '2026-12-20',
    zone: 'America/Los_Angeles',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: '',
    withoutDates: false,
    titles: 'F R B Q1 D C R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: '',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'UTC',
    withoutDates: false,
    titles: 'F R B Q1 D C R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'UTC',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'Europe/Berlin',
    withoutDates: false,
    titles: 'F R B Q1 D C R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'Europe/Berlin',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'America/Los_Angeles',
    withoutDates: false,
    titles: 'F R B Q1 D C R1 R2',
  ),
  (
    from: '2026-11-01',
    to: '2026-11-30',
    zone: 'America/Los_Angeles',
    withoutDates: true,
    titles: 'I O F P G W A R B H M U K J T S Q N E D C V Q1 R1 R2',
  ),
];

void main() {
  late AppDatabase db;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  final now = DateTime.utc(2026, 10, 26, 12);
  final keys = <int, String>{};

  Task fixtureTask(_Fixture fixture, int id) {
    DateTime? at(String? text) => text == null ? null : DateTime.parse(text);
    final parent = _subtasks.entries
        .where((entry) => entry.value.contains(fixture.key))
        .map((entry) => entry.key)
        .firstOrNull;
    return sampleTask(
      id: id,
      title: fixture.key,
      projectId: _project,
      start: at(fixture.start),
      end: at(fixture.end),
      due: at(fixture.due),
      done: _done.contains(fixture.key),
      subtaskIds: [
        for (final child in _subtasks[fixture.key] ?? const <String>[])
          100 + _fixture.indexWhere((task) => task.key == child) + 1,
      ],
      parentIds: [
        if (parent != null)
          100 + _fixture.indexWhere((task) => task.key == parent) + 1,
      ],
    );
  }

  Future<void> useView({String filter = ''}) => db.projectsDao.upsertAll([
    sampleProject(
      id: _project,
      title: 'Gantt',
      views: [
        ProjectView(
          id: _ganttView,
          projectId: _project,
          title: 'Gantt',
          kind: ProjectViewKind.gantt,
          position: 200,
          filter: filter.isEmpty ? null : ViewFilter(filter: filter),
        ),
      ],
    ),
  ]);

  setUp(() async {
    db = testDatabase();
    final write = FakeWriteClient(clock: () => now);
    final sync = RecordingSyncEngine();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: FakeSyncClient(),
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: FakeSyncClient(),
      now: () => now,
    );
    addTearDown(repository.dispose);
    await useView();
    final tasks = [
      for (final (index, fixture) in _fixture.indexed)
        fixtureTask(fixture, 100 + index + 1),
    ];
    for (final task in tasks) {
      keys[task.id] = task.title;
    }
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
  });

  Future<void> addX() async {
    final x = fixtureTask(_x, 200);
    keys[x.id] = 'X';
    await db.tasksDao.upsertAll([x], syncRunId: 'run');
  }

  /// What the server lists: the matching tasks and all their subtasks.
  Future<
    ({Set<String> matching, Set<String> listed, List<String> topLevelRows})
  >
  evaluate({
    required String from,
    required String to,
    required String zone,
    required bool withoutDates,
  }) async {
    await db.syncStateDao.write({
      SyncStateKeys.userSettings: encodeUserSettings(
        UserSettings(timezone: zone.isEmpty ? 'GMT' : zone),
      ),
    });
    final range = GanttRange(
      from: CalendarDate.tryParse(from)!,
      to: CalendarDate.tryParse(to)!,
    );
    final source = await repository
        .watchProjectList(
          _project,
          viewId: _ganttView,
          includeDone: false,
          request: ViewFilter(
            filter: ganttFilterText(range),
            includeNulls: withoutDates,
          ),
        )
        .first;
    final matching = source.matchingIds!;
    final listed = {...matching};
    var frontier = matching;
    while (frontier.isNotEmpty) {
      frontier = {
        for (final id in frontier)
          for (final subtask in source.tasksById[id]?.subtasks ?? <Task>[])
            if (listed.add(subtask.id)) subtask.id,
      };
    }
    final layout = layoutGantt(
      matching: [
        for (final task in source.projectTasks)
          if (matching.contains(task.id)) task,
      ],
      tasksById: source.tasksById,
      range: range,
      today: const CalendarDate(2026, 10, 26),
      zone: locationForFilters([if (zone.isEmpty) 'GMT' else zone]),
      showTasksWithoutDates: withoutDates,
    );
    return (
      matching: {for (final id in matching) keys[id]!},
      listed: {for (final id in listed) keys[id]!},
      topLevelRows: [
        for (final row in layout.rows)
          if (row.indent == 0) keys[row.task.id]!,
      ],
    );
  }

  Set<String> titles(String spaced) => spaced.split(' ').toSet();

  test('every observed run lists what the server listed, in every zone and '
      'with the toggle off and on', () async {
    for (final run in _runs) {
      final result = await evaluate(
        from: run.from,
        to: run.to,
        zone: run.zone,
        withoutDates: run.withoutDates,
      );
      final reason =
          '${run.from}..${run.to} in "${run.zone}", without dates: '
          '${run.withoutDates}';
      expect(result.listed, titles(run.titles), reason: reason);
      // The server lists the top-level tasks first, in the timeline's
      // order; the timeline leaves out those whose bar misses the range.
      final serverOrder = run.titles.split(' ');
      expect(
        result.topLevelRows,
        serverOrder.where(result.topLevelRows.contains).toList(),
        reason: reason,
      );
      expect(result.topLevelRows, isNotEmpty, reason: reason);
    }
  });

  test("the matching tasks alone are the server's answer without "
      'expand', () async {
    final result = await evaluate(
      from: '2026-10-11',
      to: '2026-12-20',
      zone: 'Europe/Berlin',
      withoutDates: false,
    );

    expect(result.matching, titles('F G W A R B Q1 H N D C'));
  });

  test('a start on the last day after midnight matches only in a zone where '
      'that is still the day before', () async {
    await addX();
    for (final (zone, listed) in [
      ('UTC', 'F G W A R B Q1 H M U D C R1 R2'),
      ('America/Los_Angeles', 'F G W A R B Q1 H M U X D C R1 R2'),
      ('Europe/Berlin', 'F G W A R B Q1 H N D C R1 R2'),
    ]) {
      final result = await evaluate(
        from: '2026-10-11',
        to: '2026-12-20',
        zone: zone,
        withoutDates: false,
      );
      expect(result.listed, titles(listed), reason: zone);
    }
  });

  test("a view filter is ANDed, and the toggle's include-nulls never brings "
      'back a done task', () async {
    await addX();
    await useView(filter: 'done = false');
    for (final (withoutDates, listed) in [
      (false, 'F W A R B Q1 H M U D C R1 R2'),
      (true, 'I O F P W A R B H M U X K J T S Q N E D C Q1 R1 R2'),
    ]) {
      final result = await evaluate(
        from: '2026-10-11',
        to: '2026-12-20',
        zone: 'UTC',
        withoutDates: withoutDates,
      );
      expect(result.listed, titles(listed), reason: '$withoutDates');
    }
  });

  test('a reversed range and a single day', () async {
    await addX();
    expect(
      (await evaluate(
        from: '2026-12-20',
        to: '2026-10-11',
        zone: 'UTC',
        withoutDates: false,
      )).listed,
      titles('F G W A R Q1 H R1 R2'),
    );
    expect(
      (await evaluate(
        from: '2026-11-01',
        to: '2026-11-01',
        zone: 'UTC',
        withoutDates: false,
      )).listed,
      {'F'},
    );
  });
}
