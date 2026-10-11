import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

// The screen's indeterminate progress bar never settles, so these tests pump
// frames until what they expect is there. The completers that hold a run
// open are created inside the test bodies: one from setUp would complete
// outside the test's fake async zone and never reach the engine.
void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  late Completer<void> run;

  setUp(() {
    data = SyncFakes(now: now, status: const SyncNeverRun());
  });

  /// Signed in with a never-synced account, on the first-sync screen with
  /// the run held open by [run].
  Future<AuthFakes> pumpFirstSync(WidgetTester tester) async {
    run = Completer<void>();
    data.engine.onEnsureInitialSync = () => run.future;
    final auth = await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      settle: false,
    );
    await pumpUntil(tester, find.text(en.syncPhaseAccount));
    return auth;
  }

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget(find.byType(LinearProgressIndicator));

  testWidgets('a new account starts on the first-sync screen, which starts '
      'the sync', (tester) async {
    await pumpFirstSync(tester);

    expect(location(tester), AppRoutes.firstSync);
    expect(find.byType(FirstSyncScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.text(en.firstSyncTitle), findsOneWidget);
    expect(find.text(en.firstSyncBody('tasks.example.org')), findsOneWidget);
    expect(data.engine.ensureInitialSyncCalls, 1);
    expect(data.engine.refreshCalls, 0);
    expect(bar(tester).value, isNull);
  });

  testWidgets('shows the phase, the counts and the progress', (tester) async {
    await pumpFirstSync(tester);

    data.engine.emit(
      const SyncRunning(
        phase: SyncPhase.tasks,
        done: 30,
        total: 120,
        initial: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.syncPhaseTasks), findsOneWidget);
    expect(find.text(en.syncProgressOfTotal(30, 120)), findsOneWidget);
    expect(bar(tester).value, 0.25);
    expect(bar(tester).semanticsLabel, isNull);

    data.engine.emit(
      const SyncRunning(phase: SyncPhase.archivedTasks, done: 7, initial: true),
    );
    await pumpFrames(tester, 3);

    expect(find.text(en.syncPhaseArchivedTasks), findsOneWidget);
    expect(find.text(en.syncProgressCount(7)), findsOneWidget);
    expect(bar(tester).value, isNull);
  });

  testWidgets('goes to the shell when the sync completes, without a second '
      'pull', (tester) async {
    await pumpFirstSync(tester);

    run.complete();
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(FirstSyncScreen), findsNothing);
    expect(location(tester), AppRoutes.overview);
    expect(data.engine.refreshCalls, 0);
  });

  testWidgets('a failure is explained and retried from the checkpoint', (
    tester,
  ) async {
    await pumpFirstSync(tester);

    run.completeError(const NetworkFailure(NetworkProblem.unreachable));
    await tester.pumpAndSettle();

    expect(find.byType(FirstSyncScreen), findsOneWidget);
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.failureUnreachableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final retry = Completer<void>();
    data.engine.onEnsureInitialSync = () => retry.future;
    await tester.ensureVisible(find.text(en.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.retry));
    await pumpUntil(tester, find.text(en.syncPhaseAccount));

    expect(data.engine.ensureInitialSyncCalls, 2);
    expect(find.byType(DataFailureCard), findsNothing);

    retry.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('a restart with an unfinished first run resumes it', (
    tester,
  ) async {
    data = SyncFakes(
      now: now,
      status: const SyncFailed(
        failure: NetworkFailure(NetworkProblem.timeout),
        lastSyncedAt: null,
      ),
    );

    await pumpFirstSync(tester);

    expect(find.byType(FirstSyncScreen), findsOneWidget);
    expect(data.engine.ensureInitialSyncCalls, 1);
  });

  testWidgets('cancel signs out after confirming and deletes the local data', (
    tester,
  ) async {
    final auth = await pumpFirstSync(tester);
    final accountId = (await auth.registry.load()).activeAccountId;

    await tester.tap(find.text(en.firstSyncCancel));
    await pumpUntil(tester, find.text(en.signOutDialogTitle));
    expect(
      find.text(
        en.signOutDialogBody(
          en.signOutDialogAccount('Alice Example', 'alice'),
          'tasks.example.org',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(auth.secureStore.values, isEmpty);
    expect((await auth.registry.load()).accounts, isEmpty);
    expect(data.files.deleted, [accountId]);
    expect(data.engine.disposed, isTrue);
  });

  testWidgets('cancelling the dialog keeps the sync going', (tester) async {
    await pumpFirstSync(tester);

    await tester.tap(find.text(en.firstSyncCancel));
    await pumpUntil(tester, find.text(en.signOutDialogCancel));
    await tester.tap(find.text(en.signOutDialogCancel));
    await pumpFrames(tester, 3);

    expect(find.text(en.signOutDialogTitle), findsNothing);
    expect(find.byType(FirstSyncScreen), findsOneWidget);
    expect(data.files.deleted, isEmpty);

    run.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('the phase is one live region with the counts as its value, '
      'and the title a heading', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpFirstSync(tester);

    expect(
      tester.getSemantics(find.text(en.firstSyncTitle)),
      matchesSemantics(label: en.firstSyncTitle, isHeader: true),
    );
    expect(
      tester.getSemantics(find.text(en.syncPhaseAccount)),
      matchesSemantics(label: en.syncPhaseAccount, isLiveRegion: true),
    );

    data.engine.emit(
      const SyncRunning(
        phase: SyncPhase.tasks,
        done: 30,
        total: 120,
        initial: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text(en.syncPhaseTasks)),
      matchesSemantics(
        label: en.syncPhaseTasks,
        value: en.syncProgressOfTotal(30, 120),
        isLiveRegion: true,
      ),
    );
    // Neither the bar nor the counts text repeats the phase or the counts.
    expect(find.bySemanticsLabel(en.syncPhaseTasks), findsOneWidget);
    expect(
      find.bySemanticsLabel(en.syncProgressOfTotal(30, 120)),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('a failure that is no server answer is explained and can be '
      'retried', (tester) async {
    await pumpFirstSync(tester);

    run.completeError(StateError('unreadable database'));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.dataFailureUnexpected('tasks.example.org')),
      findsOneWidget,
    );
    expect(find.text(en.retry), findsOneWidget);
  });

  group('session ended', () {
    /// Signed in, on the first-sync screen, with a connector and user for a
    /// sign-in again.
    Future<AuthFakes> pumpWithReauth(
      WidgetTester tester, {
      bool needsReauth = false,
    }) async {
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now.toUtc()),
        needsReauth: needsReauth,
      );
      auth.serveUser(
        const User(id: 7, username: 'alice', name: 'Alice Example'),
        now: now,
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        connector: FakeServerConnector.succeeding(fullServer270()),
        sync: data,
        overrides: [clockProvider.overrideWithValue(() => now)],
        settle: false,
      );
      return auth;
    }

    testWidgets('a run that ends the session asks for a new sign-in instead '
        'of a retry, and syncs after it', (tester) async {
      run = Completer<void>();
      data.engine.onEnsureInitialSync = () => run.future;
      await pumpWithReauth(tester);
      await pumpUntil(tester, find.text(en.syncPhaseAccount));

      run.completeError(
        const SessionEnded(SessionEndReason.expired, code: 16003),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FirstSyncScreen), findsOneWidget);
      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.byType(DataFailureCard), findsNothing);
      expect(find.text(en.retry), findsNothing);
      expect(find.text(en.firstSyncCancel), findsOneWidget);

      final retry = Completer<void>();
      data.engine.onEnsureInitialSync = () => retry.future;
      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await pumpUntil(tester, find.text(en.syncPhaseAccount));

      expect(find.byType(ReauthBanner), findsNothing);
      expect(data.engine.ensureInitialSyncCalls, 2);

      retry.complete();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('an account that already needs a new sign-in gets the banner '
        'before any run', (tester) async {
      data.engine.onEnsureInitialSync = () => Completer<void>().future;
      await pumpWithReauth(tester, needsReauth: true);
      await pumpUntil(tester, find.byType(ReauthBanner));

      expect(find.byType(FirstSyncScreen), findsOneWidget);
      expect(find.byType(DataFailureCard), findsNothing);
      expect(data.engine.ensureInitialSyncCalls, 0);
    });
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    data.engine.onEnsureInitialSync = () => Completer<void>().future;
    await pumpSignedInApp(tester, sync: data, now: now, settle: false);
    await pumpUntil(tester, find.text(de.syncPhaseAccount));

    expect(find.text(de.firstSyncTitle), findsOneWidget);
    expect(find.text(de.firstSyncCancel), findsOneWidget);
  });

  testWidgets('home is not reachable before the first sync', (tester) async {
    await pumpFirstSync(tester);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.projects);
    await pumpFrames(tester, 3);

    expect(location(tester), AppRoutes.firstSync);
    expect(find.byType(FirstSyncScreen), findsOneWidget);
  });

  testWidgets('the first-sync route needs an account', (tester) async {
    await pumpVikunjaApp(tester, auth: AuthFakes());

    containerOf(tester).read(appRouterProvider).go(AppRoutes.firstSync);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
  });

  testWidgets('a synced account skips the screen', (tester) async {
    await pumpSignedInApp(
      tester,
      sync: SyncFakes(now: now),
      now: now,
    );

    containerOf(tester).read(appRouterProvider).go(AppRoutes.firstSync);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(HomeShell), findsOneWidget);
  });
}
