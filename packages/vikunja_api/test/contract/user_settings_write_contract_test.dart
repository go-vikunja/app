@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/user_settings_codec.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// One throwaway user whose frontend settings carry keys other clients
// wrote. The port writes every field and clears the nullable ones on each
// of its three paths: the v2 merge-patch (2.7.0), the v2 full PUT (as on
// 2.4 to 2.6) and the v1 full POST (as on 2.3); the server's raw settings
// change only where the port changed them. Refusals leave them as they
// were. The avatar provider is read and set, and an image uploaded, on both
// versions.
const _pace = Duration(milliseconds: 500);
const _writtenFrontendKeys = {
  'quick_add_magic_mode',
  'quick_add_default_reminders',
  'filter_id_used_on_overview',
  'minimum_priority',
  'comment_sort_order',
  'date_display',
  'time_format',
  'color_schema',
  'default_view',
};
const Map<String, Object?> _foreignKeys = {
  'play_sound_when_done': false,
  'sidebar_width': 280,
  'rurana_unknown_key': {
    'nested': [1, 2],
  },
};

final List<int> _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

typedef _Path = ({String name, ServerConnection connection});

void main() {
  group('user settings writes on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late int writableProjectId;
        late int archivedProjectId;
        late int savedFilterPseudoId;

        Dio authenticated(ServerConnection over) => createAuthenticatedDio(
          base: dio,
          connection: over,
          tokens: StaticJwt(user.jwt),
        );

        UserSettingsWritePort portOver(ServerConnection over) =>
            createUserSettingsWritePort(
              dio: authenticated(over),
              connection: over,
            );

        Uri v2(String path) {
          final base = connection.apiBaseUri(ApiVersion.v2);
          return base.replace(path: '${base.path}$path');
        }

        Options authorized({String? contentType}) => Options(
          headers: {'Authorization': 'Bearer ${user.jwt}'},
          contentType: contentType,
        );

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        Future<Map<String, Object?>> rawSettings() async {
          final response = await patiently(
            () => dio.getUri<Map<String, Object?>>(
              v2('/user'),
              options: authorized(),
            ),
          );
          return response.data!['settings']! as Map<String, Object?>;
        }

        // The 2.6 line: v2 without the merge-patch.
        ServerConnection withoutMergePatch() {
          final info = ServerInfo(
            version: const ServerVersion(2, 6, 0),
            maxFileSizeBytes: connection.info.maxFileSizeBytes,
          );
          return ServerConnection(
            rootUri: connection.rootUri,
            apiVersions: connection.apiVersions,
            info: info,
            capabilities: ServerCapabilities.derive(
              info: info,
              apiVersions: connection.apiVersions,
            ),
          );
        }

        List<_Path> paths() => [
          (name: 'v2 merge-patch', connection: connection),
          (name: 'v2 full PUT', connection: withoutMergePatch()),
          (
            name: 'v1 full POST',
            connection: onlyVersion(connection, ApiVersion.v1),
          ),
        ];

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
          expect(
            connection.capabilities.has(Capability.userSettingsMergePatch),
            isTrue,
          );
          final writes = createWriteClient(
            dio: authenticated(connection),
            connection: connection,
          ).projects;
          writableProjectId = (await paced(
            () => writes.create(const NewProject(title: 'Default target')),
          )).id;
          final archived = await paced(
            () => writes.create(const NewProject(title: 'Archived default')),
          );
          await paced(
            () => writes.update(
              archived.id,
              const ProjectChanges(isArchived: true),
            ),
          );
          archivedProjectId = archived.id;
          final projects = await patiently(
            () => createReadClient(
              dio: authenticated(connection),
              connection: connection,
            ).projects.listAll(),
          );
          savedFilterPseudoId =
              projects
                  .where((project) => project.id < Project.favoritesId)
                  .firstOrNull
                  ?.id ??
              -2;
          await paced(
            () => dio.patchUri<Object?>(
              v2('/user/settings/general'),
              data: {'frontend_settings': _foreignKeys},
              options: authorized(contentType: 'application/merge-patch+json'),
            ),
          );
        });

        tearDownAll(() => dio.close(force: true));

        for (final (index, pathName) in [
          'v2 merge-patch',
          'v2 full PUT',
          'v1 full POST',
        ].indexed) {
          test('$pathName: every field round-trips and only the changed raw '
              'settings change', () async {
            final path = paths()[index];
            final port = portOver(path.connection);
            final before = await rawSettings();
            final changes = UserSettingsChanges(
              name: 'Dora $index',
              emailRemindersEnabled: index.isEven,
              discoverableByName: true,
              discoverableByEmail: index.isOdd,
              overdueTasksRemindersEnabled: index.isOdd,
              overdueTasksRemindersTime: ClockTime(7 + index, 5 * index),
              defaultProjectId: SettingChange.set(writableProjectId),
              weekStart: index + 1,
              timezone: [
                'Europe/Berlin',
                'America/New_York',
                'Asia/Tokyo',
              ][index],
              language: ['de-DE', 'fr-FR', 'ja-JP'][index],
              quickAddMagicMode: [
                QuickAddMagicMode.todoist,
                QuickAddMagicMode.disabled,
                QuickAddMagicMode.vikunja,
              ][index],
              quickAddDefaultReminders: [Duration(minutes: -15 * (index + 1))],
              filterIdUsedOnOverview: SettingChange.set(savedFilterPseudoId),
              minimumPriority: index + 3,
              commentSortOrder: index.isEven
                  ? CommentSortOrder.newestFirst
                  : CommentSortOrder.oldestFirst,
              dateDisplay: SettingChange.set(DateDisplay.values[index + 1]),
              timeFormat: SettingChange.set(
                index.isEven
                    ? TimeFormat.twelveHour
                    : TimeFormat.twentyFourHour,
              ),
              colorSchema: ColorSchema.values[index],
              defaultViewKind: SettingChange.set(ProjectViewKind.values[index]),
            );

            final result = await paced(() => port.update(changes));

            final reread = await patiently(
              () => AccountApi(
                authenticated(path.connection),
                path.connection,
              ).currentUserWithProfile(),
            );
            expect(result.settings, reread.settings);
            expect(result.profile, reread.profile);
            expect(result.profile.name, 'Dora $index');
            expect(result.settings, changes.applyTo(parseUserSettings(before)));
            final after = await rawSettings();
            expect(after.keys, unorderedEquals(before.keys));
            expect(
              after['extra_settings_links'],
              before['extra_settings_links'],
            );
            final frontend =
                after['frontend_settings']! as Map<String, Object?>;
            for (final MapEntry(:key, :value) in _foreignKeys.entries) {
              expect(frontend[key], value, reason: key);
            }
            for (final MapEntry(:key, :value)
                in (before['frontend_settings']! as Map<String, Object?>)
                    .entries) {
              if (!_writtenFrontendKeys.contains(key)) {
                expect(frontend[key], value, reason: key);
              }
            }
            expect(frontend['quick_add_default_reminders'], [
              {
                'relative_period': -900 * (index + 1),
                'relative_to': 'due_date',
              },
            ]);
          });

          test('$pathName: clearing removes the frontend keys and the '
              'default project; the rest stays', () async {
            final path = paths()[index];
            final port = portOver(path.connection);
            final before = await rawSettings();

            final result = await paced(
              () => port.update(
                const UserSettingsChanges(
                  defaultProjectId: SettingChange.clear(),
                  filterIdUsedOnOverview: SettingChange.clear(),
                  dateDisplay: SettingChange.clear(),
                  timeFormat: SettingChange.clear(),
                  defaultViewKind: SettingChange.clear(),
                ),
              ),
            );

            expect(result.settings.defaultProjectId, isNull);
            expect(result.settings.filterIdUsedOnOverview, isNull);
            expect(result.settings.dateDisplay, isNull);
            expect(result.settings.timeFormat, isNull);
            expect(result.settings.defaultViewKind, isNull);
            final after = await rawSettings();
            expect(after['default_project_id'], 0);
            final frontend =
                after['frontend_settings']! as Map<String, Object?>;
            final kept =
                {...before['frontend_settings']! as Map<String, Object?>}
                  ..remove('filter_id_used_on_overview')
                  ..remove('date_display')
                  ..remove('time_format')
                  ..remove('default_view');
            expect(frontend, kept);
            expect(
              {...after}
                ..remove('default_project_id')
                ..remove('frontend_settings'),
              {...before}
                ..remove('default_project_id')
                ..remove('frontend_settings'),
            );
          });

          test('$pathName: refusals carry the server codes and change '
              'nothing', () async {
            final port = portOver(paths()[index].connection);
            final before = await rawSettings();

            await expectLater(
              despiteWriteRaces(
                () => port.update(
                  const UserSettingsChanges(timezone: 'Mars/Phobos'),
                ),
              ),
              throwsA(
                isA<DomainError>()
                    .having((f) => f.code, 'code', 1025)
                    .having((f) => f.statusCode, 'status', 400),
              ),
            );
            await Future<void>.delayed(_pace);
            await expectLater(
              despiteWriteRaces(
                () => port.update(
                  UserSettingsChanges(
                    name: 'Refused',
                    defaultProjectId: SettingChange.set(archivedProjectId),
                  ),
                ),
              ),
              throwsA(isA<DomainError>().having((f) => f.code, 'code', 3017)),
            );
            await Future<void>.delayed(_pace);
            await expectLater(
              despiteWriteRaces(
                () => port.update(const UserSettingsChanges(weekStart: 7)),
              ),
              throwsA(
                isA<ValidationFailed>().having(
                  (f) => f.fieldErrors.keys,
                  'fields',
                  ['week_start'],
                ),
              ),
            );
            await Future<void>.delayed(_pace);

            expect(await rawSettings(), before);
          });
        }

        test('an empty timezone stores the server default', () async {
          final result = await paced(
            () =>
                portOver(connection)
                    .update(const UserSettingsChanges(timezone: '')),
          );

          expect(result.settings.timezone, isNotEmpty);
        });

        for (final apiVersion in ApiVersion.values) {
          test(
            '${apiVersion.pathSegment}: the avatar provider is read and '
            'set; an upload switches it to upload and bumps the user',
            () async {
              final over = onlyVersion(connection, apiVersion);
              final port = portOver(over);
              final avatars = createReadClient(
                dio: authenticated(over),
                connection: over,
              ).avatars;
              final account = AccountApi(authenticated(over), over);

              final marble = apiVersion == ApiVersion.v2
                  ? AvatarProvider.marble
                  : AvatarProvider.defaultAvatar;
              await paced(() => port.setAvatarProvider(marble));
              expect(await patiently(port.avatarProvider), marble);
              expect(
                (await patiently(() => avatars.fetch(user.username, size: 64)))
                    .isSvg,
                isTrue,
              );
              final beforeUpload = await patiently(
                account.currentUserWithProfile,
              );

              // `updated` has a resolution of one second.
              await Future<void>.delayed(const Duration(milliseconds: 1100));
              await paced(
                () => port.uploadAvatar(
                  fileName: 'avatar.png',
                  bytes: Stream.value(_pixel),
                  length: _pixel.length,
                ),
              );

              expect(
                await patiently(port.avatarProvider),
                AvatarProvider.upload,
              );
              final image = await patiently(
                () => avatars.fetch(user.username, size: 64),
              );
              expect(image.contentType, 'image/png');
              final afterUpload = await patiently(
                account.currentUserWithProfile,
              );
              expect(
                afterUpload.profile.updated!.isAfter(
                  beforeUpload.profile.updated!,
                ),
                isTrue,
              );

              await expectLater(
                port.uploadAvatar(
                  fileName: 'avatar.txt',
                  bytes: Stream.value(utf8.encode('not an image')),
                  length: 12,
                ),
                throwsA(
                  isA<ValidationFailed>().having(
                    (f) => f.fieldErrors.keys,
                    'fields',
                    ['avatar'],
                  ),
                ),
              );
              await Future<void>.delayed(_pace);
              expect(
                await patiently(port.avatarProvider),
                AvatarProvider.upload,
              );

              await paced(
                () => port.setAvatarProvider(AvatarProvider.initials),
              );
              expect(
                await patiently(port.avatarProvider),
                AvatarProvider.initials,
              );
            },
          );
        }

        test('the sign-in providers are refused before any request', () async {
          final port = portOver(connection);

          await expectLater(
            port.setAvatarProvider(AvatarProvider.openid),
            throwsArgumentError,
          );
        });
      });
    }
  });
}
