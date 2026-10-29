import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A transparent status bar whose icons and text read on [background].
/// Without navigation bar fields: a region that reaches the bottom of the
/// window would otherwise decide Android's navigation bar too.
SystemUiOverlayStyle statusBarStyleOn(Color background) {
  final darkBackground =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarBrightness: darkBackground ? Brightness.dark : Brightness.light,
    statusBarIconBrightness: darkBackground
        ? Brightness.light
        : Brightness.dark,
  );
}
