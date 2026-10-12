import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/platform/app_shortcuts.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../features/quick_add/presentation/composer_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';

void main() {
  late ComposerHarness harness;

  setUp(() {
    harness = ComposerHarness();
    harness.data.tasks.all = [sampleTask(id: 7, title: 'Existing')];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).state.matchedLocation;

  Finder projectChip(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ActionChip));

  testWidgets('registers the New task shortcut in the device language', (
    tester,
  ) async {
    await harness.pumpApp(tester);

    expect(harness.shortcuts.titles, [en.newTask]);
  });

  testWidgets('registers it in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await harness.pumpApp(tester);

    expect(harness.shortcuts.titles, [de.newTask]);
  });

  testWidgets('opens the New task sheet over the overview, once', (
    tester,
  ) async {
    await harness.pumpApp(tester);
    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();

    harness.shortcuts.trigger(newTaskShortcutType);
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
    expect(location(tester), AppRoutes.overview);
    // The overview has no project of its own.
    expect(projectChip('Inbox'), findsOneWidget);

    harness.shortcuts
      ..trigger(newTaskShortcutType)
      ..trigger(newTaskShortcutType);
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
  });

  testWidgets('a shortcut that launched the app waits for the shell', (
    tester,
  ) async {
    harness.shortcuts = FakeAppShortcuts(launchAction: newTaskShortcutType);
    await harness.pumpApp(tester);

    expect(find.byType(NewTaskSheet), findsOneWidget);
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('opens over the edit page without leaving it', (tester) async {
    await harness.pumpApp(tester);
    unawaited(routerOf(tester).push(AppRoutes.taskEdit(7)));
    await tester.pumpAndSettle();

    harness.shortcuts.trigger(newTaskShortcutType);
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
    expect(location(tester), AppRoutes.taskEdit(7));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsOneWidget);
  });

  testWidgets('other shortcut types are ignored', (tester) async {
    await harness.pumpApp(tester);

    harness.shortcuts.trigger('something_else');
    await tester.pumpAndSettle();

    expect(find.byType(NewTaskSheet), findsNothing);
  });

  testWidgets('signed out the shortcut is ignored', (tester) async {
    await pumpVikunjaApp(tester, overrides: harness.overrides);

    harness.shortcuts.trigger(newTaskShortcutType);
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.byType(NewTaskSheet), findsNothing);
  });

  testWidgets('during the first sync the shortcut waits for the shell', (
    tester,
  ) async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final sync = SyncFakes(status: const SyncNeverRun());
    final firstSync = Completer<void>();
    sync.engine.onEnsureInitialSync = () => firstSync.future;
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: sync,
      overrides: harness.overrides,
      settle: false,
    );
    await pumpUntil(tester, find.byType(FirstSyncScreen));

    harness.shortcuts.trigger(newTaskShortcutType);
    await pumpFrames(tester, 3);
    expect(find.byType(NewTaskSheet), findsNothing);

    firstSync.complete();
    await tester.pumpAndSettle();
    expect(location(tester), AppRoutes.overview);
    expect(find.byType(NewTaskSheet), findsOneWidget);
  });
}
