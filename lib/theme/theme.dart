import 'package:flutter/material.dart';
import 'package:vikunja_app/theme/constants.dart';

ThemeData buildVikunjaTheme() => _buildVikunjaTheme(ThemeData.light());

ThemeData buildVikunjaDarkTheme() {
  ThemeData base = _buildVikunjaTheme(ThemeData.dark());
  return base.copyWith(
    accentColor: vWhite,
  );
}

ThemeData _buildVikunjaTheme(ThemeData base) {
  return base.copyWith(
    errorColor: vRed,
    primaryColor: vPrimaryDark,
    primaryColorLight: vPrimary,
    primaryColorDark: vBlueDark,
    buttonTheme: base.buttonTheme.copyWith(
      buttonColor: vPrimary,
      textTheme: ButtonTextTheme.normal,
      colorScheme: base.buttonTheme.colorScheme.copyWith(
        // Why does this not work?
        onSurface: vWhite,
        onSecondary: vWhite,
        background: vBlue,
      ),
    ),
    textTheme: base.textTheme.copyWith(
//      headline: base.textTheme.headline.copyWith(
//        fontFamily: 'Quicksand',
//      ),
//      title: base.textTheme.title.copyWith(
//        fontFamily: 'Quicksand',
//      ),
      button: base.textTheme.button.copyWith(
        color:
            vWhite, // This does not work, looks like a bug in Flutter: https://github.com/flutter/flutter/issues/19623
      ),
    ),
  );
}
