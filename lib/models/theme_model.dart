import 'package:flutter/material.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:vikunja_app/theme/constants.dart';

class ThemeModel with ChangeNotifier {
  FlutterThemeMode _themeMode = FlutterThemeMode.light;
  bool _dynamicColors = false;

  FlutterThemeMode get themeMode => _themeMode;

  void set themeMode(FlutterThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void set dynamicColors(bool dynamicTheme) {
    _dynamicColors = dynamicTheme;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  ThemeData? getLightTheme(ColorScheme? lightTheme) {
    switch (_themeMode) {
      case FlutterThemeMode.system:
        return lightTheme != null && _dynamicColors
            ? ThemeData(colorScheme: lightTheme)
            : _buildVikunjaLight();
      case FlutterThemeMode.dark:
        return null;
      case FlutterThemeMode.light:
        return _dynamicColors
            ? ThemeData(colorScheme: lightTheme)
            : _buildVikunjaLight();
    }
  }

  ThemeData? getDarkTheme(ColorScheme? darkTheme) {
    switch (_themeMode) {
      case FlutterThemeMode.system:
        return darkTheme != null && _dynamicColors
            ? ThemeData(colorScheme: darkTheme)
            : _buildVikunjaDark();
      case FlutterThemeMode.dark:
        return _dynamicColors
            ? ThemeData(colorScheme: darkTheme)
            : _buildVikunjaDark();
      case FlutterThemeMode.light:
        return null;
    }
  }

  ThemeData _buildVikunjaLight() {
    return ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: vPrimary,
            dynamicSchemeVariant: DynamicSchemeVariant.content));
  }

  ThemeData _buildVikunjaDark() {
    return ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: vPrimary, brightness: Brightness.dark));
  }
}
