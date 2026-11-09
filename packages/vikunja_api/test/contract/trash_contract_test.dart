@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// One throwaway user moves its own tasks and projects to the trash through
// the write ports, seeded by raw v2 calls, and takes them back or deletes
// them for good through the trash port. The tests run in order and build
// on each other. The trash exists from 2.8.0 on.
const _pace = Duration(milliseconds: 500);

Matcher _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _recently(DateTime since) => predicate<DateTime>(
  (at) => at.isUtc && !at.isBefore(since.subtract(const Duration(minutes: 1))),
  'shortly after $since',
);

void main() {
  group('the trash on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late TrashPort trash;
        late TasksWritePort tasks;
        late ProjectsWritePort projects;
        late VikunjaReadClient reads;
        late int gardenId;
        late int labelId;
        late int plantsId;
        late int shedId;
        late int toolsId;
        late int screwsId;

        Future<Map<String, Object?>> post(
          String path,
          Map<String, Object?> body,
        ) async {
          final v2 = connection.apiBaseUri(ApiVersion.v2);
          try {
            final response = await despiteWriteRaces(
              () => dio.postUri<Map<String, Object?>>(
                v2.replace(path: '${v2.path}$path'),
                data: body,
                options: Options(
                  headers: {'Authorization': 'Bearer ${user.jwt}'},
                ),
              ),
            );
            await Future<void>.delayed(_pace);
            return response.data!;
          } on DioException catch (error) {
            throw StateError(
              'POST $path failed with ${error.response?.statusCode}: '
              '${error.response?.data}',
            );
          }
        }

        Future<int> create(String path, Map<String, Object?> body) async =>
            (await post(path, body))['id']! as int;

        Future<int> project(String title, {int? parent}) =>
            create('/projects', {'title': title, 'parent_project_id': ?parent});

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        Future<List<int>> trashedTaskIds() async => [
          for (final trashed in await patiently(trash.tasks)) trashed.task.id,
        ];

        bool before280() {
          if (connection.info.version!.isAtLeast(2, 8)) return false;
          markTestSkipped('servers before 2.8.0 have no trash');
          return true;
        }

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: connection,
            tokens: StaticJwt(user.jwt),
          );
          trash = createTrashPort(dio: authenticated, connection: connection);
          final writes = createWriteClient(
            dio: authenticated,
            connection: connection,
          );
          tasks = RetryingTasksWrites(writes.tasks);
          projects = RetryingProjectsWrites(writes.projects);
          reads = createReadClient(dio: authenticated, connection: connection);
          gardenId = await project('Trash contract garden');
          labelId = await create('/labels', {
            'title': 'kept',
            'hex_color': '1973ff',
          });
          plantsId = await create('/projects/$gardenId/tasks', {
            'title': 'Water the plants',
          });
          await post('/tasks/$plantsId/labels', {'label_id': labelId});
          await post('/tasks/$plantsId/assignees', {'user_id': user.id});
        });

        tearDownAll(() => dio.close(force: true));

        void expectLabelAndAssignee(Task task) {
          expect(task.labels.map((l) => l.id), [labelId]);
          expect(task.assignees.map((u) => u.id), [user.id]);
        }

        test('a deleted task is listed with who deleted it, and '
            'counted', () async {
          if (before280()) return;
          final countBefore = await patiently(trash.taskCount);
          final deletedFrom = DateTime.now().toUtc();

          await paced(() => tasks.delete(plantsId));

          final listed = (await patiently(trash.tasks))
              .singleWhere((trashed) => trashed.task.id == plantsId);
          expect(listed.task.title, 'Water the plants');
          expectLabelAndAssignee(listed.task);
          expect(listed.deletedAt, _recently(deletedFrom));
          expect(listed.deletedBy?.id, user.id);
          expect(listed.deletedBy?.username, user.username);
          expect(listed.deletedBy?.email, isNull);
          expect(listed.canDeletePermanently, isTrue);
          expect(
            await patiently(trash.taskCount),
            TrashCount(
              total: countBefore.total + 1,
              byOthers: countBefore.byOthers,
            ),
          );
        });

        test('restored with its label and assignee; restoring it again '
            'reads it', () async {
          if (before280()) return;

          final restored = await paced(() => trash.restoreTask(plantsId));

          expect(restored.id, plantsId);
          expectLabelAndAssignee(restored);
          expectLabelAndAssignee(
            await patiently(() => reads.tasks.read(plantsId)),
          );
          expect(await trashedTaskIds(), isNot(contains(plantsId)));

          final again = await paced(() => trash.restoreTask(plantsId));
          expect(again.id, plantsId);
          expectLabelAndAssignee(again);
        });

        test('deleted again and for good: a read and a second delete find '
            'nothing', () async {
          if (before280()) return;
          await paced(() => tasks.delete(plantsId));

          await paced(() => trash.deleteTaskForever(plantsId));

          await expectLater(
            reads.tasks.read(plantsId),
            throwsA(_notFound(4002)),
          );
          await expectLater(
            trash.deleteTaskForever(plantsId),
            throwsA(_notFound(4002)),
          );
          expect(await trashedTaskIds(), isNot(contains(plantsId)));
        });

        test('a project goes to the trash with its child and '
            'grandchild', () async {
          if (before280()) return;
          shedId = await project('Trash contract shed');
          toolsId = await project('Tools', parent: shedId);
          screwsId = await project('Screws', parent: toolsId);

          await paced(() => projects.delete(shedId));

          final listed = await patiently(trash.projects);
          expect(
            listed.map((trashed) => trashed.project.id),
            isNot(contains(toolsId)),
          );
          final shed = listed.singleWhere(
            (trashed) => trashed.project.id == shedId,
          );
          expect(shed.project.title, 'Trash contract shed');
          expect(shed.deletedBy?.id, user.id);
          expect(shed.subprojects, [
            TrashedSubproject(
              id: toolsId,
              title: 'Tools',
              parentProjectId: shedId,
              depth: 1,
            ),
            TrashedSubproject(
              id: screwsId,
              title: 'Screws',
              parentProjectId: toolsId,
              depth: 2,
            ),
          ]);
          await expectLater(
            reads.projects.read(screwsId),
            throwsA(_notFound(3018)),
          );
        });

        test('restored with its views and subprojects; restoring it again '
            'reads it', () async {
          if (before280()) return;

          final restored = await paced(() => trash.restoreProject(shedId));

          expect(restored.id, shedId);
          expect(restored.views, isNotEmpty);
          expect(restored.maxPermission, Permission.admin);
          expect(
            (await patiently(() => reads.projects.read(screwsId))).id,
            screwsId,
          );

          final again = await paced(() => trash.restoreProject(shedId));
          expect(again.id, shedId);
          expect(again.views, isNotEmpty);
        });

        test('a child deleted on its own cannot be restored while its parent '
            'is in the trash', () async {
          if (before280()) return;
          await paced(() => projects.delete(toolsId));
          await paced(() => projects.delete(shedId));

          await expectLater(
            trash.restoreProject(toolsId),
            throwsA(_domainError(412, 3019)),
          );

          final shed = (await patiently(trash.projects))
              .singleWhere((trashed) => trashed.project.id == shedId);
          expect(shed.subprojects.map((s) => (s.id, s.depth)), [
            (toolsId, 1),
            (screwsId, 2),
          ]);
          await paced(() => trash.restoreProject(shedId));
          expect(
            (await patiently(() => reads.projects.read(toolsId))).id,
            toolsId,
          );
        });

        test('a task in a project archived since cannot be restored', () async {
          if (before280()) return;
          final archiveId = await project('Trash contract archive');
          final storedId = await create('/projects/$archiveId/tasks', {
            'title': 'Store the pots',
          });
          await paced(() => tasks.delete(storedId));
          await paced(
            () => projects.update(
              archiveId,
              const ProjectChanges(isArchived: true),
            ),
          );

          await expectLater(
            trash.restoreTask(storedId),
            throwsA(_domainError(412, 3008)),
          );
          expect(await trashedTaskIds(), isNot(contains(storedId)));
        });

        test('emptying without what others moved there removes the '
            "user's own tasks", () async {
          if (before280()) return;
          final soilId = await create('/projects/$gardenId/tasks', {
            'title': 'Buy soil',
          });
          await paced(() => tasks.delete(soilId));
          expect(await trashedTaskIds(), contains(soilId));

          await paced(() => trash.emptyTasks(includeOthers: false));

          expect(await trashedTaskIds(), isNot(contains(soilId)));
          await expectLater(
            trash.restoreTask(soilId),
            throwsA(_notFound(4002)),
          );
        });
      });
    }
  });
}
