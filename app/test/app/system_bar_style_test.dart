import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/theme/system_bar_style.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';

import '../helpers/pump_app.dart';

const _android = TargetPlatformVariant({TargetPlatform.android});
const _iOS = TargetPlatformVariant({TargetPlatform.iOS});

/// The style of the region where Flutter looks for the status bar's, the
/// centre of the status bar.
SystemUiOverlayStyle? _atStatusBar(WidgetTester tester) {
  final view = tester.binding.renderViews.single;
  return view.debugLayer!.find<SystemUiOverlayStyle>(
    Offset(view.paintBounds.center.dx, tester.view.padding.top / 2),
  );
}

/// Where Flutter looks for Android's navigation bar style.
SystemUiOverlayStyle? _atNavigationBar(WidgetTester tester) {
  final view = tester.binding.renderViews.single;
  final bounds = view.paintBounds;
  return view.debugLayer!.find<SystemUiOverlayStyle>(
    Offset(
      bounds.center.dx,
      bounds.bottom - 1 - tester.view.padding.bottom / 2,
    ),
  );
}

void _usePlatformBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Dark icons and text on a light page, light ones on a dark page.
void _expectReadableOn(Brightness page, SystemUiOverlayStyle? style) {
  expect(style, isNotNull);
  expect(
    style!.statusBarIconBrightness,
    page == Brightness.light ? Brightness.dark : Brightness.light,
  );
  expect(style.statusBarBrightness, page);
}

void _expectNoNavigationBarFields(SystemUiOverlayStyle? style) {
  expect(style, isNotNull);
  expect(style!.systemNavigationBarColor, isNull);
  expect(style.systemNavigationBarDividerColor, isNull);
  expect(style.systemNavigationBarIconBrightness, isNull);
  expect(style.systemNavigationBarContrastEnforced, isNull);
}

/// Android's navigation bar in the colour of the bottom bar of the theme the
/// app shows, [theme], with icons that read on it.
void _expectNavigationBarOf(
  WidgetTester tester,
  Brightness theme,
  SystemUiOverlayStyle? style,
) {
  final colors = Theme.of(tester.element(find.byType(Scaffold).first))
      .colorScheme;
  expect(colors.brightness, theme);
  expect(style, isNotNull);
  expect(style!.systemNavigationBarColor, colors.surfaceContainer);
  expect(
    style.systemNavigationBarIconBrightness,
    ThemeData.estimateBrightnessForColor(colors.surfaceContainer) ==
            Brightness.light
        ? Brightness.dark
        : Brightness.light,
  );
  expect(
    style.systemNavigationBarIconBrightness,
    theme == Brightness.light ? Brightness.dark : Brightness.light,
  );
}

void main() {
  test('systemBarStyleOn gives a transparent status bar that reads on the '
      'background, and no navigation bar fields', () {
    for (final (background, page) in const [
      (Color(0xFFFFFFFF), Brightness.light),
      (Color(0xFF000000), Brightness.dark),
    ]) {
      expect(
        systemBarStyleOn(background),
        SystemUiOverlayStyle(
          statusBarColor: const Color(0x00000000),
          statusBarBrightness: page,
          statusBarIconBrightness: page == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
      );
    }
  });

  test('systemBarStyleOn with a navigation bar gives it that colour and '
      'icons that read on it', () {
    for (final (bar, icons) in const [
      (Color(0xFFF0F0F0), Brightness.dark),
      (Color(0xFF202020), Brightness.light),
    ]) {
      final style = systemBarStyleOn(
        const Color(0xFFFFFFFF),
        navigationBar: bar,
      );
      expect(style.systemNavigationBarColor, bar);
      expect(style.systemNavigationBarIconBrightness, icons);
      expect(style.statusBarIconBrightness, Brightness.dark);
    }
    _expectNoNavigationBarFields(systemBarStyleOn(const Color(0xFF000000)));
  });

  for (final brightness in Brightness.values) {
    testWidgets('after an iOS sheet closes over a page without an app bar, '
        'the status bar reads on the page (${brightness.name})', (
      tester,
    ) async {
      _usePlatformBrightness(tester, brightness);
      await pumpVikunjaApp(tester);
      final page = find.byType(ConnectServerScreen);
      expect(page, findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      unawaited(
        showReadableCupertinoSheet<void>(
          context: tester.element(page),
          scrollableBuilder: (context, controller) => const SizedBox.expand(),
        ),
      );
      await tester.pumpAndSettle();
      // The sheet's gap above it asks for light text on any page.
      expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);

      Navigator.of(tester.element(find.byType(ReadableSheetWidth))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ReadableSheetWidth), findsNothing);

      _expectReadableOn(brightness, _atStatusBar(tester));
      _expectReadableOn(brightness, SystemChrome.latestStyle);
    }, variant: _iOS);
  }

  for (final brightness in Brightness.values) {
    testWidgets('the Overview, without an app bar, gets a status bar that '
        'reads on it (${brightness.name})', (tester) async {
      _usePlatformBrightness(tester, brightness);
      await pumpSignedInApp(tester);
      expect(find.byType(OverviewScreen), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      _expectReadableOn(brightness, _atStatusBar(tester));
      _expectReadableOn(brightness, SystemChrome.latestStyle);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets("Android's navigation bar takes the bottom bar's colour with "
        'icons that read on it (${brightness.name})', (tester) async {
      _usePlatformBrightness(tester, brightness);
      await pumpVikunjaApp(tester);
      expect(find.byType(AppBar), findsNothing);

      _expectReadableOn(brightness, _atStatusBar(tester));
      _expectNavigationBarOf(tester, brightness, _atNavigationBar(tester));
      _expectNavigationBarOf(tester, brightness, SystemChrome.latestStyle);
    }, variant: _android);
  }

  testWidgets("Android's navigation bar follows a change of the theme while "
      'the app runs', (tester) async {
    _usePlatformBrightness(tester, Brightness.light);
    await pumpVikunjaApp(tester);
    _expectNavigationBarOf(tester, Brightness.light, SystemChrome.latestStyle);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    _expectNavigationBarOf(tester, Brightness.dark, SystemChrome.latestStyle);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    _expectNavigationBarOf(tester, Brightness.light, SystemChrome.latestStyle);
  }, variant: _android);

  testWidgets("the account's colour scheme decides Android's navigation bar, "
      "not the system's", (tester) async {
    _usePlatformBrightness(tester, Brightness.light);
    await pumpVikunjaApp(
      tester,
      overrides: [themeModeProvider.overrideWithValue(ThemeMode.dark)],
    );

    _expectReadableOn(Brightness.dark, SystemChrome.latestStyle);
    _expectNavigationBarOf(tester, Brightness.dark, SystemChrome.latestStyle);
  }, variant: _android);

  testWidgets('an app bar still decides the status bar where it is', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);
    Navigator.of(tester.element(find.byType(ConnectServerScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF000000),
            title: const Text('A dark app bar'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectReadableOn(Brightness.dark, _atStatusBar(tester));
    _expectReadableOn(Brightness.dark, SystemChrome.latestStyle);
  });
}
