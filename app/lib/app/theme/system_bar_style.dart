import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A transparent status bar whose icons and text read on [background], and
/// with [navigationBar] Android's navigation bar in that colour with icons
/// that read on it. Without [navigationBar] the style has no navigation bar
/// fields and leaves the bar as it is, although a region that reaches the
/// bottom of the window decides the navigation bar.
///
/// Flutter sets the navigation bar from Android 8 on; Android 15 and later
/// ignore its colour, as the app draws behind the bar, and the icons and the
/// contrast scrim of 3-button navigation follow the icon brightness.
SystemUiOverlayStyle systemBarStyleOn(
  Color background, {
  Color? navigationBar,
}) {
  final darkBackground = _isDark(background);
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarBrightness: darkBackground ? Brightness.dark : Brightness.light,
    statusBarIconBrightness: darkBackground
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarColor: navigationBar,
    systemNavigationBarIconBrightness: switch (navigationBar) {
      null => null,
      final bar => _isDark(bar) ? Brightness.light : Brightness.dark,
    },
  );
}

bool _isDark(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
