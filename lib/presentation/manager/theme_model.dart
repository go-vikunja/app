import 'package:flutter/material.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/core/utils/constants.dart';

class ThemeModel {
  final FlutterThemeMode themeMode;
  final bool dynamicColors;

  ThemeModel({
    this.themeMode = FlutterThemeMode.light,
    this.dynamicColors = false,
  });

  ThemeData getTheme(ColorScheme? lightTheme) {
    return dynamicColors
        ? ThemeData(colorScheme: lightTheme)
        : _buildVikunjaLight();
  }

  ThemeData getDarkTheme(ColorScheme? darkTheme) {
    return dynamicColors
        ? ThemeData(colorScheme: darkTheme, brightness: Brightness.dark)
        : _buildVikunjaDark();
  }

  ThemeData _buildVikunjaLight() {
    return ThemeData.light().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: vPrimary,
        dynamicSchemeVariant: DynamicSchemeVariant.content,
      ),
    );
  }

  ThemeData _buildVikunjaDark() {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: vPrimary,
        brightness: Brightness.dark,
      ),
    );
  }

  ThemeMode getThemeMode() {
    switch (themeMode) {
      case FlutterThemeMode.light:
        return ThemeMode.light;
      case FlutterThemeMode.dark:
        return ThemeMode.dark;
      case FlutterThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeModel copyWith({FlutterThemeMode? themeMode, bool? dynamicColors}) {
    return ThemeModel(
      themeMode: themeMode ?? this.themeMode,
      dynamicColors: dynamicColors ?? this.dynamicColors,
    );
  }
}
