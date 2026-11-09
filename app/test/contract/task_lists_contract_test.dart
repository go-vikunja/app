@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// The Upcoming comparison sends the process's zone as `filter_timezone`, so
// the run needs an explicit IANA name: TZ=Europe/Berlin VIKUNJA_CONTRACT=1
// flutter test --tags contract.
final String? _zone = Platform.environment['TZ'];

typedef _Seed = ({
  int listsId,
  int otherId,
  List<int> datedOpen,
  int undated,
  int archived,
  int importantId,
  int importantViewId,
  int importantDone,
  int sharedId,
  int sharedXId,
});

List<int> _flatten(Iterable<TaskTreeNode> nodes) => [
  for (final node in nodes) ...[node.task.id, ..._flatten(node.children)],
];

List<int> _ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

/// Whole seconds at :17, so that no due date falls on a midnight or week
/// bound and the server's second precision changes nothing.
String _due(DateTime moment) {
  final utc = moment.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    17,
  ).toIso8601String();
}

void main() {
  group('task lists against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late Seeder seeder;
    late _Seed seed;
    late int pseudoId;
    late int movedId;

    Future<List<Map<String, Object?>>> v2Items(
      String path,
      Map<String, Object> query,
    ) async {
      final v2 = connection.apiBaseUri(ApiVersion.v2);
      final response = await despiteWriteRaces(
        () => dio.getUri<Map<String, Object?>>(
          v2.replace(path: '${v2.path}$path', queryParameters: query),
          options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
        ),
      );
      return [
        for (final item in response.data!['items']! as List<Object?>)
          item! as Map<String, Object?>,
      ];
    }

    Future<int> task(
      int projectId,
      String title, [
      Map<String, Object?>? more,
    ]) =>
        seeder.create('/projects/$projectId/tasks', {'title': title, ...?more});

    Future<void> subtask(int parent, int child) => seeder.post(
      '/tasks/$parent/relations',
      {'other_task_id': child, 'relation_kind': 'subtask'},
    );

    Future<void> assignMe(int taskId) =>
        seeder.post('/tasks/$taskId/assignees', {'user_id': user.id});

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      user = await registerAndLogin(dio, connection);
      seeder = Seeder(dio, connection, user);
      final now = DateTime.now();

      final listsId = await seeder.create('/projects', {'title': 'Lists'});
      final otherId = await seeder.create('/projects', {'title': 'Other'});
      final datesId = await seeder.create('/projects', {'title': 'Dates'});
      final archiveId = await seeder.create('/projects', {'title': 'Archive'});

      final oldest = await task(listsId, 'Oldest');
      await task(listsId, 'Done', {'done': true});
      final parent = await task(listsId, 'Parent');
      final openChild = await task(listsId, 'Open child');
      final doneChild = await task(listsId, 'Done child', {'done': true});
      final grandchild = await task(listsId, 'Grandchild');
      final doneParent = await task(listsId, 'Done parent', {'done': true});
      final orphan = await task(listsId, 'Open child of a done parent');
      final crossParent = await task(listsId, 'Cross-project parent');
      final crossChild = await task(otherId, 'Child elsewhere');
      await task(listsId, 'Newest');
      await subtask(parent, openChild);
      await subtask(parent, doneChild);
      await subtask(openChild, grandchild);
      await subtask(doneParent, orphan);
      await subtask(crossParent, crossChild);
      for (final id in [oldest, orphan, crossChild]) {
        await assignMe(id);
      }
      await assignMe(doneChild);

      final datedOpen = [
        for (final offset in const [
          Duration(hours: -30),
          Duration(minutes: -90),
          Duration(minutes: 90),
          Duration(hours: 26),
          Duration(days: 3),
          Duration(days: 6, hours: 20),
          Duration(days: 9),
          Duration(days: 40),
        ])
          await task(datesId, 'Due in $offset', {
            'due_date': _due(now.add(offset)),
          }),
      ];
      final undated = await task(datesId, 'Undated');
      await task(datesId, 'Done and due', {
        'done': true,
        'due_date': _due(now.add(const Duration(hours: 2))),
      });
      // The server takes no task into an archived project.
      final archived = await task(archiveId, 'Archived and due', {
        'due_date': _due(now.add(const Duration(hours: 2))),
      });
      await seeder.patch('/projects/$archiveId', {'is_archived': true});

      // The oldest task sits at the bottom of the List view; move it up.
      final project = await seeder.get('/projects/$listsId');
      final listView = (project['views']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere((view) => view['view_kind'] == 'list');
      await seeder.put('/tasks/$oldest/position', {
        'project_view_id': listView['id'],
        'position': 1.5,
      });
      movedId = oldest;

      // Open R, done P below it and open X below P: the server sends X as
      // a root too, and the web shows it only under P.
      final sharedId = await seeder.create('/projects', {
        'title': 'Shared subtasks',
      });
      final sharedR = await task(sharedId, 'R');
      final sharedP = await task(sharedId, 'P', {'done': true});
      final sharedXId = await task(sharedId, 'X');
      await subtask(sharedR, sharedP);
      await subtask(sharedP, sharedXId);

      // A view the device cannot evaluate, its done task moved to the top.
      final importantId = await seeder.create('/projects', {
        'title': 'Important',
      });
      await task(importantId, 'Open p3', {'priority': 3});
      final importantDone = await task(importantId, 'Done p4', {
        'priority': 4,
        'done': true,
      });
      await task(importantId, 'Open p5', {'priority': 5});
      await task(importantId, 'Open p1', {'priority': 1});
      final importantViewId = await seeder.create(
        '/projects/$importantId/views',
        {
          'title': 'Important',
          'view_kind': 'list',
          'filter': {'filter': 'priority >= 3', 'filter_include_nulls': false},
        },
      );
      await seeder.put('/tasks/$importantDone/position', {
        'project_view_id': importantViewId,
        'position': 1.5,
      });

      // The web stores the saved filter's pseudo project id.
      final projects = await v2Items('/projects', {'per_page': '50'});
      pseudoId = projects
          .map((project) => project['id']! as int)
          .firstWhere((id) => id < Project.favoritesId);
      await seeder.patch('/user/settings/general', {
        'frontend_settings': {'filter_id_used_on_overview': pseudoId},
      });

      seed = (
        listsId: listsId,
        otherId: otherId,
        datedOpen: datedOpen,
        undated: undated,
        archived: archived,
        importantId: importantId,
        importantViewId: importantViewId,
        importantDone: importantDone,
        sharedId: sharedId,
        sharedXId: sharedXId,
      );
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      group('synced over ${apiVersion.pathSegment}', () {
        late VikunjaReadClient reads;
        late AppDatabase db;
        late LocalTaskRepository tasks;

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
        });

        test(
          "the project's List view nests and orders like the web's",
          () async {
            final project = (await db.projectsDao.loadAll()).firstWhere(
              (project) => project.id == seed.listsId,
            );
            final view = project.views.firstWhere(
              (view) => view.kind == ProjectViewKind.list,
            );
            expect(classifyViewFilter(view.filter), ViewFilterKind.openOnly);

            await tasks.refreshProjectList(seed.listsId, viewId: view.id);
            final source = await tasks
                .watchProjectList(seed.listsId, viewId: view.id)
                .first;
            final positions = source.snapshot.positions;
            final matching =
                [
                  for (final task in source.projectTasks)
                    if (!task.done) task,
                ]..sort(
                  (a, b) => compareTasksForList(
                    a,
                    b,
                    TaskListSort.manual,
                    positions: positions,
                  ),
                );
            final tree = buildTaskTree(
              matching: matching,
              tasksById: source.tasksById,
            );

            final server = await v2Items(
              '/projects/${seed.listsId}/views/${view.id}/tasks',
              {'expand': 'subtasks', 'per_page': '50'},
            );
            final serverIds = [for (final item in server) item['id']! as int];
            final roots = _ids(tree.map((node) => node.task));
            expect(roots.first, movedId);
            expect(serverIds.take(roots.length), roots);
            expect(serverIds.toSet(), _flatten(tree).toSet());
            expect(
              source.tasksById.values.any((t) => t.projectId == seed.otherId),
              isTrue,
            );
          },
        );

        test('a task below a done subtask shows once, nested, as the web '
            'shows the server answer', () async {
          final project = (await db.projectsDao.loadAll()).firstWhere(
            (project) => project.id == seed.sharedId,
          );
          final view = project.views.firstWhere(
            (view) => view.kind == ProjectViewKind.list,
          );

          await tasks.refreshProjectList(seed.sharedId, viewId: view.id);
          final source = await tasks
              .watchProjectList(seed.sharedId, viewId: view.id)
              .first;
          final tree = buildTaskTree(
            matching: [
              for (final task in source.projectTasks)
                if (!task.done) task,
            ],
            tasksById: source.tasksById,
          );

          final server = await v2Items(
            '/projects/${seed.sharedId}/views/${view.id}/tasks',
            {'expand': 'subtasks', 'per_page': '50'},
          );
          final sent = {for (final item in server) item['id']! as int};
          Iterable<int> parentIdsOf(Map<String, Object?> item) => [
            if (item['related_tasks'] case {
              'parenttask': final List<Object?> parents,
            })
              for (final parent in parents)
                (parent! as Map<String, Object?>)['id']! as int,
          ];
          final webTop = {
            for (final item in server)
              if (!parentIdsOf(item).any(sent.contains)) item['id']! as int,
          };
          final shown = _flatten(tree);

          expect(sent, contains(seed.sharedXId));
          expect(_ids(tree.map((node) => node.task)).toSet(), webTop);
          expect(shown.where((id) => id == seed.sharedXId), hasLength(1));
          expect(shown.toSet(), sent);
        });

        test("a filter the classifier does not know matches the server's "
            "on the device, and its download keeps the server's order, its "
            'done task among the open ones', () async {
          final project = (await db.projectsDao.loadAll()).firstWhere(
            (project) => project.id == seed.importantId,
          );
          final view = project.views.firstWhere(
            (view) => view.id == seed.importantViewId,
          );
          expect(classifyViewFilter(view.filter), ViewFilterKind.other);

          await tasks.refreshProjectList(seed.importantId, viewId: view.id);
          final source = await tasks
              .watchProjectList(
                seed.importantId,
                viewId: view.id,
                includeDone: false,
              )
              .first;
          final listed =
              [for (final id in source.snapshot.taskIds) source.tasksById[id]!]
                ..sort(
                  (a, b) => compareTasksForList(
                    a,
                    b,
                    TaskListSort.manual,
                    positions: source.snapshot.positions,
                    separateDone: false,
                  ),
                );

          final server = await v2Items(
            '/projects/${seed.importantId}/views/${view.id}/tasks',
            {'expand': 'subtasks', 'per_page': '50'},
          );
          expect(_ids(listed), [for (final item in server) item['id']! as int]);
          expect(source.matchingIds, _ids(listed).toSet());
          expect(_ids(listed), hasLength(3));
          expect(listed.first.id, seed.importantDone);
          expect(listed.first.done, isTrue);
        });

        test("the Overview shows the user's saved filter", () async {
          final overview = await tasks.watchOverviewTasks().first;

          expect(overview.filter?.projectId, pseudoId);
          // The sync read the filter's definition, so the device evaluates
          // it.
          expect(overview.filterEvaluation, FilterEvaluation.local);
          final server = await v2Items('/projects/$pseudoId/tasks', {
            'filter': 'done = false',
            'sort_by': ['due_date', 'id'],
            'order_by': ['asc', 'desc'],
            'per_page': '50',
          });
          expect(overview.tasks, hasLength(3));
          expect(_ids(overview.tasks), [
            for (final item in server) item['id']! as int,
          ]);
        });

        test(
          'Upcoming matches the web filter for today, this week and the '
          'next 7 days',
          skip: _zone == null ? 'Run with an explicit TZ' : null,
          () async {
            final active = await tasks.watchActiveOpenTasks().first;
            for (final preset in const [
              DateRangePreset.today,
              DateRangePreset.thisWeek,
              DateRangePreset.next7Days,
            ]) {
              final now = DateTime.now();
              final range = preset.resolve(now);
              Future<List<int>> serverIds(
                String filter, {
                bool includeNulls = false,
              }) async => [
                for (final item in await v2Items('/tasks', {
                  'filter': filter,
                  'filter_timezone': _zone!,
                  'filter_include_nulls': '$includeNulls',
                  'sort_by': ['due_date', 'id'],
                  'order_by': ['asc', 'desc'],
                  'per_page': '50',
                }))
                  item['id']! as int,
              ];

              final plain = selectUpcoming(
                active,
                range: range,
                now: now,
                showOverdue: false,
                showWithoutDueDate: false,
              );
              expect(
                _ids(plain.inRange),
                await serverIds(
                  "done = false && due_date < '${preset.to}' && "
                  "due_date > '${preset.from}'",
                ),
                reason: preset.name,
              );

              if (preset == DateRangePreset.next7Days) {
                expect(plain.inRange, hasLength(4));
              }

              final pinned = selectUpcoming(
                active,
                range: range,
                now: now,
                showOverdue: true,
                showWithoutDueDate: true,
              );
              expect(
                {..._ids(pinned.overdue), ..._ids(pinned.inRange)},
                (await serverIds("done = false && due_date < '${preset.to}'"))
                    .toSet(),
                reason: '${preset.name} with the overdue tasks',
              );
              final withNulls = await serverIds(
                "done = false && due_date < '${preset.to}' && "
                "due_date > '${preset.from}'",
                includeNulls: true,
              );
              expect(
                _ids(pinned.withoutDueDate).toSet(),
                withNulls.toSet().difference(_ids(plain.inRange).toSet()),
                reason: '${preset.name} without a due date',
              );
            }
            expect(
              active.map((task) => task.id),
              containsAll([...seed.datedOpen, seed.undated]),
            );
            expect(
              active.map((task) => task.id),
              isNot(contains(seed.archived)),
            );
          },
        );
      });
    }
  });
}
