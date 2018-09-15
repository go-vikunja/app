import 'package:flutter/material.dart';

const vBlue = Color(0xFF455486);
const vBlueLight = Color(0xFF7480b7);
const vBlueDark = Color(0xFF152c5a);
const vBlack = Color(0xFFFFFFFF);

ThemeData buildVikunjaTheme() {
  var base = ThemeData.light();
  return base.copyWith(
    primaryColor: vBlue,
    primaryColorLight: vBlueLight,
    primaryColorDark: vBlueDark,
    textTheme: base.textTheme.copyWith(
      headline: base.textTheme.headline.copyWith(
        fontFamily: 'Quicksand',
        fontSize: 72.0,
      ),
      subhead: base.textTheme.subhead.copyWith(
        fontFamily: 'Quicksand',
        fontSize: 24.0,
      ),
      title: base.textTheme.title.copyWith(
        fontFamily: 'Quicksand',
      ),
      body1: base.textTheme.body1.copyWith(
        fontFamily: 'Quicksand',
      )
    )
  );
}