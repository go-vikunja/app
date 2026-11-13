import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';

part 'theme_providers.g.dart';

final _log = Logger('Theme');

const useSystemColorsKey = 'appearance.system_colors';
const themeModeKey = 'appearance.theme';

typedef ColorSchemes = ({ColorScheme light, ColorScheme dark});

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

/// The palette Android 12 and later derive from the wallpaper, as light
/// and dark schemes; null on other platforms and older versions. Read
/// again whenever the app comes back to the front, as the wallpaper may
/// have changed meanwhile.
@Riverpod(keepAlive: true)
class SystemColors extends _$SystemColors {
  @override
  Future<ColorSchemes?> build() {
    final lifecycle = AppLifecycleListener(onResume: _readAgain);
    ref.onDispose(lifecycle.dispose);
    return readSystemColorSchemes();
  }

  Future<void> _readAgain() async {
    final schemes = await readSystemColorSchemes();
    if (schemes != state.value) state = AsyncData(schemes);
  }
}

Future<ColorSchemes?> readSystemColorSchemes() async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return (
      light: palette.toColorScheme(),
      dark: palette.toColorScheme(brightness: Brightness.dark),
    );
  } on Object catch (error) {
    _log.warning('Could not read the system colours: ${error.runtimeType}');
    return null;
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

/// The schemes the themes use instead of the brand blue; null for the
/// brand blue.
@riverpod
ColorSchemes? appColorSchemes(Ref ref) {
  final system = ref.watch(systemColorsProvider).value;
  if (system == null) return null;
  final enabled = ref.watch(useSystemColorsProvider).value ?? true;
  return enabled ? system : null;
}
