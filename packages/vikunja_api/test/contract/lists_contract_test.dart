@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// One project, created in the order A (open), B (done, assigned), C (open,
// assigned, due in two days), D (open), E (open, assigned, due tomorrow),
// F (open, assigned, no due date). Every new task goes on top of each view
// (lower positions), then A is moved to the very top through v2 and D to
// the bottom through v1. The default saved filter "My Open Tasks" of a new
// user is `done = false && assignees = <the user>`.
typedef _Seed = ({
  int projectId,
  int listViewId,
  int a,
  int b,
  int c,
  int d,
  int e,
  int f,
});

typedef _Reads = ({
  AvatarImage avatar,
  AvatarImage unknownAvatar,
  Page<Task> inListView,
  Page<Task> inProject,
  Project savedFilter,
  Page<Task> inSavedFilter,
});

const _topPosition = 100.0;
const _bottomPosition = 1e9;

void main() {
  group('lists on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late _Seed seed;
        late Map<ApiVersion, _Reads> reads;

        Uri at(ApiVersion apiVersion, String path) {
          final base = connection.apiBaseUri(apiVersion);
          return base.replace(path: '${base.path}$path');
        }

        Options authorized({String? contentType}) => Options(
          headers: {'Authorization': 'Bearer ${user.jwt}'},
          contentType: contentType,
        );

        Future<Map<String, Object?>> send(
          String method,
          ApiVersion apiVersion,
          String path, [
          Map<String, Object?>? body,
          String? contentType,
        ]) async {
          try {
            final response = await despiteWriteRaces(
              () => dio.requestUri<Map<String, Object?>>(
                at(apiVersion, path),
                data: body,
                options: authorized(contentType: contentType)
                    .copyWith(method: method),
              ),
            );
            return response.data ?? const {};
          } on DioException catch (error) {
            throw StateError(
              '$method $path failed with ${error.response?.statusCode}: '
              '${error.response?.data}',
            );
          }
        }

        Future<int> createTask(int projectId, Map<String, Object?> body) async {
          final created = await send(
            'POST',
            ApiVersion.v2,
            '/projects/$projectId/tasks',
            body,
          );
          return created['id']! as int;
        }

        Future<void> assign(int taskId) => send(
          'POST',
          ApiVersion.v2,
          '/tasks/$taskId/assignees',
          {'user_id': user.id},
        );

        VikunjaReadClient readClient(ApiVersion apiVersion) {
          final only = onlyVersion(connection, apiVersion);
          return createReadClient(
            dio: createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            ),
            connection: only,
          );
        }

        Future<UserSettings> settingsThrough(ApiVersion apiVersion) async {
          final only = onlyVersion(connection, apiVersion);
          final api = AccountApi(
            createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            ),
            only,
          );
          return (await api.currentUserWithSettings()).settings;
        }

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);

          final project = await send('POST', ApiVersion.v2, '/projects', {
            'title': 'Lists contract',
          });
          final projectId = project['id']! as int;
          final views = await readClient(ApiVersion.v2).projects
              .read(projectId)
              .then((project) => project.views);
          final listViewId = views
              .firstWhere((view) => view.kind == ProjectViewKind.list)
              .id;
          final now = DateTime.now().toUtc();
          final a = await createTask(projectId, {'title': 'A'});
          final b = await createTask(projectId, {'title': 'B', 'done': true});
          final c = await createTask(projectId, {
            'title': 'C',
            'due_date': now.add(const Duration(days: 2)).toIso8601String(),
          });
          final d = await createTask(projectId, {'title': 'D'});
          final e = await createTask(projectId, {
            'title': 'E',
            'due_date': now.add(const Duration(days: 1)).toIso8601String(),
          });
          final f = await createTask(projectId, {'title': 'F'});
          for (final taskId in [b, c, e, f]) {
            await assign(taskId);
          }
          await send('PUT', ApiVersion.v2, '/tasks/$a/position', {
            'project_view_id': listViewId,
            'position': _topPosition,
          });
          await send('POST', ApiVersion.v1, '/tasks/$d/position', {
            'project_view_id': listViewId,
            'position': _bottomPosition,
          });
          seed = (
            projectId: projectId,
            listViewId: listViewId,
            a: a,
            b: b,
            c: c,
            d: d,
            e: e,
            f: f,
          );

          final perPage = connection.info.maxItemsPerPage;
          reads = {};
          for (final apiVersion in connection.apiVersions) {
            final client = readClient(apiVersion);
            final savedFilter = (await client.projects.listAll()).singleWhere(
              (project) => project.savedFilterId != null,
            );
            reads[apiVersion] = (
              avatar: await client.avatars.fetch(user.username, size: 50),
              unknownAvatar: await client.avatars.fetch(
                'nobody${user.username}',
                size: 50,
              ),
              inListView: await client.tasks.listInView(
                projectId,
                listViewId,
                TaskQuery(
                  sort: const [TaskSort(TaskSortField.position)],
                  perPage: perPage,
                ),
              ),
              inProject: await client.tasks.listInProject(
                projectId,
                TaskQuery(sort: TaskQuery.defaultSort, perPage: perPage),
              ),
              savedFilter: savedFilter,
              inSavedFilter: await client.tasks.listInProject(
                savedFilter.id,
                TaskQuery(
                  filter: 'done = false',
                  sort: TaskQuery.dueDateSort,
                  perPage: perPage,
                ),
              ),
            );
          }
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            test("a new user's avatar is the initials provider's SVG", () {
              final avatar = reads[apiVersion]!.avatar;

              expect(avatar.contentType, 'image/svg+xml');
              expect(avatar.isSvg, isTrue);
              expect(utf8.decode(avatar.bytes), contains('<svg'));
            });

            test('an unknown username gets the placeholder, not an error', () {
              final avatar = reads[apiVersion]!.unknownAvatar;

              expect(avatar.isSvg, isTrue);
              expect(avatar.bytes, isNotEmpty);
            });

            test('the List view by position: its positions in order, no done '
                'task', () {
              final page = reads[apiVersion]!.inListView;
              final positions = page.items.map((task) => task.position);

              expect(page.items.map((task) => task.id), [
                seed.a,
                seed.f,
                seed.e,
                seed.c,
                seed.d,
              ]);
              expect(page.items.first.position, _topPosition);
              expect(page.items.last.position, _bottomPosition);
              expect(positions, everyElement(greaterThan(0)));
              expect(positions.toList(), [...positions]..sort());
              expect(page.items.map((task) => task.done), everyElement(false));
              expect(page.hasMore, isFalse);
            });

            test('positions exist only through a view', () {
              final page = reads[apiVersion]!.inProject;

              expect(page.items.map((task) => task.id), contains(seed.b));
              expect(page.items.map((task) => task.position), everyElement(0));
            });

            test('the default saved filter is a pseudo project with views '
                'without a filter', () {
              final savedFilter = reads[apiVersion]!.savedFilter;

              expect(savedFilter.title, 'My Open Tasks');
              expect(savedFilter.id, lessThanOrEqualTo(-2));
              expect(savedFilter.id, -savedFilter.savedFilterId! - 1);
              final list = savedFilter.views.firstWhere(
                (view) => view.kind == ProjectViewKind.list,
              );
              expect(list.id, greaterThan(0));
              expect(list.filter, isNull);
            });

            test("the saved filter's open tasks, as the web's Overview asks "
                'for them: due date ascending, undated last', () {
              final page = reads[apiVersion]!.inSavedFilter;

              expect(page.items.map((task) => task.id), [
                seed.e,
                seed.c,
                seed.f,
              ]);
              expect(page.hasMore, isFalse);
            });
          });
        }

        test('v1 and v2 agree', () {
          final v1 = reads[ApiVersion.v1]!;
          final v2 = reads[ApiVersion.v2]!;

          expect(v1.avatar.bytes, v2.avatar.bytes);
          expect(v1.inListView.items, v2.inListView.items);
          expect(v1.inSavedFilter.items, v2.inSavedFilter.items);
          expect(v1.savedFilter, v2.savedFilter);
          expect(v1.savedFilter.views, v2.savedFilter.views);
        });

        test(
          'the two new settings, written the way the web writes them',
          () async {
            final savedFilterId = reads[ApiVersion.v2]!.savedFilter.id;

            // The web's v2 settings form: a merge-patch of frontend_settings.
            await send('PATCH', ApiVersion.v2, '/user/settings/general', {
              'frontend_settings': {
                'filter_id_used_on_overview': savedFilterId,
                'minimum_priority': 4,
              },
            }, 'application/merge-patch+json');
            for (final apiVersion in ApiVersion.values) {
              final settings = await settingsThrough(apiVersion);
              expect(
                settings.filterIdUsedOnOverview,
                savedFilterId,
                reason: apiVersion.pathSegment,
              );
              expect(settings.minimumPriority, 4);
            }

            // v1 only replaces the whole object.
            final current = await send('GET', ApiVersion.v1, '/user');
            final settings = current['settings']! as Map<String, Object?>;
            await send('POST', ApiVersion.v1, '/user/settings/general', {
              ...settings,
              'frontend_settings': {
                ...?settings['frontend_settings'] as Map<String, Object?>?,
                'filter_id_used_on_overview': null,
                'minimum_priority': 1,
              },
            });
            for (final apiVersion in ApiVersion.values) {
              final settings = await settingsThrough(apiVersion);
              expect(
                settings.filterIdUsedOnOverview,
                isNull,
                reason: apiVersion.pathSegment,
              );
              expect(settings.minimumPriority, 1);
              expect(settings.effectiveMinimumPriority, 1);
            }
          },
        );
      });
    }
  });
}
