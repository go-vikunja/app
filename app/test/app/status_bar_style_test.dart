import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/theme/status_bar_style.dart';
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

void main() {
  test('statusBarStyleOn gives a transparent status bar that reads on the '
      'background, and no navigation bar fields', () {
    for (final (background, page) in const [
      (Color(0xFFFFFFFF), Brightness.light),
      (Color(0xFF000000), Brightness.dark),
    ]) {
      expect(
        statusBarStyleOn(background),
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

  testWidgets("the fallback leaves Android's navigation bar as it is", (
    tester,
  ) async {
    await pumpVikunjaApp(tester);
    expect(find.byType(AppBar), findsNothing);

    _expectReadableOn(Brightness.light, _atStatusBar(tester));
    _expectNoNavigationBarFields(_atStatusBar(tester));
    _expectNoNavigationBarFields(_atNavigationBar(tester));
    _expectNoNavigationBarFields(SystemChrome.latestStyle);
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
