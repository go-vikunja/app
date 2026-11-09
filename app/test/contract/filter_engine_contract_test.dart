@Tags(['contract'])
@Timeout(Duration(minutes: 12))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_saved_filter_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// The fixture of step 24's probe (scratchpad step24/probe/fixture.py) with
// one user: absolute dates around 2026-10-20 midnight in Europe/Berlin
// versus GMT and New York, plus two tasks due relative to now. No stored
// instant equals a bound of a filter below, which a SQLite server compares
// off by one.
const _zones = ['GMT', 'Europe/Berlin', 'America/New_York'];

typedef _Case = ({String filter, bool nulls, bool dated});

_Case _plain(String filter, {bool nulls = false}) =>
    (filter: filter, nulls: nulls, dated: false);

_Case _dated(String filter, {bool nulls = false}) =>
    (filter: filter, nulls: nulls, dated: true);

void main() {
  group(
    'the filter engine against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;
      final projects = <String, int>{};
      final labels = <String, int>{};
      final tasks = <String, int>{};
      late int myOpenTasks;

      Future<T> paced<T>(Future<T> Function() write) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return await write();
      }

      Future<int> task(
        String key,
        String project,
        String title, {
        Map<String, Object?> fields = const {},
        List<String> labelKeys = const [],
        bool assigned = false,
      }) async {
        final id = await paced(
          () => seeder.create('/projects/${projects[project]}/tasks', {
            'title': title,
            ...fields,
          }),
        );
        for (final label in labelKeys) {
          await paced(
            () => seeder.post('/tasks/$id/labels', {'label_id': labels[label]}),
          );
        }
        if (assigned) {
          await paced(
            () => seeder.post('/tasks/$id/assignees', {'user_id': user.id}),
          );
        }
        return tasks[key] = id;
      }

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
        // Identifiers are unique on the whole instance.
        final suffix = Random.secure()
            .nextInt(1 << 16)
            .toRadixString(16)
            .toUpperCase();
        for (final (key, title, identifier, parent) in [
          ('main', 'Filter Main', 'FLT$suffix', null),
          ('child', 'Filter Child', 'FCH$suffix', 'main'),
          ('grand', 'Filter Grandchild', '', 'child'),
          ('other', 'Filter Other', '', null),
          ('arch', 'Filter Archived', 'ARC$suffix', null),
          ('archchild', 'Filter Archived Child', '', 'arch'),
        ]) {
          projects[key] = await paced(
            () => seeder.create('/projects', {
              'title': title,
              'identifier': identifier,
              'parent_project_id': ?projects[parent],
            }),
          );
        }
        for (final (key, title) in [
          ('urgent', 'Urgent'),
          ('home', 'Home'),
          ('work', 'Work Stuff'),
        ]) {
          labels[key] = await paced(
            () => seeder.create('/labels', {'title': title}),
          );
        }
        final now = DateTime.now().toUtc();
        await task(
          't1',
          'main',
          'Alpha report',
          fields: {
            'description': '<p>Quarterly numbers</p>',
            'due_date': '2026-10-20T21:30:00Z',
          },
        );
        await task(
          't2',
          'main',
          'Beta review',
          fields: {
            'due_date': '2026-10-20T22:30:00Z',
            'priority': 1,
            'hex_color': 'ff0000',
          },
          labelKeys: ['urgent'],
        );
        await task(
          't3',
          'main',
          'gamma Plan',
          fields: {
            'due_date': '2026-10-20T00:30:00Z',
            'priority': 2,
            'percent_done': 0.25,
            'start_date': '2026-10-18T08:00:00Z',
            'end_date': '2026-10-22T18:00:00Z',
          },
          labelKeys: ['urgent', 'home'],
          assigned: true,
        );
        await task(
          't4',
          'main',
          'Delta',
          fields: {'due_date': '2026-10-19T22:30:00Z', 'priority': 3},
          labelKeys: ['home'],
        );
        await task(
          't5',
          'main',
          'Epsilon done',
          fields: {
            'due_date': '2026-10-01T12:00:00Z',
            'priority': 4,
            'done': true,
          },
          labelKeys: ['urgent', 'home', 'work'],
          assigned: true,
        );
        await task(
          't6',
          'main',
          'Zeta 100% sure',
          fields: {
            'priority': 5,
            'percent_done': 0.5,
            'start_date': '2026-10-21T00:00:00Z',
            'end_date': '2026-10-25T00:00:00Z',
          },
        );
        await task('t7', 'main', 'Eta_under', fields: {'percent_done': 1.0});
        await task(
          't8',
          'main',
          'Theta',
          fields: {
            'due_date': '2026-11-15T12:00:00Z',
            'repeat_after': 86400,
            'reminders': [
              {'reminder': '2026-10-25T08:00:00Z'},
              {'reminder': '2026-10-20T22:30:00Z'},
            ],
          },
        );
        final iota = await task(
          't9',
          'main',
          'Iota',
          fields: {'description': '<p>mentions ALPHA in the text</p>'},
        );
        // Marked done by an update, so it has a done_at.
        await paced(() => seeder.patch('/tasks/$iota', {'done': true}));
        await task('t10', 'main', 'Kappa #12 literal');
        await task(
          't11',
          'main',
          'Ärger mit Öl',
          fields: {'description': '<p>straße</p>'},
        );
        await task('t12', 'main', 'Lambda 50% off');
        await task(
          'r1',
          'main',
          'Soon',
          fields: {
            'due_date': now.add(const Duration(hours: 3)).toIso8601String(),
            'reminders': [
              {'reminder': now.add(const Duration(hours: 2)).toIso8601String()},
            ],
          },
        );
        await task(
          'r2',
          'main',
          'Next week',
          fields: {
            'due_date': now.add(const Duration(days: 5)).toIso8601String(),
          },
        );
        await task(
          'c1',
          'child',
          'Child alpha',
          fields: {'due_date': '2026-10-20T21:30:00Z'},
          labelKeys: ['urgent'],
        );
        await task('c2', 'child', 'Child done', fields: {'done': true});
        await task('g1', 'grand', 'Grandchild task', assigned: true);
        await task('o1', 'other', 'Other alpha', fields: {'priority': 3});
        await task('o2', 'other', 'Other', labelKeys: ['work']);
        await task(
          'a1',
          'arch',
          'Archived alpha',
          fields: {'due_date': '2026-10-20T21:30:00Z', 'is_favorite': true},
          labelKeys: ['urgent'],
        );
        await task('ac1', 'archchild', 'Archived child alpha');
        await paced(
          () => seeder.post('/tasks/${tasks['t6']}/relations', {
            'other_task_id': tasks['t7'],
            'relation_kind': 'subtask',
          }),
        );
        await paced(
          () => seeder.patch('/projects/${projects['arch']}', {
            'is_archived': true,
          }),
        );
        final listed =
            (await seeder.get('/projects'))['items']! as List<Object?>;
        myOpenTasks =
            listed.cast<Map<String, Object?>>().firstWhere(
                  (project) => project['title'] == 'My Open Tasks',
                )['id']!
                as int;
        await paced(
          () => seeder.patch('/user/settings/general', {
            'timezone': 'Europe/Berlin',
            'frontend_settings': {'filter_id_used_on_overview': myOpenTasks},
          }),
        );
      });

      tearDownAll(() => dio.close(force: true));

      List<_Case> cases() {
        final main = projects['main'];
        final child = projects['child'];
        final other = projects['other'];
        final urgent = labels['urgent'];
        final home = labels['home'];
        final work = labels['work'];
        final me = user.username;
        return [
          _plain('done = false'),
          _plain('done = true'),
          _plain('done != false'),
          _plain('priority = 3'),
          _plain('priority != 3'),
          _plain('priority >= 3'),
          _plain('priority < 2'),
          _plain('priority in 1, 3, 5'),
          _plain('priority not in 0, 1'),
          _plain('percent_done = 0.5'),
          _plain('percent_done > 0.2'),
          _plain('percent_done in 0.25, 1'),
          _plain('project = $main'),
          _plain('project_id != $main'),
          _plain('project in $main, $child'),
          _plain('labels = $urgent'),
          _plain('labels != $urgent'),
          _plain('labels in $home, $work'),
          _plain('labels not in $urgent, $home'),
          _plain('labels = $urgent && labels = $home'),
          _plain('labels > $home'),
          _plain('assignees = $me'),
          _plain('assignees != $me'),
          _plain('assignees in $me, nobody'),
          _plain('assignees like x'),
          _plain('created_by = $me'),
          _plain('title like alpha'),
          _plain('title like a_p'),
          _plain('title = Delta'),
          _plain('title like ÄRGER'),
          _plain('title like ärger'),
          _plain('description like <p>'),
          _plain('hex_color = ff0000'),
          _plain('index = 1'),
          _plain('repeat_after > 0'),
          _plain(
            'reminders > 2026-10-21T00:00:00Z && '
            'reminders < 2026-10-24T00:00:00Z',
          ),
          _plain('reminders > 2026-10-20T00:00:00Z'),
          _plain('done_at > 2026-01-01T00:00:00Z'),
          _plain('priority = 5 || priority = 3 && done = true'),
          _plain('priority > 3 || priority < 1 && done = true'),
          _plain('done = true && priority = 4 || priority = 5'),
          _plain('priority = 5 || (done = true && priority = 4)'),
          _plain('(labels = $urgent || project = $other) && done = false'),
          _plain('done = false && title like a', nulls: true),
          _plain('priority > 2', nulls: true),
          _plain('priority in 3, 4', nulls: true),
          _plain('labels = $urgent', nulls: true),
          _plain('assignees = $me', nulls: true),
          _plain('created_by = nobody', nulls: true),
          _plain('percent_done > 0.2', nulls: true),
          _dated('due_date >= 2026-10-20 && due_date < 2026-10-21'),
          _dated('due_date < 2026-10-20 22:00'),
          _dated('due_date > 2026-10-20'),
          _dated('due_date < 2026-10-20T22:00:00+02:00'),
          _dated('start_date > 2026-10-19 && end_date < 2026-10-23'),
          _dated('due_date > 0001-01-01'),
          _dated('due_date < now+1d'),
          _dated('due_date > now'),
          _dated('due_date >= now/d && due_date < now/d+7d'),
          _dated('reminders > now && reminders < now+1d'),
          _dated('due_date < 2026-10-21', nulls: true),
          _dated('done = false && due_date < now', nulls: true),
        ];
      }

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late AppDatabase db;
          late DefaultSyncEngine engine;
          late VikunjaReadClient reads;
          late VikunjaWriteClient writes;
          late LocalTaskRepository taskRepository;
          late LocalProjectRepository projectRepository;
          late LocalSavedFilterRepository savedFilters;

          Future<Set<int>> serverIds(
            String filter, {
            String? zone,
            bool nulls = false,
            int? projectId,
          }) async {
            final ids = <int>{};
            for (var page = 1; ; page++) {
              final query = TaskQuery(
                filter: filter,
                filterTimezone: zone,
                includeNulls: nulls,
                page: page,
                perPage: 50,
              );
              final result = await despiteWriteRaces(
                () => projectId == null
                    ? reads.tasks.list(query)
                    : reads.tasks.listInProject(projectId, query),
              );
              ids.addAll(result.items.map((task) => task.id));
              if (!result.hasMore) return ids;
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
            writes = createWriteClient(dio: authenticated, connection: only);
            db = testDatabase();
            engine = DefaultSyncEngine(
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
            taskRepository = LocalTaskRepository(
              db,
              engine,
              sender,
              writes,
              read: reads,
              perPage: only.info.maxItemsPerPage,
            );
            addTearDown(taskRepository.dispose);
            projectRepository = LocalProjectRepository(db, engine, writes);
            addTearDown(projectRepository.dispose);
            savedFilters = LocalSavedFilterRepository(db, engine, writes);
            await engine.ensureInitialSync();
          });

          test(
            "every filter matches the server's tasks, in every zone",
            () async {
              final candidates = await db.tasksDao
                  .loadFilterRowsOfSavedFilters();
              expect(
                candidates.map((row) => row.task.id).toSet(),
                await serverIds(''),
              );
              var compared = 0;
              for (final (:filter, :nulls, :dated) in cases()) {
                for (final zone in dated ? _zones : const ['GMT']) {
                  final local = LocalFilter.compile(
                    ViewFilter(filter: filter, includeNulls: nulls),
                    location: locationForFilters([zone]),
                    now: DateTime.now(),
                  );
                  final server = await serverIds(
                    filter,
                    zone: zone,
                    nulls: nulls,
                  );
                  expect(
                    local?.matchingIds(candidates),
                    server,
                    reason: '$filter (nulls: $nulls) in $zone',
                  );
                  compared++;
                }
              }
              expect(compared, greaterThanOrEqualTo(40));
            },
          );

          test("a view's filter covers its project, archived included, and "
              'never its subprojects', () async {
            for (final (key, filter) in [
              ('main', 'priority >= 2 || labels = ${labels['urgent']}'),
              ('arch', 'labels = ${labels['urgent']}'),
              ('child', 'done = false'),
            ]) {
              final projectId = projects[key]!;
              final local = await LocalFilters(db, now: DateTime.now)
                  .matchingInProject(
                    projectId,
                    ViewFilter(filter: filter),
                    timezoneSetting: 'GMT',
                  );
              expect(
                local,
                await serverIds(filter, zone: 'GMT', projectId: projectId),
                reason: '$filter in $key',
              );
            }
          });

          test('the server refuses what the engine refuses', () async {
            for (final filter in [
              'dueDate < now',
              'done = yes',
              'done = true &&',
              'labels = Urgent',
              'priority in 1,',
              'title !~ x',
            ]) {
              final local = LocalFilter.compile(
                ViewFilter(filter: filter),
                location: locationForFilters(['GMT']),
                now: DateTime.now(),
              );
              expect(local, isNull, reason: filter);
              await expectLater(
                serverIds(filter),
                throwsA(isA<DomainError>()),
                reason: filter,
              );
            }
          });

          test('more than 10000 business days across a filter are refused '
              'by the engine and, from 2.8.0, by the server', () async {
            for (final (filter, refused) in [
              ('due_date < now+10000b', false),
              ('due_date < now+10001b', true),
              ('due_date < now+6000b || due_date > now-4001b', true),
            ]) {
              final local = LocalFilter.compile(
                ViewFilter(filter: filter),
                location: locationForFilters(['GMT']),
                now: DateTime.now(),
              );
              expect(local == null, refused, reason: filter);
              if (!refused) {
                expect(
                  local!.matchingIds(
                    await db.tasksDao.loadFilterRowsOfSavedFilters(),
                  ),
                  await serverIds(filter),
                  reason: filter,
                );
              } else if (connection.info.version!.isAtLeast(2, 8)) {
                await expectLater(
                  serverIds(filter),
                  throwsA(
                    isA<DomainError>().having((f) => f.code, 'code', 4019),
                  ),
                  reason: filter,
                );
              }
            }
          });

          test("a saved filter made here lists the server's open tasks, in the "
              "user's zone, at once and after a sync; edits, the favourite and "
              'the delete round-trip', () async {
            final urgent = labels['urgent'];
            final pseudoId = await savedFilters.create(
              SavedFilterDraft(
                title: 'Urgent ${apiVersion.pathSegment}',
                description: 'Made in the app',
                filter: ViewFilter(filter: 'labels = $urgent'),
              ),
            );
            final filterId = SavedFilter.idOfPseudoProject(pseudoId)!;

            Future<void> expectServerList() async {
              final list = await taskRepository
                  .watchSavedFilterTasks(pseudoId)
                  .first;
              expect(list.evaluation, FilterEvaluation.local);
              final server = <int>[];
              for (var page = 1; ; page++) {
                final result = await reads.tasks.listInProject(
                  pseudoId,
                  TaskQuery(
                    filter: 'done = false',
                    sort: TaskQuery.dueDateSort,
                    page: page,
                    perPage: 50,
                  ),
                );
                server.addAll(result.items.map((task) => task.id));
                if (!result.hasMore) break;
              }
              expect([for (final task in list.tasks) task.id], server);
            }

            await expectServerList();
            await engine.refresh();
            await expectServerList();

            await savedFilters.update(
              pseudoId,
              const SavedFilterDraft(
                title: 'Today in Berlin',
                filter: ViewFilter(
                  filter: 'due_date >= 2026-10-20 && due_date < 2026-10-21',
                ),
              ),
            );
            await expectServerList();
            await savedFilters.setFavorite(pseudoId, favorite: true);

            final read = await writes.savedFilters.read(filterId);
            expect(read.title, 'Today in Berlin');
            expect(read.description, '');
            expect(read.isFavorite, isTrue);
            await engine.refresh();
            final stored = (await projectRepository.watchSavedFilters().first)
                .singleWhere((filter) => filter.projectId == pseudoId);
            expect(stored.title, 'Today in Berlin');
            expect(stored.isFavorite, isTrue);
            expect(stored.definition?.filter, read.filter);
            await expectServerList();

            await savedFilters.delete(pseudoId);
            await expectLater(
              writes.savedFilters.read(filterId),
              throwsA(isA<NotFound>()),
            );
            await engine.refresh();
            expect(
              (await projectRepository.watchSavedFilters().first).map(
                (filter) => filter.projectId,
              ),
              isNot(contains(pseudoId)),
            );
          });

          test(
            "the user's My Open Tasks on the Overview is evaluated here like "
            'the server',
            () async {
              final overview = await taskRepository.watchOverviewTasks().first;

              expect(overview.filter?.projectId, myOpenTasks);
              expect(overview.filterEvaluation, FilterEvaluation.local);
              final server = await reads.tasks.listInProject(
                myOpenTasks,
                const TaskQuery(
                  filter: 'done = false',
                  sort: TaskQuery.dueDateSort,
                  perPage: 50,
                ),
              );
              expect(
                [for (final task in overview.tasks) task.id],
                [for (final task in server.items) task.id],
              );
              expect(overview.tasks, isNotEmpty);
            },
          );
        });
      }
    },
  );
}
