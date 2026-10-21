@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

/// A 1 × 1 PNG.
final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAj'
  'CB0C8AAAAASUVORK5CYII=',
);

/// `GET /user` with the test user's long-lived JWT.
final class _StaticAccountGateway implements AccountGateway {
  new(this._dio, this._connection);

  final Dio _dio;
  final ServerConnection _connection;

  AccountApi get _api => AccountApi(_dio, _connection);

  @override
  Future<User> currentUser(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api.currentUser();

  @override
  Future<UserWithSettings> currentUserWithSettings(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api.currentUserWithSettings();

  @override
  Future<UserWithProfile> currentUserWithProfile(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api.currentUserWithProfile();

  @override
  Future<void> logout(ServerConnection connection, AccessTokenSource tokens) =>
      throw UnsupportedError('no logout in this test');
}

/// The settings minus [keys] (`frontend_settings.x` for a frontend key).
Map<String, Object?> _without(Map<String, Object?> settings, Set<String> keys) {
  const frontendPrefix = 'frontend_settings.';
  final frontend = {
    ...?(settings['frontend_settings'] as Map<String, Object?>?),
  };
  for (final key in keys) {
    if (key.startsWith(frontendPrefix)) {
      frontend.remove(key.substring(frontendPrefix.length));
    }
  }
  return {
    for (final MapEntry(:key, :value) in settings.entries)
      if (!keys.contains(key)) key: value,
    'frontend_settings': frontend,
  };
}

void main() {
  group(
    'account settings against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
        // What the web and other clients keep there, which the app does not
        // model.
        await seeder.patch('/user/settings/general', {
          'email_reminders_enabled': true,
          'discoverable_by_email': true,
          'overdue_tasks_reminders_time': '7:30',
          'frontend_settings': {
            'play_sound_when_done': false,
            'sidebar_width': 321,
            'rurana_contract_foreign': {
              'nested': [1, 2],
            },
            'color_schema': 'dark',
            'time_format': '12h',
          },
        });
      });

      tearDownAll(() => dio.close(force: true));

      Future<Map<String, Object?>> rawSettings() async =>
          (await seeder.get('/user'))['settings']! as Map<String, Object?>;

      for (final apiVersion in [ApiVersion.v2, ApiVersion.v1]) {
        group('over ${apiVersion.pathSegment}', () {
          final accountId = 'contract-${apiVersion.pathSegment}';
          late ProviderContainer container;
          late RecordingSyncEngine quiet;
          late AccountSettingsRepository repository;

          setUpAll(() async {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            final preferences = MemoryPreferencesStore();
            final secureStore = MemorySecureStore();
            await AccountRegistry(preferences).upsert(
              RegisteredAccount(
                account: Account(
                  id: accountId,
                  serverRoot: only.rootUri,
                  userId: user.id,
                  username: user.username,
                  displayName: user.username,
                  addedAt: DateTime.utc(2026, 10, 20),
                ),
                connection: only,
              ),
              activate: true,
            );
            // Not flagged as an account without tokens; the JWT is static.
            await secureStore.write(TokenStore.refreshTokenKey(accountId), '-');
            quiet = RecordingSyncEngine();
            final db = testDatabase();
            container = ProviderContainer(
              overrides: [
                preferencesStoreProvider.overrideWithValue(preferences),
                secureStoreProvider.overrideWithValue(secureStore),
                // Only asked for the session, never to refresh.
                tokenGatewayProvider.overrideWithValue(FakeTokenGateway()),
                accountGatewayProvider.overrideWithValue(
                  _StaticAccountGateway(authenticated, only),
                ),
                accountDioProvider.overrideWith((ref, _) => authenticated),
                appDatabaseProvider.overrideWith((ref, _) => db),
                // The repository's sync after a write does nothing, so a
                // check sees the write's own answer.
                syncEngineProvider.overrideWith((ref, _) => quiet),
              ],
            );
            addTearDown(container.dispose);
            await container.read(accountsProvider.future);
            repository = container
                .listen(
                  accountSettingsRepositoryForProvider(accountId),
                  (_, _) {},
                )
                .read();
            await repository.refresh();
          });

          Future<AccountSettingsState> stored() => repository.watch().first;

          test('a change leaves every other raw setting as it was, foreign '
              'frontend keys included', () async {
            final before = await rawSettings();
            final weekStart = before['week_start'] == 2 ? 3 : 2;

            await repository.update(
              UserSettingsChanges(
                weekStart: weekStart,
                dateDisplay: const SettingChange.set(DateDisplay.dayMonthYear),
              ),
            );
            await _pace();

            final after = await rawSettings();
            const changed = {'week_start', 'frontend_settings.date_display'};
            expect(_without(after, changed), _without(before, changed));
            expect(after['week_start'], weekStart);
            expect(
              (after['frontend_settings']! as Map)['date_display'],
              'dayMonthYear',
            );
            expect((after['frontend_settings']! as Map)['sidebar_width'], 321);
            final settings = (await stored()).settings;
            expect(settings.weekStart, weekStart);
            expect(settings.dateDisplay, DateDisplay.dayMonthYear);
            expect(settings.emailRemindersEnabled, isTrue);
            expect(settings.overdueTasksRemindersTime, const ClockTime(7, 30));
            expect(quiet.refreshAfterWriteCalls, greaterThan(0));
          });

          test('clearing a frontend setting removes only that key', () async {
            await repository.update(
              const UserSettingsChanges(
                timeFormat: SettingChange.set(TimeFormat.twelveHour),
              ),
            );
            await _pace();
            final before = await rawSettings();

            await repository.update(
              const UserSettingsChanges(timeFormat: SettingChange.clear()),
            );
            await _pace();

            final after = await rawSettings();
            final frontend =
                after['frontend_settings']! as Map<String, Object?>;
            expect(frontend.containsKey('time_format'), isFalse);
            const changed = {'frontend_settings.time_format'};
            expect(_without(after, changed), _without(before, changed));
            expect((await stored()).settings.timeFormat, isNull);
          });

          test('a new name reaches the store, the profile and the account '
              'list', () async {
            final name = 'Contract ${apiVersion.pathSegment}';

            await repository.update(UserSettingsChanges(name: name));
            await _pace();
            await pumpEventQueue();

            expect((await rawSettings())['name'], name);
            final state = await stored();
            expect(state.settings.name, name);
            expect(state.profile?.name, name);
            expect(
              container
                  .read(accountsProvider)
                  .value
                  ?.find(accountId)
                  ?.account
                  .displayName,
              name,
            );
          });

          test('refusals are thrown and change nothing here', () async {
            final before = await stored();

            await expectLater(
              repository.update(
                const UserSettingsChanges(timezone: 'Mars/Phobos'),
              ),
              throwsA(isA<DomainError>().having((e) => e.code, 'code', 1025)),
            );
            await _pace();
            await expectLater(
              repository.update(
                const UserSettingsChanges(
                  defaultProjectId: SettingChange.set(999999),
                ),
              ),
              throwsA(isA<DomainError>().having((e) => e.code, 'code', 3017)),
            );
            await _pace();

            expect(await stored(), before);
          });

          test(
            'an avatar upload bumps the user and the cache asks again',
            () async {
              final cache = container.read(
                accountAvatarCacheProvider(accountId),
              );
              await cache.load(user.username, 64);
              final generation = cache.generationOf(user.username);
              final before = (await stored()).profile!.updated!;
              final directory = await Directory.systemTemp.createTemp('avatar');
              addTearDown(() => directory.delete(recursive: true));
              final image = File('${directory.path}/avatar.png');
              await image.writeAsBytes(_png);
              // `updated` has whole seconds.
              await Future<void>.delayed(const Duration(seconds: 1));

              await repository.uploadAvatar(image);
              await _pace();

              final state = await stored();
              expect(state.avatarProvider, AvatarProvider.upload);
              expect(state.profile!.updated!.isAfter(before), isTrue);
              expect(cache.generationOf(user.username), generation + 1);
              expect(cache.peek(user.username, 64), isNull);
              final uploaded = await cache.load(user.username, 64);
              expect(uploaded.bytes, isNotNull);

              await repository.setAvatarProvider(AvatarProvider.initials);
              await _pace();
              expect((await stored()).avatarProvider, AvatarProvider.initials);
              expect(cache.generationOf(user.username), generation + 2);
              // The initials are an SVG, which the app draws itself.
              expect((await cache.load(user.username, 64)).bytes, isNull);
            },
          );
        });
      }
    },
  );
}
