import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);
  late AuthFakes auth;
  late FakeBackgroundScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    scheduler = FakeBackgroundScheduler();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        backgroundSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);
  });

  test('registered while an account is signed in, cancelled after the last '
      'sign-out', () async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await container.read(accountsProvider.future);

    container.listen(backgroundRegistrationProvider, (_, _) {});
    await pumpEventQueue();
    expect(scheduler.calls, ['register']);

    await container.read(accountRegistryProvider).markNeedsReauth(entry.id);
    await pumpEventQueue();
    expect(scheduler.calls, ['register']);

    await container.read(accountRegistryProvider).remove(entry.id);
    await pumpEventQueue();
    expect(scheduler.calls, ['register', 'cancel']);
  });

  test('without accounts at start, whatever an earlier install left is '
      'cancelled', () async {
    await container.read(accountsProvider.future);

    container.listen(backgroundRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    expect(scheduler.calls, ['cancel']);
  });

  test('a failing scheduler does not break the provider', () async {
    scheduler.failure = Exception('not initialised');
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    await container.read(accountsProvider.future);

    container.listen(backgroundRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    expect(scheduler.calls, ['register']);
  });

  testWidgets('the heartbeat beats while the app is visible, not while it '
      'is hidden', (tester) async {
    final heartbeats = ProviderContainer(
      overrides: [
        ...auth.overrides,
        clockProvider.overrideWithValue(() => now),
      ],
    );
    final heartbeat = heartbeats.read(foregroundHeartbeatProvider);
    await tester.pump();
    expect(heartbeat.isBeating, isTrue);
    expect(await BackgroundRunLog(auth.preferences).lastHeartbeat(), now);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(heartbeat.isBeating, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(heartbeat.isBeating, isTrue);

    heartbeats.dispose();
    expect(heartbeat.isBeating, isFalse);
  });

  group('BackgroundRunLog', () {
    test(
      'round-trips the heartbeat, the account runs and the result',
      () async {
        final log = BackgroundRunLog(auth.preferences);

        await log.beat(now);
        await log.recordAccountRun('a1', now);
        await log.recordAttempt('a1', now);
        await log.recordResult(BackgroundRunOutcome.partial, now);

        expect(await log.lastHeartbeat(), now);
        expect(await log.lastRunAt('a1'), now);
        expect(
          auth.preferences.values['background.lastRunAt.a1'],
          '2026-10-13T12:00:00.000Z',
        );
        expect(await log.lastResult(), (
          outcome: BackgroundRunOutcome.partial,
          at: now,
        ));
        expect(await log.lastAttemptAt('a1'), now);
        await log.forget('a1');
        expect(await log.lastRunAt('a1'), isNull);
        expect(await log.lastAttemptAt('a1'), isNull);
      },
    );

    test('an unreadable result counts as none', () async {
      auth.preferences.values[BackgroundRunLog.lastRunResultKey] = 'garbage';

      expect(await BackgroundRunLog(auth.preferences).lastResult(), isNull);
    });
  });
}
