import 'package:flutter/material.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/theming/theme.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';

class ThemeModel {
  final FlutterThemeMode themeMode;
  final bool dynamicColors;

  ThemeModel({
    this.themeMode = FlutterThemeMode.light,
    this.dynamicColors = false,
  });

  ThemeData getTheme(ColorScheme? lightTheme) {
    return dynamicColors
        ? ThemeData(
            colorScheme: lightTheme,
            scaffoldBackgroundColor: lightTheme?.surface,
            canvasColor: lightTheme?.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: lightTheme?.primary,
              foregroundColor: lightTheme?.onPrimary,
            ),
            extensions: [
              AppColors(
                success: MaterialTheme.success.light.colorContainer,
                onSuccess: MaterialTheme.success.light.onColorContainer,
                warning: MaterialTheme.warning.light.colorContainer,
                onWarning: MaterialTheme.warning.light.onColorContainer,
                danger: MaterialTheme.danger.light.colorContainer,
                onDanger: MaterialTheme.danger.light.onColorContainer,
              ),
            ],
          )
        : _buildVikunjaLight();
  }

  ThemeData getDarkTheme(ColorScheme? darkTheme) {
    return dynamicColors
        ? ThemeData(
            colorScheme: darkTheme,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: darkTheme?.surface,
            canvasColor: darkTheme?.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: darkTheme?.primary,
              foregroundColor: darkTheme?.onPrimary,
            ),
            extensions: [
              AppColors(
                success: MaterialTheme.success.dark.color,
                onSuccess: MaterialTheme.success.dark.onColor,
                warning: MaterialTheme.warning.dark.color,
                onWarning: MaterialTheme.warning.dark.onColor,
                danger: MaterialTheme.danger.dark.color,
                onDanger: MaterialTheme.danger.dark.onColor,
              ),
            ],
          )
        : _buildVikunjaDark();
  }

  ThemeData _buildVikunjaLight() {
    var lightScheme = MaterialTheme.lightScheme();
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: lightScheme.surface,
      canvasColor: lightScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: lightScheme.primary,
        foregroundColor: lightScheme.onPrimary,
      ),
      extensions: [
        AppColors(
          success: MaterialTheme.success.light.colorContainer,
          onSuccess: MaterialTheme.success.light.onColorContainer,
          warning: MaterialTheme.warning.light.colorContainer,
          onWarning: MaterialTheme.warning.light.onColorContainer,
          danger: MaterialTheme.danger.light.colorContainer,
          onDanger: MaterialTheme.danger.light.onColorContainer,
        ),
      ],
    );
  }

  ThemeData _buildVikunjaDark() {
    var darkScheme = MaterialTheme.darkScheme();
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: darkScheme.surface,
      canvasColor: darkScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.primaryContainer,
        foregroundColor: darkScheme.onPrimaryContainer,
      ),
      extensions: [
        AppColors(
          success: MaterialTheme.success.dark.color,
          onSuccess: MaterialTheme.success.dark.onColor,
          warning: MaterialTheme.warning.dark.color,
          onWarning: MaterialTheme.warning.dark.onColor,
          danger: MaterialTheme.danger.dark.color,
          onDanger: MaterialTheme.danger.dark.onColor,
        ),
      ],
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
