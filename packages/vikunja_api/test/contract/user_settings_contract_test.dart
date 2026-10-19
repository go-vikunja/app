@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

void main() {
  group('user settings on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late UserWithSettings before;
        late int otherProjectId;

        Uri v2(String path) {
          final base = connection.apiBaseUri(ApiVersion.v2);
          return base.replace(path: '${base.path}$path');
        }

        Options authorized() =>
            Options(headers: {'Authorization': 'Bearer ${user.jwt}'});

        AccountApi accountApi(ApiVersion apiVersion) {
          final only = onlyVersion(connection, apiVersion);
          return AccountApi(
            createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            ),
            only,
          );
        }

        // One throwaway user for both API versions: the read comes before
        // and after the web's way of saving its settings.
        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
          before = await accountApi(ApiVersion.v2).currentUserWithSettings();
          final project = await despiteWriteRaces(
            () => dio.postUri<Map<String, Object?>>(
              v2('/projects'),
              data: {'title': 'Settings contract'},
              options: authorized(),
            ),
          );
          otherProjectId = project.data!['id']! as int;
          final current = await dio.getUri<Map<String, Object?>>(
            v2('/user'),
            options: authorized(),
          );
          // PUT replaces every field, so the whole object goes back.
          final settings = {
            ...current.data!['settings']! as Map<String, Object?>,
            'default_project_id': otherProjectId,
            'week_start': 1,
            'timezone': 'Europe/Berlin',
            'frontend_settings': {
              'quick_add_magic_mode': 'todoist',
              'quick_add_default_reminders': [
                {'relative_period': -900, 'relative_to': 'due_date'},
                {'relative_period': 86400, 'relative_to': 'due_date'},
                {'relative_period': 'soon'},
              ],
              'play_sound_when_done': false,
              'comment_sort_order': 'desc',
            },
          };
          await despiteWriteRaces(
            () => dio.putUri<Object?>(
              v2('/user/settings/general'),
              data: settings,
              options: authorized(),
            ),
          );
        });

        tearDownAll(() => dio.close(force: true));

        test('a new user has the defaults and the Inbox as default '
            'project', () {
          expect(before.user.id, user.id);
          expect(before.user.username, user.username);
          expect(before.settings.defaultProjectId, isNotNull);
          expect(before.settings.quickAddMagicMode, QuickAddMagicMode.vikunja);
          expect(before.settings.quickAddDefaultReminders, isEmpty);
          expect(before.settings.weekStart, 0);
          expect(
            before.settings.commentSortOrder,
            CommentSortOrder.oldestFirst,
          );
        });

        for (final apiVersion in ApiVersion.values) {
          test('${apiVersion.pathSegment} reads what the web saved', () async {
            final (user: reader, :settings) = await accountApi(apiVersion)
                .currentUserWithSettings();

            expect(reader.id, user.id);
            expect(
              settings,
              UserSettings(
                defaultProjectId: otherProjectId,
                weekStart: 1,
                timezone: 'Europe/Berlin',
                language: before.settings.language,
                quickAddMagicMode: QuickAddMagicMode.todoist,
                quickAddDefaultReminders: const [
                  Duration(minutes: -15),
                  Duration(days: 1),
                ],
                commentSortOrder: CommentSortOrder.newestFirst,
              ),
            );
          });
        }
      });
    }
  });
}
