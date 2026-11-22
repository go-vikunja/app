import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/settings/appearance_settings.dart';

part 'theme_providers.g.dart';

final _log = Logger('Theme');

typedef ColorSchemes = ({ColorScheme light, ColorScheme dark});

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

/// The schemes the themes use instead of the brand blue; null for the
/// brand blue.
@riverpod
ColorSchemes? appColorSchemes(Ref ref) {
  final system = ref.watch(systemColorsProvider).value;
  if (system == null) return null;
  final enabled = ref.watch(useSystemColorsProvider).value ?? false;
  return enabled ? system : null;
}
