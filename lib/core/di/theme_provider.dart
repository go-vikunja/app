import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/presentation/manager/theme_model.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class Theme extends _$Theme {
  @override
  Future<ThemeModel> build() async {
    var themeMode = await ref.read(settingsRepositoryProvider).getThemeMode();
    var dynamicColors = await ref
        .read(settingsRepositoryProvider)
        .getDynamicColors();
    return ThemeModel(themeMode: themeMode, dynamicColors: dynamicColors);
  }

  void set(ThemeModel notification) {
    state = AsyncData(notification);
  }
}
