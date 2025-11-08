import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/di/theme_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/settings_page_state.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:workmanager/workmanager.dart';

part 'settings_controller.g.dart';

@riverpod
class SettingsController extends _$SettingsController {
  @override
  Future<SettingsPageState> build() async {
    return getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => getAll());
  }

  Future<SettingsPageState> getAll() async {
    var ignoreCertificates = await ref
        .read(settingsRepositoryProvider)
        .getIgnoreCertificates();
    var versionNotification = await ref
        .read(settingsRepositoryProvider)
        .getVersionNotifications();
    var refreshInterval = await ref
        .read(settingsRepositoryProvider)
        .getRefreshInterval();
    var sentryEnabled = await ref
        .read(settingsRepositoryProvider)
        .getSentryEnabled();
    var themeMode = await ref.read(settingsRepositoryProvider).getThemeMode();
    var dynamicColor = await ref
        .read(settingsRepositoryProvider)
        .getDynamicColors();

    var version = await ref
        .read(versionRepositoryProvider)
        .getCurrentVersionTag();

    final user = ref.read(currentUserProvider)!;
    final projects = ref.watch(projectsControllerProvider).value;

    return SettingsPageState(
      user,
      projects ?? [],
      ignoreCertificates,
      sentryEnabled,
      versionNotification,
      refreshInterval,
      themeMode,
      dynamicColor,
      version,
    );
  }

  Future<void> setThemeMode(FlutterThemeMode mode) async {
    ref.read(settingsRepositoryProvider).setThemeMode(mode);
    var themeModel = ref.read(themeProvider).value?.copyWith(themeMode: mode);
    if (themeModel != null) {
      ref.read(themeProvider.notifier).set(themeModel);
    }
    state = AsyncData(await getAll());
  }

  Future<void> setDynamicColors(bool dynamicColors) async {
    ref.read(settingsRepositoryProvider).setDynamicColors(dynamicColors);
    var themeModel = ref
        .read(themeProvider)
        .value
        ?.copyWith(dynamicColors: dynamicColors);
    if (themeModel != null) {
      ref.read(themeProvider.notifier).set(themeModel);
    }
    state = AsyncData(await getAll());
  }

  Future<void> setSentryEnabled(bool value) async {
    ref.read(settingsRepositoryProvider).setSentryEnabled(value);
    state = AsyncData(await getAll());
  }

  Future<void> setIgnoreCertificates(bool value) async {
    ref.read(settingsRepositoryProvider).setIgnoreCertificates(value);

    ref.read(clientProviderProvider).setIgnoreCerts(value);

    state = AsyncData(await getAll());
  }

  Future<void> setRefreshInterval(int minutes) async {
    ref.read(settingsRepositoryProvider).setRefreshInterval(minutes);
    state = AsyncData(await getAll());

    updateWorkManagerDuration();
  }

  Future<void> setVersionNotifications(bool value) async {
    ref.read(settingsRepositoryProvider).setVersionNotifications(value);
    state = AsyncData(await getAll());
  }

  void updateWorkManagerDuration() async {
    if (kIsWeb) {
      return;
    }


    var settings = await getAll();
    // var settings = ref.read(settingsControllerProvider);
    // settings.whenData((settings) {
      Workmanager().cancelAll().then((value) {
        var duration = Duration(minutes: settings.refreshInterval);
        if (duration.inMinutes > 0) {
          Workmanager().registerPeriodicTask(
            "update-tasks",
            "update-tasks",
            frequency: duration,
            constraints: Constraints(networkType: NetworkType.connected),
            initialDelay: Duration(seconds: 15),
          );
        }

        Workmanager().registerPeriodicTask(
          "refresh-token",
          "refresh-token",
          frequency: Duration(hours: 12),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresDeviceIdle: true,
          ),
          initialDelay: Duration(seconds: 15),
        );
      });
  }

  void setDefaultProject(int value) {
    final user = ref.read(currentUserProvider);
    user!.settings!.default_project_id = value;
    ref.watch(userRepositoryProvider).setCurrentUserSettings(user.settings!);

    ref.read(currentUserProvider.notifier).set(user);

    refresh();
  }
}
