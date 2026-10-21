import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final twoHoursAgo = now.subtract(const Duration(hours: 2));
  const unreachable = NetworkFailure(NetworkProblem.unreachable);
  final offline = SyncFailed(failure: unreachable, lastSyncedAt: twoHoursAgo);
  const running = SyncRunning(phase: SyncPhase.tasks, done: 1, initial: false);

  group('offlineAfter', () {
    final state = OfflineState(lastSyncedAt: twoHoursAgo);

    test('a run that cannot reach the server is offline', () {
      expect(offlineAfter(null, offline), state);
    });

    test('a run in progress or no status yet keeps the last outcome', () {
      expect(offlineAfter(state, running), state);
      expect(offlineAfter(state, null), state);
      expect(offlineAfter(null, running), isNull);
    });

    test('a run that gets through, or fails on the server, is online', () {
      expect(offlineAfter(state, SyncIdle(lastSyncedAt: now)), isNull);
      expect(
        offlineAfter(
          state,
          SyncFailed(failure: const ServerFailure(502), lastSyncedAt: now),
        ),
        isNull,
      );
      expect(offlineAfter(state, const SyncNeverRun()), isNull);
    });
  });

  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [sampleTask(id: 1, title: 'Saved task')];
  });

  final bannerText = find.textContaining(en.offlineNotice, findRichText: true);

  Future<void> goOffline(WidgetTester tester) async {
    data.engine.emit(offline);
    await tester.pumpAndSettle();
  }

  testWidgets('a sync that cannot reach the server shows the strip above '
      'the bar with the last sync; a retry keeps it, a run that gets '
      'through takes it away', (tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    expect(bannerText, findsNothing);

    await goOffline(tester);
    expect(bannerText, findsOneWidget);
    expect(
      find.textContaining(
        en.accountLastSynced(en.relativeHoursAgo(2)),
        findRichText: true,
      ),
      findsOneWidget,
    );
    final banner = tester.getRect(find.byType(OfflineBanner));
    expect(banner.bottom, tester.getRect(find.byType(NavigationBar)).top);
    expect(banner.width, phoneSize.width);
    expect(find.text('Saved task'), findsOneWidget);

    data.engine.emit(running);
    await tester.pump();
    expect(bannerText, findsOneWidget);
    expect(
      find.textContaining(
        en.accountLastSynced(en.relativeHoursAgo(2)),
        findRichText: true,
      ),
      findsOneWidget,
    );

    data.engine.emit(SyncIdle(lastSyncedAt: now));
    await tester.pumpAndSettle();
    expect(bannerText, findsNothing);
  });

  testWidgets('beside the rail it takes the bottom of the content', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(800, 600));
    await pumpSignedInApp(tester, sync: data, now: now);

    await goOffline(tester);

    final banner = tester.getRect(find.byType(OfflineBanner));
    expect(banner.left, tester.getRect(find.byType(NavigationRail)).right);
    expect(banner.right, 800);
    expect(banner.bottom, 600);
  });

  testWidgets('a tap syncs now; while the run is going a tap does nothing', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    await goOffline(tester);
    final run = Completer<void>();
    data.engine.onRefresh = () => run.future;

    await tester.tap(find.byType(OfflineBanner));
    await tester.pump();
    expect(data.engine.refreshCalls, 1);
    expect(bannerText, findsOneWidget);

    await tester.tap(find.byType(OfflineBanner));
    await tester.pump();
    expect(data.engine.refreshCalls, 1);

    run.complete();
    await tester.pumpAndSettle();
    expect(bannerText, findsNothing);
  });

  testWidgets('a tap does nothing while the account signs out, as Sync now '
      'in the Account tab', (tester) async {
    usePhoneSurface(tester);
    final auth = await pumpSignedInApp(tester, sync: data, now: now);
    await goOffline(tester);
    final logout = Completer<void>();
    auth.accountGateway.onLogout = (_) => logout.future;
    final accountId = (await auth.registry.load()).activeAccountId!;

    unawaited(
      containerOf(tester)
          .read(signOutControllerProvider.notifier)
          .signOut(accountId),
    );
    await tester.pump();
    expect(bannerText, findsOneWidget);
    await tester.tap(find.byType(OfflineBanner));
    await tester.pump();

    expect(data.engine.refreshCalls, 0);
    logout.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap does nothing once the session ended; screen readers '
      'hear it disabled', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhoneSurface(tester);
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: true,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    await goOffline(tester);

    await tester.tap(find.byType(OfflineBanner));
    await tester.pump();

    expect(data.engine.refreshCalls, 0);
    expect(
      tester.getSemantics(find.byType(OfflineBanner)),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('offline after a refresh, still offline when it fails again', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    data.engine.onRefresh = () async => throw unreachable;

    await pullToRefresh(tester, find.byType(CustomScrollView));
    expect(bannerText, findsOneWidget);

    await tester.tap(find.byType(OfflineBanner));
    await tester.pumpAndSettle();
    expect(data.engine.refreshCalls, 2);
    expect(bannerText, findsOneWidget);
  });

  testWidgets('the lists show no offline notice of their own beside it', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    data.engine.onRefresh = () async => throw unreachable;

    await pullToRefresh(tester, find.byType(CustomScrollView));
    expect(bannerText, findsOneWidget);
    expect(find.byType(OfflineNotice), findsNothing);

    await openTab(tester, en.tabProjects);
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.refresh));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(bannerText, findsOneWidget);
    expect(find.byType(OfflineNotice), findsNothing);
  });

  testWidgets('a sync the server fails is no reason for it', (tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);

    data.engine.emit(
      SyncFailed(failure: const ServerFailure(502), lastSyncedAt: now),
    );
    await tester.pumpAndSettle();

    expect(bannerText, findsNothing);
  });

  testWidgets("it follows the active account: the other account's last run "
      'decides', (tester) async {
    usePhoneSurface(tester);
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    data.accounts[bob.id] = AccountDataFakes(now: now);
    await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
    await goOffline(tester);

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();

    expect(bannerText, findsNothing);
  });

  testWidgets('screen readers hear it once when it appears; the time is its '
      'value and Sync now its action', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    await goOffline(tester);

    final node = tester.getSemantics(find.byType(OfflineBanner));
    expect(
      node,
      isSemantics(
        label: en.offlineNotice,
        value: en.accountLastSynced(en.relativeHoursAgo(2)),
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isLiveRegion: true,
        hasTapAction: true,
        onTapHint: en.accountSyncNow,
      ),
    );

    // While the run it starts is going, a tap does nothing.
    final run = Completer<void>();
    data.engine.onRefresh = () => run.future;
    await tester.tap(find.byType(OfflineBanner));
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(OfflineBanner)),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    run.complete();
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('its tap target is at least 48 dp tall, also on one line', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(1400, 800));
    await pumpSignedInApp(tester, sync: data, now: now);
    await goOffline(tester);

    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(OfflineBanner),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);

    await goOffline(tester);

    expect(
      find.textContaining(de.offlineNotice, findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        de.accountLastSynced(de.relativeHoursAgo(2)),
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
