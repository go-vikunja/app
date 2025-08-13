import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/reppository_provider.dart';
import 'package:vikunja_app/core/services.dart';
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
    var ignoreCertificates =
        await ref.read(settingsRepositoryProvider).getIgnoreCertificates();
    var versionNotification =
        await ref.read(settingsRepositoryProvider).getVersionNotifications();
    var refreshInterval =
        await ref.read(settingsRepositoryProvider).getRefreshInterval();
    var sentryEnabled =
        await ref.read(settingsRepositoryProvider).getSentryEnabled();
    var themeMode = await ref.read(settingsRepositoryProvider).getThemeMode();
    var dynamicColor =
        await ref.read(settingsRepositoryProvider).getDynamicColors();

    var version =
        await ref.read(versionRepositoryProvider).getCurrentVersionTag();

    return SettingsPageState(ignoreCertificates, sentryEnabled,
        versionNotification, refreshInterval, themeMode, dynamicColor, version);
  }

  Future<void> setThemeMode(FlutterThemeMode mode) async {
    ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = AsyncData(await getAll());
  }

  Future<void> setDynamicColors(bool dynamicColors) async {
    ref.read(settingsRepositoryProvider).setDynamicColors(dynamicColors);
    state = AsyncData(await getAll());
  }

  Future<void> setSentryEnabled(bool value) async {
    ref.read(settingsRepositoryProvider).setSentryEnabled(value);
    state = AsyncData(await getAll());
  }

  Future<void> setIgnoreCertificates(bool value) async {
    ref.read(settingsRepositoryProvider).setIgnoreCertificates(value);
    state = AsyncData(await getAll());
  }

  Future<void> setRefreshInterval(int minutes) async {
    ref.read(settingsRepositoryProvider).setRefreshInterval(minutes);
    state = AsyncData(await getAll());
  }

  Future<void> setVersionNotifications(bool value) async {
    ref.read(settingsRepositoryProvider).setVersionNotifications(value);
    state = AsyncData(await getAll());
  }
}
