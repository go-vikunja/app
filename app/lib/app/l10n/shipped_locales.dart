import 'package:flutter/widgets.dart';

/// The languages the app offers, English first as the fallback (D88). An
/// ARB file not listed here compiles, but nothing selects it. Android's
/// locales_config.xml, iOS's CFBundleLocalizations and `PreviousApp.kt`
/// list the same languages; tests keep them equal.
const List<Locale> shippedLocales = [Locale('en'), Locale('de')];

/// The shipped locale MaterialApp shows for a device that reports
/// [locales], resolved over the whole list, else English. Tests pass
/// another [shipped] list.
Locale shippedLocaleFor(
  Iterable<Locale> locales, {
  List<Locale> shipped = shippedLocales,
}) => basicLocaleListResolution(locales.toList(), shipped);
