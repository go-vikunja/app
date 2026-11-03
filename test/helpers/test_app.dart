/// Harness for widget tests: a localised [MaterialApp] wired to fake
/// repositories, plus the provider-override plumbing every UI test needs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

import 'fake_repositories.dart';

/// The fakes backing one widget test, handed back by [repositoryOverrides] so a
/// test can stub responses and assert on recorded calls.
class TestRepositories {
  final FakeProjectRepository project = FakeProjectRepository();
  final FakeTaskRepository task = FakeTaskRepository();
  final FakeBucketRepository bucket = FakeBucketRepository();
  final FakeProjectViewRepository projectView = FakeProjectViewRepository();
  final FakeTaskCommentRepository comment = FakeTaskCommentRepository();
  final FakeLabelRepository label = FakeLabelRepository();
  final FakeTaskLabelRepository taskLabel = FakeTaskLabelRepository();
  final FakeTaskLabelBulkRepository labelBulk = FakeTaskLabelBulkRepository();
  final FakeUserRepository user = FakeUserRepository();
  final FakeServerRepository server = FakeServerRepository();
  final FakeVersionRepository version = FakeVersionRepository();
  final FakeSettingsRepository settings = FakeSettingsRepository();

  List<Override> get overrides => [
    projectRepositoryProvider.overrideWithValue(project),
    taskRepositoryProvider.overrideWithValue(task),
    bucketRepositoryProvider.overrideWithValue(bucket),
    projectViewRepositoryProvider.overrideWithValue(projectView),
    taskCommentRepositoryProvider.overrideWithValue(comment),
    labelRepositoryProvider.overrideWithValue(label),
    taskLabelRepositoryProvider.overrideWithValue(taskLabel),
    taskLabelBulkRepositoryProvider.overrideWithValue(labelBulk),
    userRepositoryProvider.overrideWithValue(user),
    serverRepositoryProvider.overrideWithValue(server),
    versionRepositoryProvider.overrideWithValue(version),
    settingsRepositoryProvider.overrideWithValue(settings),
  ];
}

/// Seeds [currentUserProvider] with [user] before the widget tree builds.
Override currentUserOverride(User user) =>
    currentUserProvider.overrideWith(() => _SeededCurrentUser(user));

class _SeededCurrentUser extends CurrentUser {
  _SeededCurrentUser(this._user);

  final User _user;

  @override
  User? build() => _user;
}

/// A small phone in logical pixels. Tests default to this so that a layout
/// which overflows on a real device also overflows here — the 800x600 default
/// `flutter_test` surface hides exactly the defects a UI test should catch.
/// Pass a larger [surfaceSize] for a test that genuinely needs the room.
const Size phoneSurface = Size(400, 800);

/// Phone width, but tall enough that a long scrolling page builds every row.
/// Lets a test assert on content without scrolling to it first while keeping the
/// width honest, so a layout defect still surfaces.
const Size tallPhoneSurface = Size(400, 2400);

/// Renders the current test at [size] logical pixels, restoring the default when
/// the test ends.
///
/// Resizes the view rather than calling `setSurfaceSize`: that only changes the
/// layout constraints and leaves `MediaQuery` reporting the old size, so a
/// widget that measures itself against `MediaQuery.sizeOf` gets laid out into a
/// box of a different width and overflows for a reason no device can reproduce.
void useSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [child] inside a localised `MaterialApp` and a `ProviderScope`.
///
/// [navigatorObservers] lets a test assert on navigation without reaching into
/// the widget under test.
///
/// Set [inScaffold] for widgets that need a `Material` ancestor (chips, list
/// tiles, ink wells) but do not bring their own.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  List<NavigatorObserver> navigatorObservers = const [],
  Locale locale = const Locale('en'),
  Size surfaceSize = phoneSurface,
  bool inScaffold = false,
}) async {
  useSurfaceSize(tester, surfaceSize);

  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: inScaffold ? Scaffold(body: Center(child: child)) : child,
        navigatorObservers: navigatorObservers,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    ),
  );

  return container;
}

/// The English strings, so a test can name a widget by the label the user sees
/// without hard-coding a translation. Call [loadL10n] once in `setUpAll`.
late AppLocalizations l10n;

Future<void> loadL10n() async {
  l10n = await AppLocalizations.delegate.load(const Locale('en'));
}

/// Drags [scrollable] down far enough to trigger a `RefreshIndicator`, then
/// lets the indicator run to completion.
Future<void> pullToRefresh(WidgetTester tester, Finder scrollable) async {
  // RefreshIndicator only fires well past a quarter of the scrollable's height,
  // and it ignores a single large jump — so drag most of the height, in steps,
  // starting near the top edge.
  final rect = tester.getRect(scrollable);
  final distance = rect.height * 0.8;
  const steps = 40;
  final gesture = await tester.startGesture(
    Offset(rect.center.dx, rect.top + 40),
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, distance / steps));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Taps [finder] and settles the resulting animation.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Enters [text] into [finder] and settles.
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}
