import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';

part 'appearance_settings.g.dart';

final _log = Logger('Theme');

const useSystemColorsKey = 'appearance.system_colors';
const themeModeKey = 'appearance.theme';

/// The device's theme, the same for every account and for guests; the
/// system's until it is read.
@riverpod
ThemeMode themeMode(Ref ref) =>
    ref.watch(themeChoiceProvider).value ?? ThemeMode.system;

/// The device-wide light, dark or system theme, the system's unless
/// another was picked.
@Riverpod(keepAlive: true)
class ThemeChoice extends _$ThemeChoice {
  @override
  Future<ThemeMode> build() async {
    final stored = await ref
        .watch(preferencesStoreProvider)
        .getString(themeModeKey);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    try {
      await ref
          .read(preferencesStoreProvider)
          .setString(themeModeKey, mode.name);
    } on Object catch (error) {
      _log.warning('Could not store the theme: ${error.runtimeType}');
    }
  }
}

/// The device-wide "Use system colours" switch, on unless turned off.
@Riverpod(keepAlive: true)
class UseSystemColors extends _$UseSystemColors {
  @override
  Future<bool> build() async {
    final stored = await ref
        .watch(preferencesStoreProvider)
        .getString(useSystemColorsKey);
    return stored != 'false';
  }

  Future<void> set({required bool enabled}) async {
    state = AsyncData(enabled);
    try {
      await ref
          .read(preferencesStoreProvider)
          .setString(useSystemColorsKey, '$enabled');
    } on Object catch (error) {
      _log.warning('Could not store the colour choice: ${error.runtimeType}');
    }
  }
}
