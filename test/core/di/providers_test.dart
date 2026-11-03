/// The DI graph: each provider builds the right implementation, and the few
/// providers that hold mutable state behave as their callers expect.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/core/di/locale_provider.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/di/theme_provider.dart' as theme_di;
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/data/data_sources/bucket_data_source.dart';
import 'package:vikunja_app/data/data_sources/label_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_view_data_source.dart';
import 'package:vikunja_app/data/data_sources/server_data_source.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_comment_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_bulk_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/data/repositories/bucket_repository_impl.dart';
import 'package:vikunja_app/data/repositories/label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_view_repository_impl.dart';
import 'package:vikunja_app/data/repositories/server_repository_impl.dart';
import 'package:vikunja_app/data/repositories/settings_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_comment_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_bulk_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/data/repositories/user_repository_impl.dart';
import 'package:vikunja_app/data/repositories/version_repository_impl.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/theme_model.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/plugin_mocks.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    mockPlatformPlugins();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('data source providers', () {
    test('each builds its own data source type', () {
      expect(
        container.read(projectDataSourceProvider),
        isA<ProjectDataSource>(),
      );
      expect(
        container.read(projectViewDataSourceProvider),
        isA<ProjectViewDataSource>(),
      );
      expect(container.read(bucketDataSourceProvider), isA<BucketDataSource>());
      expect(container.read(taskDataSourceProvider), isA<TaskDataSource>());
      expect(
        container.read(taskLabelDataSourceProvider),
        isA<TaskLabelDataSource>(),
      );
      expect(
        container.read(taskLabelBulkDataSourceProvider),
        isA<TaskLabelBulkDataSource>(),
      );
      expect(container.read(labelDataSourceProvider), isA<LabelDataSource>());
      expect(container.read(userDataSourceProvider), isA<UserDataSource>());
      expect(container.read(serverDataSourceProvider), isA<ServerDataSource>());
      expect(
        container.read(taskCommentDataSourceProvider),
        isA<TaskCommentDataSource>(),
      );
      expect(
        container.read(settingsDataSourceProvider),
        isA<SettingsDatasource>(),
      );
      expect(
        container.read(versionDataSourceProvider),
        isA<VersionDataSource>(),
      );
    });

    test('remote data sources share the one client instance', () {
      final client = container.read(clientProviderProvider);

      expect(container.read(projectDataSourceProvider).client, same(client));
      expect(container.read(taskDataSourceProvider).client, same(client));
      expect(container.read(bucketDataSourceProvider).client, same(client));
    });
  });

  group('repository providers', () {
    test('each builds its own repository implementation', () {
      expect(
        container.read(projectRepositoryProvider),
        isA<ProjectRepositoryImpl>(),
      );
      expect(
        container.read(projectViewRepositoryProvider),
        isA<ProjectViewRepositoryImpl>(),
      );
      expect(
        container.read(bucketRepositoryProvider),
        isA<BucketRepositoryImpl>(),
      );
      expect(container.read(taskRepositoryProvider), isA<TaskRepositoryImpl>());
      expect(
        container.read(taskLabelRepositoryProvider),
        isA<TaskLabelRepositoryImpl>(),
      );
      expect(
        container.read(taskLabelBulkRepositoryProvider),
        isA<TaskLabelBulkRepositoryImpl>(),
      );
      expect(
        container.read(labelRepositoryProvider),
        isA<LabelRepositoryImpl>(),
      );
      expect(container.read(userRepositoryProvider), isA<UserRepositoryImpl>());
      expect(
        container.read(serverRepositoryProvider),
        isA<ServerRepositoryImpl>(),
      );
      expect(
        container.read(settingsRepositoryProvider),
        isA<SettingsRepositoryImpl>(),
      );
      expect(
        container.read(versionRepositoryProvider),
        isA<VersionRepositoryImpl>(),
      );
      expect(
        container.read(taskCommentRepositoryProvider),
        isA<TaskCommentRepositoryImpl>(),
      );
    });
  });

  group('AuthData', () {
    test('starts empty', () {
      expect(container.read(authDataProvider), isNull);
    });

    test('set publishes the address', () {
      container
          .read(authDataProvider.notifier)
          .set(AuthModel('https://vikunja.example.com'));

      expect(
        container.read(authDataProvider)!.address,
        'https://vikunja.example.com',
      );
    });

    test('set rebuilds the client against the new address', () {
      final before = container.read(clientProviderProvider);
      expect(before.apiBase, '/api/v1');

      container
          .read(authDataProvider.notifier)
          .set(AuthModel('https://vikunja.example.com'));
      final after = container.read(clientProviderProvider);

      expect(after, isNot(same(before)));
      expect(after.apiBase, 'https://vikunja.example.com/api/v1');
    });
  });

  group('CurrentUser', () {
    test('starts empty', () {
      expect(container.read(currentUserProvider), isNull);
    });

    test('set publishes the user', () {
      container
          .read(currentUserProvider.notifier)
          .set(buildUser(username: 'demo'));

      expect(container.read(currentUserProvider)!.username, 'demo');
    });
  });

  group('Notification', () {
    test('starts empty', () {
      expect(container.read(notificationProvider), isNull);
    });

    test('set publishes the handler', () {
      final handler = NotificationHandler();

      container.read(notificationProvider.notifier).set(handler);

      expect(container.read(notificationProvider), same(handler));
    });
  });

  group('Theme', () {
    test('builds from the stored theme mode and dynamic-colour flag', () async {
      final settings = FakeSettingsRepository()
        ..themeMode = FlutterThemeMode.dark
        ..dynamicColors = true;
      final scoped = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(scoped.dispose);

      final model = await scoped.read(theme_di.themeProvider.future);

      expect(model.themeMode, FlutterThemeMode.dark);
      expect(model.dynamicColors, isTrue);
    });

    test('set replaces the published model', () async {
      await container.read(theme_di.themeProvider.future);

      container
          .read(theme_di.themeProvider.notifier)
          .set(ThemeModel(themeMode: FlutterThemeMode.light));

      expect(
        container.read(theme_di.themeProvider).value!.themeMode,
        FlutterThemeMode.light,
      );
    });
  });

  group('LocaleOverride', () {
    ProviderContainer withLocale(String? code) {
      final settings = FakeSettingsRepository()..localeOverride = code;
      final scoped = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(scoped.dispose);
      return scoped;
    }

    test('is null when no override is stored', () async {
      expect(
        await withLocale(null).read(localeOverrideProvider.future),
        isNull,
      );
    });

    test('is null when the stored override is empty', () async {
      expect(await withLocale('').read(localeOverrideProvider.future), isNull);
    });

    test('builds a Locale from the stored code', () async {
      expect(
        await withLocale('de').read(localeOverrideProvider.future),
        const Locale('de'),
      );
    });

    test('setLocale persists the language code and publishes it', () async {
      final settings = FakeSettingsRepository();
      final scoped = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(scoped.dispose);
      await scoped.read(localeOverrideProvider.future);

      await scoped
          .read(localeOverrideProvider.notifier)
          .setLocale(const Locale('it'));

      expect(settings.localeOverride, 'it');
      expect(scoped.read(localeOverrideProvider).value, const Locale('it'));
    });

    test('setLocale(null) clears the override', () async {
      final settings = FakeSettingsRepository()..localeOverride = 'de';
      final scoped = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(scoped.dispose);
      await scoped.read(localeOverrideProvider.future);

      await scoped.read(localeOverrideProvider.notifier).setLocale(null);

      expect(settings.localeOverride, isNull);
      expect(scoped.read(localeOverrideProvider).value, isNull);
    });
  });
}
