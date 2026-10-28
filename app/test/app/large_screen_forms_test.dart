import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/overview_actions.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../a11y/sweep_data.dart';
import '../helpers/large_screens.dart';
import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';

/// A window of the size matrix with the 640 inset of a form beside the
/// shell (the Account tab) and of a form page over it, as amendment A3 has
/// them. Beside the Android rail (`tab` null) the inset is what the
/// measured rail leaves beyond 640, halved.
typedef _Window = ({
  Size size,
  TargetPlatform platform,
  double? tab,
  double page,
});

const List<_Window> _matrix = [
  (size: androidPhone, platform: TargetPlatform.android, tab: 0, page: 0),
  (
    size: androidSmallLandscape,
    platform: TargetPlatform.android,
    tab: 0,
    page: 0,
  ),
  (size: androidLandscape, platform: TargetPlatform.android, tab: 0, page: 0),
  (size: androidSplit, platform: TargetPlatform.android, tab: 0, page: 0),
  (
    size: androidTabletPortrait,
    platform: TargetPlatform.android,
    tab: null,
    page: 80,
  ),
  (
    size: androidTabletLandscape,
    platform: TargetPlatform.android,
    tab: null,
    page: 320,
  ),
  (size: iPhone, platform: TargetPlatform.iOS, tab: 0, page: 0),
  (size: iPhoneLandscape, platform: TargetPlatform.iOS, tab: 0, page: 0),
  (size: iPad11Portrait, platform: TargetPlatform.iOS, tab: 97, page: 97),
  (size: iPad11Landscape, platform: TargetPlatform.iOS, tab: 277, page: 277),
  (size: iPad13Portrait, platform: TargetPlatform.iOS, tab: 192, page: 192),
];

_Window _window(Size size) =>
    _matrix.firstWhere((window) => window.size == size);

String _title(_Window window, double? inset) =>
    '${window.platform.name} ${sizeName(window.size)} '
    '(inset ${inset ?? 'beside the rail'})';

/// The window across, less the rail beside the shell and the notch's side
/// insets.
Band _available(WidgetTester tester) {
  final ratio = tester.view.devicePixelRatio;
  final padding = tester.view.padding;
  return (
    left: math.max(railRight(tester), padding.left / ratio),
    right: windowSize(tester).width - padding.right / ratio,
  );
}

Band _formBand(WidgetTester tester, double inset, {double margin = 0}) {
  final available = _available(tester);
  return (
    left: available.left + inset + margin,
    right: available.right - inset - margin,
  );
}

double _tabInset(WidgetTester tester, _Window window) {
  if (window.tab case final inset?) return inset;
  final available = _available(tester);
  final inset = (available.right - available.left - ReadableWidth.form) / 2;
  expect(inset, greaterThan(0));
  return inset;
}

Finder _mainList(Finder screen) =>
    find.descendant(of: screen, matching: find.byType(Scrollable)).first;

/// [box] fills the 640 band of [inset] (less [margin]), and on a large
/// window that band is the one the app's helpers compute.
void _expectFormBand(
  WidgetTester tester,
  Finder box,
  double inset, {
  double margin = 0,
}) {
  final rect = tester.getRect(box);
  expectFillsBand(rect, _formBand(tester, inset, margin: margin));
  if (WindowLayout(windowSize(tester)).capsWidths) {
    final band = readableBand(tester, ReadableWidth.form);
    expectFillsBand(rect, (
      left: band.left + margin,
      right: band.right - margin,
    ));
  }
}

