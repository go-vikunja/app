@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// Step 29's Gantt probe fixture (gantt.md §3.1 in the step's research):
// dates around the web's default range on 2026-10-26, a dateless parent,
// a parent with a dateless and an out-of-range child, done tasks and a
// start a few hours into the last day. Titles are lower case only, as
// SQLite orders titles by their bytes and the app ignores case.
typedef _Fixture = ({
  String key,
  String? start,
  String? end,
  String? due,
  bool done,
  int priority,
  double percent,
});

_Fixture _task(
  String key, {
  String? start,
  String? end,
  String? due,
  bool done = false,
  int priority = 0,
  double percent = 0,
}) => (
  key: key,
  start: start,
  end: end,
  due: due,
  done: done,
  priority: priority,
  percent: percent,
);

final List<_Fixture> _fixture = [
  _task(
    'a',
    start: '2026-10-20T10:00:00Z',
    end: '2026-10-25T10:00:00Z',
    priority: 3,
    percent: 0.5,
  ),
  _task('b', start: '2026-11-01T10:00:00Z', priority: 1),
  _task('c', end: '2026-11-05T10:00:00Z', priority: 5, percent: 0.25),
  _task('d', due: '2026-11-10T10:00:00Z', priority: 3),
  _task('e'),
  _task(
    'f',
    start: '2026-09-01T10:00:00Z',
    end: '2027-01-31T10:00:00Z',
    percent: 1,
  ),
  _task(
    'g',
    start: '2026-10-15T10:00:00Z',
    end: '2026-10-18T10:00:00Z',
    done: true,
    priority: 2,
  ),
  _task(
    'h',
    start: '2026-12-15T10:00:00Z',
    end: '2027-01-15T10:00:00Z',
    percent: 0.29,
  ),
  _task('i', start: '2026-08-01T10:00:00Z', end: '2026-08-10T10:00:00Z'),
  _task('j', start: '2027-02-01T10:00:00Z', end: '2027-02-10T10:00:00Z'),
  _task('k', start: '2026-12-20T09:00:00Z'),
  _task('m', start: '2026-12-19T23:30:00Z'),
  _task('n', end: '2026-10-10T23:30:00Z'),
  _task('o', start: '2026-09-01T10:00:00Z', due: '2027-01-31T10:00:00Z'),
  _task('p', start: '2026-09-15T10:00:00Z', priority: 4),
  _task('q'),
  _task('q1', start: '2026-11-02T10:00:00Z', end: '2026-11-04T10:00:00Z'),
  _task('r', start: '2026-11-01T10:00:00Z', end: '2026-11-20T10:00:00Z'),
  _task('r1'),
  _task('r2', start: '2027-03-01T10:00:00Z', end: '2027-03-05T10:00:00Z'),
  _task('s', end: '2027-01-10T10:00:00Z'),
  _task('t', due: '2027-01-10T10:00:00Z'),
  _task('u', start: '2026-12-20T00:00:00Z'),
  _task('v', done: true),
  _task('w', start: '2026-10-20T10:00:00Z', end: '2026-10-21T10:00:00Z'),
  _task('x', start: '2026-12-20T05:00:00Z'),
];

const _subtasks = {
  'q': ['q1'],
  'r': ['r1', 'r2'],
};

const _zones = ['UTC', 'Europe/Berlin', 'America/Los_Angeles'];

const _ranges = [
  GanttRange(from: CalendarDate(2026, 10, 11), to: CalendarDate(2026, 12, 20)),
  GanttRange(from: CalendarDate(2026, 11, 1), to: CalendarDate(2026, 11, 30)),
];

const List<TableSort> _tableSorts = [
  TableSort.defaultSort,
  TableSort(TableSortField.taskIndex, descending: false),
  TableSort(TableSortField.done, descending: false),
  TableSort(TableSortField.done, descending: true),
  TableSort(TableSortField.title, descending: false),
  TableSort(TableSortField.priority, descending: true),
  TableSort(TableSortField.priority, descending: false),
  TableSort(TableSortField.dueDate, descending: false),
  TableSort(TableSortField.dueDate, descending: true),
  TableSort(TableSortField.startDate, descending: true),
  TableSort(TableSortField.endDate, descending: false),
  TableSort(TableSortField.percentDone, descending: false),
  TableSort(TableSortField.doneAt, descending: false),
  TableSort(TableSortField.doneAt, descending: true),
];

