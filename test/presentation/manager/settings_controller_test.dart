import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/theme_provider.dart' as theme_di;
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

/// Records scheduling calls instead of talking to the OS scheduler.
class _FakeWorkmanager extends WorkmanagerPlatform {
  int cancelAllCount = 0;
  final List<Duration> scheduled = [];

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    String? tag,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    Duration? frequency,
    Duration? flexInterval,
    Duration? initialDelay,
    Constraints? constraints,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    Map<String, dynamic>? inputData,
    String? payload,
  }) async {
    if (frequency != null) scheduled.add(frequency);
  }
}

void main() {
  late ProviderContainer container;
  late TestRepositories repos;
  late _FakeWorkmanager workmanager;

  setUp(() {
    workmanager = _FakeWorkmanager();
    WorkmanagerPlatform.instance = workmanager;
    final harness = controllerHarness(
      user: buildUser(settings: buildUserSettings(defaultProjectId: 2)),
    );
    container = harness.container;
    repos = harness.repos;
  });

  // `setIgnoreCertificates` installs process-wide HttpOverrides.
  tearDown(() => io.HttpOverrides.global = null);

  SettingsController notifier() =>
      container.read(settingsControllerProvider.notifier);

  Future<void> start() async {
    keepAlive(container, settingsControllerProvider);
    await container.read(settingsControllerProvider.future);
  }

  group('build', () {
    test('gathers every setting, the user and their projects', () async {
      repos.settings
        ..ignoreCertificates = true
        ..sentryEnabled = true
        ..versionNotifications = true
        ..refreshInterval = 30
        ..themeMode = FlutterThemeMode.dark
        ..dynamicColors = true;
      repos.version.current = Version(1, 2, 3);
      repos.project.onGetAll = (_) => ok([buildProject(id: 1, title: 'Alpha')]);

      await start();

      final state = container.read(settingsControllerProvider).value!;
      expect(state.ignoreCertificates, isTrue);
      expect(state.sentryEnabled, isTrue);
      expect(state.versionNotifications, isTrue);
      expect(state.refreshInterval, 30);
      expect(state.themeMode, FlutterThemeMode.dark);
      expect(state.dynamicColors, isTrue);
      expect(state.currentVersion, Version(1, 2, 3));
      expect(state.user.username, 'testuser');
      expect(state.projects.single.title, 'Alpha');
    });

    test(
      'falls back to an empty project list when the request fails',
      () async {
        repos.project.onGetAll = (_) => err<List<Project>>();

        await start();

        expect(
          container.read(settingsControllerProvider).value!.projects,
          isEmpty,
        );
      },
    );
  });

  group('refresh', () {
    test('re-reads every setting', () async {
      await start();

      repos.settings.refreshInterval = 15;
      await notifier().refresh();

      expect(
        container.read(settingsControllerProvider).value!.refreshInterval,
        15,
      );
    });
  });

  group('setThemeMode', () {
    test('persists the mode and republishes it in the state', () async {
      await start();

      await notifier().setThemeMode(FlutterThemeMode.dark);

      expect(repos.settings.themeMode, FlutterThemeMode.dark);
      expect(
        container.read(settingsControllerProvider).value!.themeMode,
        FlutterThemeMode.dark,
      );
    });

    test('pushes the mode into the app theme', () async {
      await start();
      await container.read(theme_di.themeProvider.future);

      await notifier().setThemeMode(FlutterThemeMode.light);

      expect(
        container.read(theme_di.themeProvider).value!.themeMode,
        FlutterThemeMode.light,
      );
    });
  });

  group('setDynamicColors', () {
    test('persists the flag and republishes it in the state', () async {
      await start();

      await notifier().setDynamicColors(true);

      expect(repos.settings.dynamicColors, isTrue);
      expect(
        container.read(settingsControllerProvider).value!.dynamicColors,
        isTrue,
      );
    });

    test('pushes the flag into the app theme', () async {
      await start();
      await container.read(theme_di.themeProvider.future);

      await notifier().setDynamicColors(true);

      expect(
        container.read(theme_di.themeProvider).value!.dynamicColors,
        isTrue,
      );
    });
  });

  group('setSentryEnabled', () {
    test('persists the flag and republishes it', () async {
      await start();

      await notifier().setSentryEnabled(true);

      expect(repos.settings.sentryEnabled, isTrue);
      expect(
        container.read(settingsControllerProvider).value!.sentryEnabled,
        isTrue,
      );
    });
  });

  group('setIgnoreCertificates', () {
    test(
      'persists the flag, republishes it and reconfigures the client',
      () async {
        await start();

        await notifier().setIgnoreCertificates(true);

        expect(repos.settings.ignoreCertificates, isTrue);
        expect(
          container.read(settingsControllerProvider).value!.ignoreCertificates,
          isTrue,
        );
        expect(io.HttpOverrides.current, isNotNull);
      },
    );
  });

  group('setVersionNotifications', () {
    test('persists the flag and republishes it', () async {
      await start();

      await notifier().setVersionNotifications(true);

      expect(repos.settings.versionNotifications, isTrue);
      expect(
        container.read(settingsControllerProvider).value!.versionNotifications,
        isTrue,
      );
    });
  });

  group('setRefreshInterval', () {
    test('persists the interval and reschedules the background task', () async {
      await start();

      await notifier().setRefreshInterval(20);
      await pumpEventQueue();

      expect(repos.settings.refreshInterval, 20);
      expect(
        container.read(settingsControllerProvider).value!.refreshInterval,
        20,
      );
      expect(workmanager.cancelAllCount, 1);
      expect(workmanager.scheduled, [const Duration(minutes: 20)]);
    });

    test('an interval of zero cancels without rescheduling', () async {
      await start();

      await notifier().setRefreshInterval(0);
      await pumpEventQueue();

      expect(workmanager.cancelAllCount, 1);
      expect(workmanager.scheduled, isEmpty);
    });
  });

  group('setDefaultProject', () {
    test('saves the new default on the user and refreshes', () async {
      await start();

      notifier().setDefaultProject(7);
      await pumpEventQueue();

      expect(repos.user.settingsCalls.single.defaultProjectId, 7);
      expect(
        container
            .read(settingsControllerProvider)
            .value!
            .user
            .settings!
            .defaultProjectId,
        7,
      );
    });
  });
}