void main() {
  group('the Account tab', () {
    for (final window in _matrix) {
      testWidgets('keeps its list across the window and its rows in the '
          'band, ${_title(window, window.tab)}', (tester) async {
        useWindow(tester, window.size);
        await pumpSweepApp(tester);
        await openTab(tester, en.tabAccount);

        final list = _mainList(find.byType(AccountTab));
        expectFillsBand(tester.getRect(list), _available(tester));
        final inset = _tabInset(tester, window);
        _expectFormBand(
          tester,
          find.widgetWithText(ListTile, en.accountSettingsEntry),
          inset,
        );
        _expectFormBand(tester, find.byType(SettingsSection).first, inset);
      }, variant: TargetPlatformVariant.only(window.platform));
    }

    for (final window in [
      _window(androidTabletLandscape),
      _window(iPad11Landscape),
    ]) {
      testWidgets('scrolls from a drag in its margin, '
          '${_title(window, window.tab)}', (tester) async {
        useWindow(tester, window.size);
        await pumpSweepApp(tester);
        await openTab(tester, en.tabAccount);

        final list = _mainList(find.byType(AccountTab));
        final position = tester.state<ScrollableState>(list).position;
        expect(position.maxScrollExtent, greaterThan(0));
        final rect = tester.getRect(list);
        await tester.dragFrom(
          Offset(rect.left + _tabInset(tester, window) / 2, rect.center.dy),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        expect(position.pixels, greaterThan(0));
      }, variant: TargetPlatformVariant.only(window.platform));
    }
  });

  group('a settings page over the shell', () {
    for (final window in [
      _window(androidTabletLandscape),
      _window(androidTabletPortrait),
      _window(iPad13Portrait),
      _window(androidSmallLandscape),
    ]) {
      testWidgets('keeps the account settings in the band, '
          '${_title(window, window.page)}', (tester) async {
        useWindow(tester, window.size);
        await pumpSweepApp(tester);
        pushTo(tester, AppRoutes.accountSettings);
        await tester.pumpAndSettle();

        final page = find.byType(AccountSettingsPage);
        expectFillsBand(tester.getRect(_mainList(page)), _available(tester));
        _expectFormBand(
          tester,
          find
              .descendant(
                of: find.descendant(
                  of: page,
                  matching: find.byType(SettingsSection),
                ),
                matching: find.byType(ListTile),
              )
              .first,
          window.page,
        );
      }, variant: TargetPlatformVariant.only(window.platform));
    }

    testWidgets('keeps the sessions in the band, '
        '${_title(_window(androidTabletLandscape), 320)}', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      pushTo(tester, AppRoutes.accountSessions);
      await tester.pumpAndSettle();

      final page = find.byType(SessionsPage);
      expectFillsBand(tester.getRect(_mainList(page)), _available(tester));
      _expectFormBand(
        tester,
        find.descendant(of: page, matching: find.byType(ListTile)).first,
        320,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('the task edit page', () {
    for (final window in [
      _window(iPad11Landscape),
      _window(androidTabletPortrait),
      _window(iPhone),
      _window(androidLandscape),
    ]) {
      testWidgets('keeps its fields in the band, '
          '${_title(window, window.page)}', (tester) async {
        useWindow(tester, window.size);
        await pumpSweepApp(tester);
        pushTo(tester, AppRoutes.taskEdit(1));
        await tester.pumpAndSettle();

        final page = find.byType(TaskEditPage);
        expectFillsBand(tester.getRect(_mainList(page)), _available(tester));
        _expectFormBand(
          tester,
          find.descendant(of: page, matching: find.byType(TextField)).first,
          window.page,
          margin: 16,
        );
      }, variant: TargetPlatformVariant.only(window.platform));
    }
  });

  group('the server overview', () {
    for (final (window, pinned) in [
      (_window(androidTabletLandscape), true),
      (_window(iPad11Landscape), true),
      (_window(iPhone), true),
      (_window(androidLandscape), false),
    ]) {
      testWidgets('keeps its content and its '
          '${pinned ? 'pinned' : 'scrolling'} actions in the band, '
          '${_title(window, window.page)}', (tester) async {
        useWindow(tester, window.size);
        await pumpServerOverview(tester, fullServer270());

        _expectFormBand(
          tester,
          find.byType(ServerHeader),
          window.page,
          margin: 16,
        );
        final actions = find.byType(OverviewActions);
        if (!pinned) {
          await tester.scrollUntilVisible(
            actions,
            200,
            scrollable: _mainList(find.byType(ServerOverviewScreen)),
          );
        }
        _expectFormBand(tester, actions, window.page, margin: 16);
        final scaffold = tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(ServerOverviewScreen),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(scaffold.bottomNavigationBar != null, pinned);
        if (pinned) {
          final bar = find
              .ancestor(of: actions, matching: find.byType(Material))
              .first;
          expectFillsBand(tester.getRect(bar), (
            left: 0,
            right: windowSize(tester).width,
          ));
        }
      }, variant: TargetPlatformVariant.only(window.platform));
    }
  });
}
