import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/background_work.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/di/theme_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/settings_page_state.dart';

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
    final projectsResponse = await ref.read(projectRepositoryProvider).getAll();

    var projects = projectsResponse.isSuccessful
        ? projectsResponse.toSuccess().body
        : <Project>[];

    return SettingsPageState(
      user,
      projects,
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
    var settings = await getAll();
    await registerBackgroundRefresh(settings.refreshInterval);
  }

  void setDefaultProject(int value) {
    final user = ref.read(currentUserProvider);
    user!.settings!.defaultProjectId = value;
    ref.read(userRepositoryProvider).setCurrentUserSettings(user.settings!);

    ref.read(currentUserProvider.notifier).set(user);

    refresh();
  }
}
