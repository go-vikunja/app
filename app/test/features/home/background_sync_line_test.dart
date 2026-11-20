import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/widgets.dart' show Locale, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/application/background_sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final start = DateTime.utc(2026, 10, 13, 12);
  final host = displayHost(fullServer270().rootUri);
  late AuthFakes auth;
  late DateTime now;

  setUp(() {
    auth = AuthFakes();
    now = start;
  });

  Future<String> pumpAccountTab(
    WidgetTester tester, {
    String? lastRun,
    AppLocalizations? l10n,
    bool needsReauth = false,
    Future<void> Function(String accountId)? prepare,
  }) async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: needsReauth,
    );
    if (lastRun != null) {
      await auth.preferences.setString(
        BackgroundRunLog.lastRunAtKey(entry.id),
        lastRun,
      );
    }
    await prepare?.call(entry.id);
    // The banner pushes the Sync section below a test's usual surface,
    // where the list does not build it.
    if (needsReauth) {
      usePhoneSurface(tester, logicalSize: const Size(800, 2400));
    }
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: SyncFakes(now: start),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    await openTab(tester, (l10n ?? en).tabAccount);
    return entry.id;
  }

  testWidgets('says when the background sync has not run yet', (tester) async {
    await pumpAccountTab(tester);

    expect(find.text(en.accountBackgroundSyncNoneSucceeded), findsOneWidget);
    expect(find.text(en.accountBackgroundSyncIosHint), findsNothing);
  });

  testWidgets('on iOS adds that the system decides when it runs', (
    tester,
  ) async {
    await pumpAccountTab(tester);

    expect(find.text(en.accountBackgroundSyncNoneSucceeded), findsOneWidget);
    expect(find.text(en.accountBackgroundSyncIosHint), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('shows how long ago it last ran, without the hint', (
    tester,
  ) async {
    await pumpAccountTab(
      tester,
      lastRun: start.subtract(const Duration(hours: 2)).toIso8601String(),
    );

    expect(
      find.text(en.accountBackgroundSyncSucceeded(en.relativeHoursAgo(2))),
      findsOneWidget,
    );
    expect(find.text(en.accountBackgroundSyncNoneSucceeded), findsNothing);
    expect(find.text(en.accountBackgroundSyncIosHint), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reads the runner’s note again while the app is in front', (
    tester,
  ) async {
    final accountId = await pumpAccountTab(tester);
    expect(find.text(en.accountBackgroundSyncNoneSucceeded), findsOneWidget);

    await auth.preferences.setString(
      BackgroundRunLog.lastRunAtKey(accountId),
      start.toIso8601String(),
    );
    now = start.add(const Duration(seconds: 20));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text(en.accountBackgroundSyncSucceededJustNow), findsOneWidget);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(
      tester,
      lastRun: start.subtract(const Duration(minutes: 5)).toIso8601String(),
      l10n: de,
    );

    expect(
      find.text(de.accountBackgroundSyncSucceeded(de.relativeMinutesAgo(5))),
      findsOneWidget,
    );
  });

  testWidgets('in German, a failed attempt is never under the old words '
      'that the background sync has not run yet (D59)', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(
      tester,
      l10n: de,
      prepare: (accountId) =>
          BackgroundRunLog(auth.preferences).recordAccountOutcome(
            accountId,
            BackgroundAccountOutcome.unreachable,
            at: start.subtract(const Duration(hours: 1)),
          ),
    );

    expect(find.text(de.accountBackgroundSyncNoneSucceeded), findsOneWidget);
    expect(find.textContaining('lief noch nicht'), findsNothing);
  });

  group('what went wrong (D59)', () {
    BackgroundRunLog log() => BackgroundRunLog(auth.preferences);

    String ago(DateTime at) => formatRelativeTime(en, at, now: start);

    testWidgets('an attempt that failed after the last success shows how it '
        'ended', (tester) async {
      await pumpAccountTab(
        tester,
        lastRun: start.subtract(const Duration(hours: 3)).toIso8601String(),
        prepare: (accountId) => log().recordAccountOutcome(
          accountId,
          BackgroundAccountOutcome.unreachable,
          at: start.subtract(const Duration(hours: 1)),
        ),
      );

      expect(
        find.text(
          en.accountBackgroundTurn(
            en.relativeHoursAgo(1),
            en.accountBackgroundTurnUnreachable,
          ),
        ),
        findsOneWidget,
      );
    });

    // Android's raw WorkInfo numbers, which workmanager_android passes
    // through and workmanager's StopReason names otherwise.
    for (final (reason, text) in [
      (3, en.accountBackgroundTurnStoppedTimeout),
      (4, en.accountBackgroundTurnStoppedDeviceState),
      (5, en.accountBackgroundTurnStoppedBatteryLow),
      (7, en.accountBackgroundTurnStoppedConnectivity),
      // Below Android 12, and from 10 on, the plugin reports 0; the others
      // say nothing a user can act on.
      (0, en.accountBackgroundTurnStopped),
      (1, en.accountBackgroundTurnStopped),
      (2, en.accountBackgroundTurnStopped),
      (8, en.accountBackgroundTurnStopped),
      (9, en.accountBackgroundTurnStopped),
      (null, en.accountBackgroundTurnOutOfTime),
    ]) {
      testWidgets('a stop for reason $reason reads as the system meant it', (
        tester,
      ) async {
        await pumpAccountTab(
          tester,
          prepare: (accountId) => log().recordAccountOutcome(
            accountId,
            BackgroundAccountOutcome.stopped,
            at: start.subtract(const Duration(hours: 1)),
            stopReason: reason,
          ),
        );

        expect(
          find.text(en.accountBackgroundTurn(en.relativeHoursAgo(1), text)),
          findsOneWidget,
        );
      });
    }

    testWidgets("the run's own deadline is not told as the system's stop", (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => log().recordAccountOutcome(
          accountId,
          BackgroundAccountOutcome.stopped,
          at: start.subtract(const Duration(hours: 1)),
        ),
      );

      expect(find.textContaining('by the system'), findsNothing);
    });

    for (final (outcome, text, needsReauth) in [
      (
        BackgroundAccountOutcome.deferred,
        en.accountBackgroundTurnDeferred,
        false,
      ),
      (
        BackgroundAccountOutcome.storageUnreadable,
        en.accountBackgroundTurnStorageUnreadable,
        false,
      ),
      (
        BackgroundAccountOutcome.sessionEnded,
        en.accountBackgroundTurnSessionEnded,
        true,
      ),
      (
        BackgroundAccountOutcome.signInNeeded,
        en.accountBackgroundTurnSignInNeeded,
        true,
      ),
    ]) {
      testWidgets('${outcome.name} is told as such', (tester) async {
        await pumpAccountTab(
          tester,
          needsReauth: needsReauth,
          prepare: (accountId) => log().recordAccountOutcome(
            accountId,
            outcome,
            at: start.subtract(const Duration(hours: 1)),
          ),
        );

        expect(
          find.text(en.accountBackgroundTurn(en.relativeHoursAgo(1), text)),
          findsOneWidget,
        );
        expect(find.textContaining('server not reachable'), findsNothing);
      });
    }

    group('after a new sign-in', () {
      final endedAt = start.subtract(const Duration(hours: 2));
      Future<void> endedBefore(String accountId) =>
          SessionDiagnostics(auth.preferences).recordEnd(
            accountId,
            SessionEndDiagnosis(
              at: endedAt,
              cause: SessionEndCause.storageUnreadable,
              part: AppPart.app,
              resolution: SessionEndResolution.noTokens,
            ),
          );

      for (final (outcome, at, text) in [
        (
          BackgroundAccountOutcome.signInNeeded,
          start.subtract(const Duration(hours: 1)),
          en.accountBackgroundTurnSignInNeeded,
        ),
        (
          BackgroundAccountOutcome.sessionEnded,
          endedAt.add(const Duration(seconds: 5)),
          en.accountBackgroundTurnSessionEnded,
        ),
        (
          BackgroundAccountOutcome.storageUnreadable,
          start.subtract(const Duration(hours: 3)),
          en.accountBackgroundTurnStorageUnreadable,
        ),
      ]) {
        testWidgets('a turn of the ended session (${outcome.name}) is no '
            'longer shown', (tester) async {
          await pumpAccountTab(
            tester,
            prepare: (accountId) async {
              await endedBefore(accountId);
              await log().recordAccountOutcome(accountId, outcome, at: at);
            },
          );

          expect(
            find.textContaining(en.accountLastSessionEnd(ago(endedAt))),
            findsOneWidget,
          );
          expect(
            find.text(en.accountBackgroundTurn(ago(at), text)),
            findsNothing,
          );
        });
      }

      testWidgets('a turn that failed since is shown', (tester) async {
        await pumpAccountTab(
          tester,
          prepare: (accountId) async {
            await endedBefore(accountId);
            await log().recordAccountOutcome(
              accountId,
              BackgroundAccountOutcome.unreachable,
              at: start.subtract(const Duration(hours: 1)),
            );
          },
        );

        expect(
          find.text(
            en.accountBackgroundTurn(
              en.relativeHoursAgo(1),
              en.accountBackgroundTurnUnreachable,
            ),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('a session that ended on its own is not told as ended by '
        'the server', (tester) async {
      await pumpAccountTab(
        tester,
        needsReauth: true,
        prepare: (accountId) => log().recordAccountOutcome(
          accountId,
          BackgroundAccountOutcome.sessionEnded,
          at: start.subtract(const Duration(hours: 1)),
        ),
      );

      expect(find.textContaining('server ended'), findsNothing);
    });

    testWidgets('an attempt less than a minute ago reads just now', (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => log().recordAccountOutcome(
          accountId,
          BackgroundAccountOutcome.unreachable,
          at: start.subtract(const Duration(seconds: 10)),
        ),
      );

      expect(
        find.text(
          en.accountBackgroundTurnJustNow(en.accountBackgroundTurnUnreachable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed attempt before the last success is not shown', (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        lastRun: start.subtract(const Duration(hours: 1)).toIso8601String(),
        prepare: (accountId) => log().recordAccountOutcome(
          accountId,
          BackgroundAccountOutcome.failed,
          at: start.subtract(const Duration(hours: 3)),
        ),
      );

      expect(find.textContaining(en.accountBackgroundTurnFailed), findsNothing);
    });

    testWidgets('a day without any background run asks to let it run', (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        prepare: (_) => log().recordResult(
          BackgroundRunOutcome.completed,
          start.subtract(const Duration(hours: 25)),
        ),
      );

      expect(find.text(en.accountBackgroundSyncIdle), findsOneWidget);
    });

    testWidgets('no background run at all a day after the account was '
        'added asks to let it run', (tester) async {
      await pumpAccountTab(tester);

      expect(find.text(en.accountBackgroundSyncIdle), findsOneWidget);
    });

    testWidgets('an account added within the day is not told yet', (
      tester,
    ) async {
      now = DateTime.utc(2026, 10, 1, 6);

      await pumpAccountTab(tester);

      expect(find.text(en.accountBackgroundSyncIdle), findsNothing);
    });

    testWidgets('a run within the day asks for nothing', (tester) async {
      await pumpAccountTab(
        tester,
        prepare: (_) => log().recordResult(
          BackgroundRunOutcome.skipped,
          start.subtract(const Duration(hours: 2)),
        ),
      );

      expect(find.text(en.accountBackgroundSyncIdle), findsNothing);
    });

    final endedAt = start.subtract(const Duration(days: 2));
    final lostAt = endedAt.subtract(const Duration(hours: 1));
    SessionEndDiagnosis record({SessionEndResolution? resolution}) =>
        SessionEndDiagnosis(
          at: endedAt,
          cause: SessionEndCause.refreshRejected,
          part: AppPart.backgroundRun,
          code: 16002,
          lostRefreshAt: lostAt,
          lostRefreshPart: AppPart.backgroundRun,
          resolution: resolution,
        );

    testWidgets('the last ended session is told after the new sign-in, with '
        'what became of it', (tester) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          record(resolution: SessionEndResolution.orphanRevoked),
        ),
      );

      expect(
        find.text(
          [
            en.accountLastSessionEnd(ago(endedAt)),
            en.sessionEndCauseLostAnswer(ago(lostAt)),
            en.sessionEndCode(16002),
            en.sessionEndResolvedOrphan,
          ].join(' '),
        ),
        findsOneWidget,
      );
    });

    for (final (what, diagnosis) in [
      (
        'missing tokens',
        SessionEndDiagnosis(
          at: endedAt,
          cause: SessionEndCause.missingTokens,
          part: AppPart.app,
          resolution: SessionEndResolution.noTokens,
        ),
      ),
      (
        'unreadable storage',
        SessionEndDiagnosis(
          at: endedAt,
          cause: SessionEndCause.storageUnreadable,
          part: AppPart.app,
          resolution: SessionEndResolution.restored,
        ),
      ),
      (
        'a live session ended by mistake',
        record(resolution: SessionEndResolution.wasAlive),
      ),
    ]) {
      testWidgets('an end after $what is not told as a sign-out by the '
          'server', (tester) async {
        await pumpAccountTab(
          tester,
          prepare: (accountId) =>
              SessionDiagnostics(auth.preferences)
                  .recordEnd(accountId, diagnosis),
        );

        expect(
          find.textContaining(en.accountLastSessionEnd(ago(endedAt))),
          findsOneWidget,
        );
        expect(find.textContaining('by the server'), findsNothing);
      });
    }

    for (final (what, resolution, text) in [
      (
        'works again without a sign-in',
        SessionEndResolution.restored,
        en.sessionEndResolvedRestored,
      ),
      (
        'still worked',
        SessionEndResolution.wasAlive,
        en.sessionEndResolvedAlive,
      ),
    ]) {
      testWidgets('a session that $what says so, without a lost answer', (
        tester,
      ) async {
        await pumpAccountTab(
          tester,
          prepare: (accountId) =>
              SessionDiagnostics(auth.preferences)
                  .recordEnd(accountId, record(resolution: resolution)),
        );

        expect(
          find.text(
            [
              en.accountLastSessionEnd(ago(endedAt)),
              en.sessionEndCauseRefreshRejected,
              en.sessionEndCode(16002),
              text,
            ].join(' '),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('a session that ended less than a minute ago reads just now '
        'in the Sync section, as does the lost answer', (tester) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: start.subtract(const Duration(seconds: 10)),
            cause: SessionEndCause.refreshRejected,
            part: AppPart.backgroundRun,
            code: 16002,
            lostRefreshAt: start.subtract(const Duration(seconds: 20)),
            lostRefreshPart: AppPart.backgroundRun,
            resolution: SessionEndResolution.orphanRevoked,
          ),
        ),
      );

      expect(
        find.text(
          [
            en.accountLastSessionEndJustNow,
            en.sessionEndCauseLostAnswerJustNow,
            en.sessionEndCode(16002),
            en.sessionEndResolvedOrphan,
          ].join(' '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a session deleted on the server is not told as a lost '
        'answer', (tester) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          record(resolution: SessionEndResolution.goneOnServer),
        ),
      );

      expect(
        find.text(
          [
            en.accountLastSessionEnd(ago(endedAt)),
            en.sessionEndCauseRefreshRejected,
            en.sessionEndCode(16002),
            en.sessionEndResolvedGone,
          ].join(' '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the window of two weeks counts from the end, not from the '
        'sign-in', (tester) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: start.subtract(const Duration(days: 13)),
            cause: SessionEndCause.sessionExpired,
            part: AppPart.app,
            resolution: SessionEndResolution.goneOnServer,
          ),
        ),
      );

      expect(find.textContaining(en.sessionEndCauseExpired), findsOneWidget);
    });

    testWidgets('an ended session two weeks back is no longer told', (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: start.subtract(const Duration(days: 15)),
            cause: SessionEndCause.sessionExpired,
            part: AppPart.app,
          ),
        ),
      );

      expect(find.textContaining(en.sessionEndCauseExpired), findsNothing);
    });

    testWidgets('while the account waits for a sign-in, the banner tells why', (
      tester,
    ) async {
      await pumpAccountTab(
        tester,
        needsReauth: true,
        prepare: (accountId) =>
            SessionDiagnostics(auth.preferences).recordEnd(accountId, record()),
      );

      final reason = [
        en.reauthEndedAt(ago(endedAt)),
        en.sessionEndCauseLostAnswer(ago(lostAt)),
        en.sessionEndCode(16002),
      ].join(' ');
      expect(
        find.descendant(
          of: find.byType(ReauthBanner),
          matching: find.text(reason),
        ),
        findsOneWidget,
      );
      expect(find.text(en.reauthTitle), findsOneWidget);
      expect(find.text(en.reauthBody(host)), findsOneWidget);
      expect(
        find.textContaining(en.accountLastSessionEnd(ago(endedAt))),
        findsNothing,
      );
    });

    for (final cause in [
      SessionEndCause.storageUnreadable,
      SessionEndCause.missingTokens,
    ]) {
      testWidgets('an end on the device (${cause.name}) is not told as a '
          'sign-out by the server', (tester) async {
        await pumpAccountTab(
          tester,
          needsReauth: true,
          prepare: (accountId) => SessionDiagnostics(auth.preferences)
              .recordEnd(
                accountId,
                SessionEndDiagnosis(
                  at: endedAt,
                  cause: cause,
                  part: AppPart.app,
                ),
              ),
        );

        expect(find.byType(ReauthBanner), findsOneWidget);
        expect(find.text(en.reauthTitleOnDevice), findsOneWidget);
        expect(find.text(en.reauthBodyOnDevice(host)), findsOneWidget);
        expect(find.text(en.reauthTitle), findsNothing);
        expect(find.text(en.reauthBody(host)), findsNothing);
      });
    }

    group('the banner of an end on the device has its final words from '
        'its first frame, so its live region is announced once', () {
      Future<void> expectOnlyDeviceWording(WidgetTester tester) async {
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump();
          expect(find.text(en.reauthTitle), findsNothing, reason: '$frame');
          expect(find.text(en.reauthBody(host)), findsNothing);
        }
        expect(find.text(en.reauthTitleOnDevice), findsOneWidget);
        expect(find.text(en.reauthBodyOnDevice(host)), findsOneWidget);
      }

      SessionEndDiagnosis onDevice() => SessionEndDiagnosis(
        at: start.subtract(const Duration(minutes: 3)),
        cause: SessionEndCause.storageUnreadable,
        part: AppPart.app,
      );

      testWidgets('when the tab opens', (tester) async {
        final entry = await auth.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
          needsReauth: true,
        );
        await SessionDiagnostics(auth.preferences)
            .recordEnd(entry.id, onDevice());
        usePhoneSurface(tester, logicalSize: const Size(800, 2400));
        await pumpVikunjaApp(
          tester,
          auth: auth,
          sync: SyncFakes(now: start),
          overrides: [clockProvider.overrideWithValue(() => now)],
        );

        await tester.tap(find.text(en.tabAccount));
        await expectOnlyDeviceWording(tester);
      });

      testWidgets('a record that cannot be read leaves the server wording, '
          'not an empty space', (tester) async {
        await auth.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
          needsReauth: true,
        );
        usePhoneSurface(tester, logicalSize: const Size(800, 2400));
        await pumpVikunjaApp(
          tester,
          auth: auth,
          sync: SyncFakes(now: start),
          overrides: [
            clockProvider.overrideWithValue(() => now),
            markedSessionEndProvider.overrideWith(
              (ref, accountId) async => throw StateError('preferences'),
            ),
          ],
        );
        await openTab(tester, en.tabAccount);

        expect(find.text(en.reauthTitle), findsOneWidget);
        expect(find.text(en.reauthBody(host)), findsOneWidget);
      });

      testWidgets('when the session ends while the tab is open, also with '
          'the record read before the end', (tester) async {
        final accountId = await pumpAccountTab(tester);
        expect(find.byType(ReauthBanner), findsNothing);
        final read = containerOf(tester)
            .listen(markedSessionEndProvider(accountId), (_, _) {});
        addTearDown(read.close);
        await tester.pump();
        expect(read.read().value, (needsReauth: false, end: null));

        // As a session manager does: the record first, then the mark.
        await SessionDiagnostics(auth.preferences)
            .recordEnd(accountId, onDevice());
        await containerOf(tester)
            .read(accountRegistryProvider)
            .markNeedsReauth(accountId);
        await expectOnlyDeviceWording(tester);
      });
    });

    testWidgets('a record that a sign-in resolved belongs to an earlier '
        'end: the banner tells no reason from it', (tester) async {
      await pumpAccountTab(
        tester,
        needsReauth: true,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: endedAt,
            cause: SessionEndCause.storageUnreadable,
            part: AppPart.app,
            resolution: SessionEndResolution.noTokens,
          ),
        ),
      );

      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.textContaining(en.reauthEndedAt(ago(endedAt))), findsNothing);
      expect(
        find.textContaining(en.sessionEndCauseStorageUnreadable),
        findsNothing,
      );
      expect(find.text(en.reauthTitle), findsOneWidget);
    });

    testWidgets('the time in the banner ticks outside its live region, which '
        'is announced only when it appears', (tester) async {
      final semantics = tester.ensureSemantics();
      final ended = start.subtract(const Duration(minutes: 5));
      final lost = start.subtract(const Duration(minutes: 6));
      await pumpAccountTab(
        tester,
        needsReauth: true,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: ended,
            cause: SessionEndCause.refreshRejected,
            part: AppPart.backgroundRun,
            code: 16002,
            lostRefreshAt: lost,
            lostRefreshPart: AppPart.backgroundRun,
          ),
        ),
      );
      String reasonAt(DateTime now) => [
        en.reauthEndedAt(formatRelativeTime(en, ended, now: now)),
        en.sessionEndCauseLostAnswer(formatRelativeTime(en, lost, now: now)),
        en.sessionEndCode(16002),
      ].join(' ');
      SemanticsNode liveRegion() {
        final node = tester.getSemantics(find.text(en.reauthTitle));
        expect(node.flagsCollection.isLiveRegion, isTrue);
        return node;
      }

      final before = liveRegion().label;
      expect(before, contains(en.reauthBody(host)));
      expect(before, isNot(contains(reasonAt(start))));
      expect(
        tester.getSemantics(find.text(reasonAt(start))).label,
        reasonAt(start),
      );

      now = start.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(find.text(reasonAt(now)), findsOneWidget);
      expect(reasonAt(now), isNot(reasonAt(start)));
      expect(liveRegion().label, before);
      semantics.dispose();
    });

    testWidgets('a session that ended less than a minute ago reads just '
        'now in the banner', (tester) async {
      await pumpAccountTab(
        tester,
        needsReauth: true,
        prepare: (accountId) => SessionDiagnostics(auth.preferences).recordEnd(
          accountId,
          SessionEndDiagnosis(
            at: start.subtract(const Duration(seconds: 10)),
            cause: SessionEndCause.refreshRejected,
            part: AppPart.app,
            code: 16002,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(ReauthBanner),
          matching: find.text(
            [
              en.reauthEndedJustNow,
              en.sessionEndCauseRefreshRejected,
              en.sessionEndCode(16002),
            ].join(' '),
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