TaskSortField _serverField(TableSortField field) => switch (field) {
  TableSortField.taskIndex => TaskSortField.taskIndex,
  TableSortField.done => TaskSortField.done,
  TableSortField.title => TaskSortField.title,
  TableSortField.priority => TaskSortField.priority,
  TableSortField.dueDate => TaskSortField.dueDate,
  TableSortField.startDate => TaskSortField.startDate,
  TableSortField.endDate => TaskSortField.endDate,
  TableSortField.percentDone => TaskSortField.percentDone,
  TableSortField.doneAt => TaskSortField.doneAt,
  TableSortField.created => TaskSortField.created,
  TableSortField.updated => TaskSortField.updated,
};

void main() {
  group(
    'the timeline and the table against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late int projectId;
      late int openGanttId;
      final ids = <String, int>{};

      Future<T> paced<T>(Future<T> Function() write) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return await write();
      }

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        final seeder = Seeder(dio, connection, user);
        projectId = await paced(
          () => seeder.create('/projects', {'title': 'Timeline fixture'}),
        );
        for (final task in _fixture) {
          ids[task.key] = await paced(
            () => seeder.create('/projects/$projectId/tasks', {
              'title': 'gantt ${task.key}',
              'start_date': ?task.start,
              'end_date': ?task.end,
              'due_date': ?task.due,
              if (task.done) 'done': true,
              if (task.priority != 0) 'priority': task.priority,
              if (task.percent != 0) 'percent_done': task.percent,
            }),
          );
        }
        for (final MapEntry(key: parent, value: children)
            in _subtasks.entries) {
          for (final child in children) {
            await paced(
              () => seeder.post('/tasks/${ids[parent]}/relations', {
                'other_task_id': ids[child],
                'relation_kind': 'subtask',
              }),
            );
          }
        }
        openGanttId = await paced(
          () => seeder.create('/projects/$projectId/views', {
            'title': 'Open timeline',
            'view_kind': 'gantt',
            'filter': {'filter': 'done = false', 'filter_include_nulls': false},
          }),
        );
        // Marked done by an update, a second apart, so they have a done_at
        // (one created done has none).
        await paced(() => seeder.patch('/tasks/${ids['w']}', {'done': true}));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        await paced(() => seeder.patch('/tasks/${ids['a']}', {'done': true}));
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late AppDatabase db;
          late VikunjaReadClient reads;
          late LocalTaskRepository tasks;
          late ProjectView gantt;
          late ProjectView openGantt;
          late ProjectView table;

          Future<List<int>> serverIds(int viewId, TaskQuery query) async {
            final listed = <int>[];
            for (var page = 1; ; page++) {
              final result = await despiteWriteRaces(
                () => reads.tasks.listInView(
                  projectId,
                  viewId,
                  query.copyWith(page: page),
                ),
              );
              listed.addAll(result.items.map((task) => task.id));
              if (!result.hasMore) return listed;
            }
          }

          setUpAll(() async {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            final writes = createWriteClient(
              dio: authenticated,
              connection: only,
            );
            db = testDatabase();
            final engine = DefaultSyncEngine(
              db: db,
              client: reads,
              perPage: only.info.maxItemsPerPage,
              currentUser: AccountApi(
                authenticated,
                only,
              ).currentUserWithSettings,
            );
            addTearDown(engine.dispose);
            final sender = OutboxSender(
              db: db,
              writeClient: writes,
              readClient: reads,
              sync: engine,
            );
            addTearDown(sender.dispose);
            tasks = LocalTaskRepository(
              db,
              engine,
              sender,
              writes,
              read: reads,
              perPage: only.info.maxItemsPerPage,
            );
            addTearDown(tasks.dispose);
            await engine.ensureInitialSync();
            final project = (await db.projectsDao.loadProject(projectId))!;
            gantt = project.views.firstWhere(
              (view) => view.kind == ProjectViewKind.gantt,
            );
            table = project.views.firstWhere(
              (view) => view.kind == ProjectViewKind.table,
            );
            openGantt = project.views.firstWhere(
              (view) => view.id == openGanttId,
            );
            expect(openGantt.filter?.filter, 'done = false');
          });

          /// The tasks the server lists for the web's Gantt request in
          /// [view], and those this device does: the matching ones and all
          /// their subtasks.
          Future<
            ({
              Set<String> server,
              Set<String> local,
              List<String> serverOrder,
              List<String> topLevelRows,
            })
          >
          compare(
            ProjectView view,
            GanttRange range, {
            required String zone,
            required bool withoutDates,
          }) async {
            final names = {
              for (final MapEntry(:key, :value) in ids.entries) value: key,
            };
            await db.syncStateDao.write({
              SyncStateKeys.userSettings: encodeUserSettings(
                UserSettings(timezone: zone),
              ),
            });
            final request = ViewFilter(
              filter: ganttFilterText(range),
              includeNulls: withoutDates,
            );
            final server = await serverIds(
              view.id,
              TaskQuery(
                filter: request.filter,
                includeNulls: withoutDates,
                filterTimezone: zone,
                expand: const {TaskExpand.subtasks},
                sort: const [
                  TaskSort(TaskSortField.startDate),
                  TaskSort(TaskSortField.done),
                  TaskSort(TaskSortField.id, descending: true),
                ],
                perPage: 50,
              ),
            );
            final source = await tasks
                .watchProjectList(
                  projectId,
                  viewId: view.id,
                  includeDone: false,
                  request: request,
                )
                .first;
            final listed = {...source.matchingIds!};
            var frontier = source.matchingIds!;
            while (frontier.isNotEmpty) {
              frontier = {
                for (final id in frontier)
                  for (final subtask
                      in source.tasksById[id]?.subtasks ?? <Task>[])
                    if (listed.add(subtask.id)) subtask.id,
              };
            }
            final layout = layoutGantt(
              matching: [
                for (final task in source.projectTasks)
                  if (source.matchingIds!.contains(task.id)) task,
              ],
              tasksById: source.tasksById,
              range: range,
              today: const CalendarDate(2026, 10, 26),
              zone: locationForFilters([zone]),
              showTasksWithoutDates: withoutDates,
            );
            return (
              server: {for (final id in server) names[id]!},
              local: {for (final id in listed) names[id]!},
              serverOrder: [for (final id in server) names[id]!],
              topLevelRows: [
                for (final row in layout.rows)
                  if (row.indent == 0) names[row.task.id]!,
              ],
            );
          }

          test("the timeline lists the server's answer to the web's Gantt "
              'request, in three zones, with and without tasks without '
              'dates', () async {
            var compared = 0;
            for (final zone in _zones) {
              for (final range in _ranges) {
                for (final withoutDates in [false, true]) {
                  final (
                    :server,
                    :local,
                    :serverOrder,
                    :topLevelRows,
                  ) = await compare(
                    gantt,
                    range,
                    zone: zone,
                    withoutDates: withoutDates,
                  );
                  final reason =
                      '$range in $zone, without dates: $withoutDates';
                  expect(local, server, reason: reason);
                  // The top-level tasks come first, in the timeline's order.
                  expect(
                    topLevelRows,
                    serverOrder.where(topLevelRows.contains).toList(),
                    reason: reason,
                  );
                  compared++;
                }
              }
            }
            expect(compared, 12);
          });

          test("a Gantt view's own filter is ANDed, include-nulls covering "
              'it too', () async {
            for (final withoutDates in [false, true]) {
              final (
                :server,
                :local,
                serverOrder: _,
                topLevelRows: _,
              ) = await compare(
                openGantt,
                _ranges.first,
                zone: 'UTC',
                withoutDates: withoutDates,
              );
              expect(local, server, reason: 'without dates: $withoutDates');
              expect(local, isNot(contains('g')));
            }
          });

          test("the table's sorts give the server's order, missing values "
              'last both ways and ties newest first', () async {
            final source = await tasks
                .watchProjectList(projectId, viewId: table.id)
                .first;
            expect(source.matchingIds, isNull);
            expect(source.projectTasks, hasLength(_fixture.length));
            final names = {
              for (final MapEntry(:key, :value) in ids.entries) value: key,
            };
            for (final sort in _tableSorts) {
              final local = [...source.projectTasks]
                ..sort((a, b) => compareTasksForTable(a, b, sort));
              final server = await serverIds(
                table.id,
                TaskQuery(
                  sort: [
                    TaskSort(
                      _serverField(sort.field),
                      descending: sort.descending,
                    ),
                  ],
                  perPage: 50,
                ),
              );
              expect(
                [for (final task in local) names[task.id]],
                [for (final id in server) names[id]],
                reason: sort.wireName,
              );
            }
          });

          test('a table or Gantt view without a filter is never downloaded, '
              'a refresh only syncs', () async {
            await tasks.refreshProjectList(projectId, viewId: gantt.id);
            await tasks.refreshProjectList(projectId, viewId: table.id);

            for (final view in [gantt, table]) {
              final source = await tasks
                  .watchProjectList(projectId, viewId: view.id)
                  .first;
              expect(source.snapshot.loadedAt, isNull);
            }
          });
        });
      }
    },
  );
}
