import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vikunja_app/theme/constants.dart';

ThemeData buildVikunjaTheme() => _buildVikunjaTheme(ThemeData.light());
ThemeData buildVikunjaDarkTheme() =>
    _buildVikunjaTheme(ThemeData.dark(), isDark: true);

ThemeData buildVikunjaMaterialLightTheme() {
  return ThemeData.light().copyWith(
    useMaterial3: true,
  );
}

ThemeData buildVikunjaMaterialDarkTheme() {
  return ThemeData.dark().copyWith(
    useMaterial3: true,
  );
}

ThemeData _buildVikunjaTheme(ThemeData base, {bool isDark = false}) {
  return base.copyWith(
    useMaterial3: true,
    primaryColor: vPrimaryDark,
    primaryColorLight: vPrimary,
    primaryColorDark: vBlueDark,
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      foregroundColor: vWhite,
    ),
    textTheme: base.textTheme.copyWith(
//      headline: base.textTheme.headline.copyWith(
//        fontFamily: 'Quicksand',
//      ),
//      title: base.textTheme.title.copyWith(
//        fontFamily: 'Quicksand',
//      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color:
            vWhite, // This does not work, looks like a bug in Flutter: https://github.com/flutter/flutter/issues/19623
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      enabledBorder: UnderlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey, width: 1)),
    ),
    dividerTheme: DividerThemeData(
      color: () {
        return isDark ? Colors.white10 : Colors.black12;
      }(),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: vPrimary,
      // Make bottomNavigationBar backgroundColor darker to provide more separation
      backgroundColor: () {
        final _hslColor = HSLColor.fromColor(
            base.bottomNavigationBarTheme.backgroundColor ??
                base.scaffoldBackgroundColor);
        return _hslColor
            .withLightness(max(_hslColor.lightness - 0.03, 0))
            .toColor();
      }(),
    ),
    colorScheme: base.colorScheme
        .copyWith(
          primary: vPrimaryDark,
          secondary: vPrimary,
        )
        .copyWith(error: vRed),
  );
}
