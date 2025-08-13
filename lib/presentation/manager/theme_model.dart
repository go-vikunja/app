import 'package:flutter/material.dart';
import 'package:vikunja_app/core/services.dart';
import 'package:vikunja_app/core/utils/constants.dart';

class ThemeModel {
  FlutterThemeMode _themeMode = FlutterThemeMode.light;
  bool _dynamicColors = false;

  FlutterThemeMode get themeMode => _themeMode;

  void set themeMode(FlutterThemeMode mode) {
    _themeMode = mode;
  }

  void set dynamicColors(bool dynamicTheme) {
    _dynamicColors = dynamicTheme;
  }

  ThemeData? getTheme(ColorScheme? lightTheme, ColorScheme? darkTheme) {
    switch (_themeMode) {
      case FlutterThemeMode.system:
        return lightTheme != null && _dynamicColors
            ? ThemeData(colorScheme: lightTheme)
            : _buildVikunjaLight();
      case FlutterThemeMode.dark:
        return _dynamicColors
            ? ThemeData(colorScheme: darkTheme, brightness: Brightness.dark)
            : _buildVikunjaDark();
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
            ? ThemeData(colorScheme: darkTheme, brightness: Brightness.dark)
            : _buildVikunjaDark();
      case FlutterThemeMode.dark:
        return null;
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
