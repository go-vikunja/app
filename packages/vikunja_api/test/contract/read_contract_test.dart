@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Seeded through raw v2 calls: a project with a per-run identifier (they are
// unique server-wide, and the server outlives a run), a child, two labels
// and five tasks (due yesterday, in an hour with a reminder, in three days
// and a favourite, none and done, none with both labels, assigned to the
// user and the parent of the favourite).
typedef _Seed = ({
  String identifier,
  int projectId,
  int childId,
  int alphaId,
  int betaId,
  int pastId,
  int todayId,
  int futureId,
  int doneId,
  int labelledId,
  int userId,
  String username,
  DateTime todayDue,
});

typedef _Reads = ({
  List<Project> projects,
  Page<Project> firstProjectsPage,
  Project project,
  List<Label> labels,
  Page<Task> openInProject,
  Page<Task> allInProject,
  List<Page<Task>> allInProjectByTwo,
  Page<Task> openByDueDate,
  Task first,
  Task today,
  Task future,
  Task labelled,
});

Future<_Seed> _seed(Dio dio, ServerConnection connection, TestUser user) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await dio.postUri<Map<String, Object?>>(
        v2.replace(path: '${v2.path}$path'),
        data: body,
        options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
      );
      return response.data!;
    } on DioException catch (error) {
      // Error bodies carry no secrets; the failure is far easier to read
      // with the server's message.
      throw StateError(
        'POST $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }

  Future<int> create(String path, Map<String, Object?> body) async =>
      (await post(path, body))['id']! as int;

  final now = DateTime.now().toUtc();
  final todayDue = now.add(const Duration(hours: 1));
  final identifier =
      'CT${Random.secure().nextInt(1 << 16).toRadixString(16).toUpperCase()}';
  final projectId = await create('/projects', {
    'title': 'Contract',
    'identifier': identifier,
  });
  final childId = await create('/projects', {
    'title': 'Contract child',
    'parent_project_id': projectId,
  });
  final alphaId = await create('/labels', {
    'title': 'alpha',
    'hex_color': 'e8323c',
  });
  final betaId = await create('/labels', {
    'title': 'beta',
    'hex_color': '#4caf50',
  });
  final tasks = '/projects/$projectId/tasks';
  final pastId = await create(tasks, {
    'title': 'Due yesterday',
    'due_date': now.subtract(const Duration(days: 1)).toIso8601String(),
  });
  final todayId = await create(tasks, {
    'title': 'Due in an hour',
    'due_date': todayDue.toIso8601String(),
    'reminders': [
      {'relative_period': -600, 'relative_to': 'due_date'},
    ],
  });
  final futureId = await create(tasks, {
    'title': 'Due in three days',
    'due_date': now.add(const Duration(days: 3)).toIso8601String(),
    'is_favorite': true,
  });
  final doneId = await create(tasks, {'title': 'Done', 'done': true});
  final labelledId = await create(tasks, {'title': 'Labelled'});
  for (final labelId in [alphaId, betaId]) {
    await post('/tasks/$labelledId/labels', {'label_id': labelId});
  }
  await post('/tasks/$labelledId/relations', {
    'other_task_id': futureId,
    'relation_kind': 'subtask',
  });
  await post('/tasks/$labelledId/assignees', {'user_id': user.id});
  return (
    identifier: identifier,
    projectId: projectId,
    childId: childId,
    alphaId: alphaId,
    betaId: betaId,
    pastId: pastId,
    todayId: todayId,
    futureId: futureId,
    doneId: doneId,
    labelledId: labelledId,
    userId: user.id,
    username: user.username,
    todayDue: todayDue,
  );
}

Future<_Reads> _read(VikunjaReadClient client, _Seed seed) async => (
  projects: await client.projects.listAll(),
  firstProjectsPage: await client.projects.list(perPage: 2),
  project: await client.projects.read(seed.projectId),
  labels: await client.labels.listAll(),
  openInProject: await client.tasks.listInProject(
    seed.projectId,
    const TaskQuery(filter: 'done = false', sort: TaskQuery.defaultSort),
  ),
  allInProject: await client.tasks.listInProject(
    seed.projectId,
    const TaskQuery(sort: TaskQuery.defaultSort),
  ),
  allInProjectByTwo: [
    for (final page in [1, 2, 3])
      await client.tasks.listInProject(
        seed.projectId,
        TaskQuery(sort: TaskQuery.defaultSort, page: page, perPage: 2),
      ),
  ],
  openByDueDate: await client.tasks.list(
    const TaskQuery(filter: 'done = false', sort: TaskQuery.dueDateSort),
  ),
  first: await client.tasks.read(seed.pastId),
  today: await client.tasks.read(seed.todayId),
  future: await client.tasks.read(seed.futureId),
  labelled: await client.tasks.read(seed.labelledId),
);

void _expectSameViewFilters(List<ProjectView> a, List<ProjectView> b) {
  expect(a.map((v) => v.id), b.map((v) => v.id));
  for (var i = 0; i < a.length; i++) {
    final (x, y) = (a[i].filter, b[i].filter);
    expect(x == null, y == null, reason: 'view ${a[i].id}');
    if (x == null || y == null) continue;
    expect(x.filter, y.filter);
    expect(x.search, y.search);
    expect(x.sortBy, y.sortBy);
    expect(x.orderBy, y.orderBy);
    expect(x.includeNulls, y.includeNulls);
  }
}

void _expectSameRelations(Task a, Task b) {
  expect(a.relatedTasks.keys, b.relatedTasks.keys);
  for (final kind in a.relatedTasks.keys) {
    expect(a.relatedTasks[kind], b.relatedTasks[kind], reason: '$kind');
  }
}

void main() {
  group('reads on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late _Seed seed;
        late Map<ApiVersion, _Reads> reads;

        setUpAll(() async {
          dio = contractDio();
          final connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          final user = await registerAndLogin(dio, connection);
          seed = await _seed(dio, connection, user);
          reads = {};
          for (final apiVersion in connection.apiVersions) {
            final only = onlyVersion(connection, apiVersion);
            final client = createReadClient(
              dio: createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(user.jwt),
              ),
              connection: only,
            );
            reads[apiVersion] = await _read(client, seed);
          }
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            test('projects list has the tree and no duplicates', () {
              final projects = reads[apiVersion]!.projects;
              final byId = {for (final p in projects) p.id: p};

              expect(byId.length, projects.length);
              expect(byId[seed.projectId]?.title, 'Contract');
              expect(byId[seed.projectId]?.identifier, seed.identifier);
              expect(byId[seed.projectId]?.isTopLevel, isTrue);
              expect(byId[seed.childId]?.parentProjectId, seed.projectId);
              // One task is a favourite, so the Favorites pseudo project is
              // appended; the default saved filter is present.
              final favorites = projects.singleWhere(
                (p) => p.isFavoritesPseudo,
              );
              expect(favorites.isFavorite, isTrue);
              expect(
                projects.where((p) => p.savedFilterId != null),
                hasLength(1),
              );
              expect(projects.any((p) => p.isArchived), isFalse);
            });

            test('project pages carry the pseudo projects and paging', () {
              final page = reads[apiVersion]!.firstProjectsPage;

              expect(page.page, 1);
              expect(page.perPage, 2);
              expect(page.totalPages, greaterThanOrEqualTo(2));
              expect(page.hasMore, isTrue);
              expect(page.items.where((p) => !p.isPseudo), hasLength(2));
              expect(page.items.any((p) => p.isPseudo), isTrue);
              expect(
                page.total,
                apiVersion == ApiVersion.v2 ? isNotNull : isNull,
              );
            });

            test('project read has the four default views', () {
              final project = reads[apiVersion]!.project;

              expect(project.views.map((v) => v.kind), [
                ProjectViewKind.list,
                ProjectViewKind.gantt,
                ProjectViewKind.table,
                ProjectViewKind.kanban,
              ]);
              expect(
                project.views.map((v) => v.projectId),
                everyElement(seed.projectId),
              );
              expect(project.views.first.filter?.filter, 'done = false');
              expect(project.views.map((v) => v.filter == null), [
                false,
                true,
                true,
                true,
              ]);
              final kanban = project.views.last;
              expect(
                kanban.bucketConfigurationMode,
                BucketConfigurationMode.manual,
              );
              expect(kanban.defaultBucketId, greaterThan(0));
              expect(kanban.doneBucketId, greaterThan(0));
              expect(project.owner, isNotNull);
            });

            test('labels', () {
              final labels = reads[apiVersion]!.labels;
              final byId = {for (final l in labels) l.id: l};

              expect(byId[seed.alphaId]?.title, 'alpha');
              expect(byId[seed.alphaId]?.hexColor, 'e8323c');
              expect(byId[seed.betaId]?.title, 'beta');
              expect(byId[seed.betaId]?.hexColor, '4caf50');
            });

            test('tasks in the project with and without done', () {
              final (:openInProject, :allInProject) = (
                openInProject: reads[apiVersion]!.openInProject,
                allInProject: reads[apiVersion]!.allInProject,
              );

              expect(openInProject.items.map((t) => t.id), [
                seed.labelledId,
                seed.futureId,
                seed.todayId,
                seed.pastId,
              ]);
              expect(allInProject.items.map((t) => t.id), [
                seed.labelledId,
                seed.doneId,
                seed.futureId,
                seed.todayId,
                seed.pastId,
              ]);
              expect(allInProject.items[1].done, isTrue);
              expect(openInProject.hasMore, isFalse);
              expect(allInProject.items.map((t) => t.identifier), [
                for (final index in [5, 4, 3, 2, 1])
                  '${seed.identifier}-$index',
              ]);
            });

            test('tasks in the project two per page', () {
              final pages = reads[apiVersion]!.allInProjectByTwo;
              final all = reads[apiVersion]!.allInProject.items;

              expect(pages.map((p) => p.page), [1, 2, 3]);
              expect(pages.map((p) => p.perPage), everyElement(2));
              expect(pages.map((p) => p.totalPages), everyElement(3));
              expect(pages.map((p) => p.hasMore), [true, true, false]);
              expect(pages.map((p) => p.items.length), [2, 2, 1]);
              expect(
                pages.expand((p) => p.items).map((t) => t.id),
                all.map((t) => t.id),
              );
              expect(
                pages.map((p) => p.total),
                everyElement(apiVersion == ApiVersion.v2 ? all.length : isNull),
              );
            });

            test('all open tasks by due date, nulls last', () {
              final tasks = reads[apiVersion]!.openByDueDate.items;
              final ids = tasks.map((t) => t.id).toList();

              expect(
                ids.where(
                  (id) => [
                    seed.pastId,
                    seed.todayId,
                    seed.futureId,
                    seed.labelledId,
                  ].contains(id),
                ),
                [seed.pastId, seed.todayId, seed.futureId, seed.labelledId],
              );
              expect(ids, isNot(contains(seed.doneId)));
              final dated = tasks.where((t) => t.dueDate != null).toList();
              expect(dated, hasLength(3));
              expect(
                tasks.sublist(dated.length).map((t) => t.dueDate),
                everyElement(isNull),
              );
              expect(dated.map((t) => t.dueDate!.isUtc), everyElement(isTrue));
            });

            test('task reads', () {
              final (:first, :today, :future, :labelled) = (
                first: reads[apiVersion]!.first,
                today: reads[apiVersion]!.today,
                future: reads[apiVersion]!.future,
                labelled: reads[apiVersion]!.labelled,
              );

              expect(first.identifier, '${seed.identifier}-1');
              expect(first.displayIdentifier, '${seed.identifier}-1');
              expect(first.projectId, seed.projectId);
              expect(first.isOverdue(DateTime.now().toUtc()), isTrue);
              expect(first.createdBy, isNotNull);

              expect(labelled.labels.map((l) => l.id), [
                seed.alphaId,
                seed.betaId,
              ]);
              expect(labelled.dueDate, isNull);
              expect(labelled.isFavorite, isFalse);
              expect(future.isFavorite, isTrue);

              final assignee = labelled.assignees.single;
              expect(assignee.id, seed.userId);
              expect(assignee.username, seed.username);
              expect(future.assignees, isEmpty);

              final subtask = labelled.subtasks.single;
              expect(subtask.id, seed.futureId);
              expect(subtask.title, 'Due in three days');
              expect(subtask.done, isFalse);
              expect(subtask.relatedTasks, isEmpty);
              expect(labelled.parentTasks, isEmpty);
              expect(future.parentTasks.single.id, seed.labelledId);
              expect(future.subtasks, isEmpty);
              expect(first.relatedTasks, isEmpty);

              final reminder = today.reminders.single;
              expect(reminder.relativeTo, ReminderRelativeTo.dueDate);
              expect(reminder.relativePeriod, const Duration(minutes: -10));
              expect(
                reminder.reminder,
                today.dueDate!.subtract(const Duration(minutes: 10)),
              );
              expect(
                today.dueDate!.difference(seed.todayDue).abs(),
                lessThan(const Duration(seconds: 1)),
              );
            });
          });
        }

        test('v1 and v2 agree except for Page.total', () {
          final v1 = reads[ApiVersion.v1]!;
          final v2 = reads[ApiVersion.v2]!;

          expect(v1.projects, v2.projects);
          expect(
            v1.projects.map((p) => p.isFavorite),
            v2.projects.map((p) => p.isFavorite),
          );
          expect(v1.firstProjectsPage.items, v2.firstProjectsPage.items);
          expect(
            v1.firstProjectsPage.totalPages,
            v2.firstProjectsPage.totalPages,
          );
          expect(v1.firstProjectsPage.total, isNull);
          expect(v2.firstProjectsPage.total, isNotNull);
          expect(v1.project, v2.project);
          expect(v1.project.views, v2.project.views);
          _expectSameViewFilters(v1.project.views, v2.project.views);
          expect(v1.labels, v2.labels);
          for (final (a, b) in [
            (v1.openInProject, v2.openInProject),
            (v1.allInProject, v2.allInProject),
            (v1.openByDueDate, v2.openByDueDate),
          ]) {
            expect(a.items, b.items);
            expect(a.totalPages, b.totalPages);
            expect(a.perPage, b.perPage);
            expect(a.total, isNull);
            expect(b.total, b.items.length);
            for (var i = 0; i < a.items.length; i++) {
              expect(a.items[i].labels, b.items[i].labels);
              expect(a.items[i].reminders, b.items[i].reminders);
              expect(a.items[i].assignees, b.items[i].assignees);
              _expectSameRelations(a.items[i], b.items[i]);
            }
          }
          for (var i = 0; i < v1.allInProjectByTwo.length; i++) {
            final (a, b) = (v1.allInProjectByTwo[i], v2.allInProjectByTwo[i]);
            expect(a.items, b.items);
            expect(a.totalPages, b.totalPages);
            expect(a.perPage, b.perPage);
          }
          expect(v1.first, v2.first);
          expect(v1.today, v2.today);
          expect(v1.future, v2.future);
          expect(v1.labelled, v2.labelled);
          expect(v1.labelled.labels, v2.labelled.labels);
          expect(v1.labelled.assignees, v2.labelled.assignees);
          _expectSameRelations(v1.labelled, v2.labelled);
          _expectSameRelations(v1.future, v2.future);
          expect(v1.today.reminders, v2.today.reminders);
        });
      });
    }
  });
}
