import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/realtime_connection_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

/// Begins a sign-out and never ends it.
final class _SigningOut extends SignOutController {
  @override
  Future<void> signOut(String accountId) async => state = true;
}

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  late AuthFakes auth;
  late SyncFakes sync;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes(now: now);
    sync.realtime.accepts = true;
  });

  Future<RegisteredAccount> seed(
    ServerConnection connection, {
    int userId = 7,
    bool needsReauth = false,
    bool activate = true,
  }) => auth.seedAccount(
    connection,
    tokens: issueTokens(issuedAt: DateTime.now().toUtc(), userId: userId),
    needsReauth: needsReauth,
    activate: activate,
  );

  ProviderContainer containerWith([List<Override> overrides = const []]) =>
      ProviderContainer(
        overrides: [
          ...appOverrides(auth: auth, sync: sync),
          clockProvider.overrideWithValue(() => now),
          ...overrides,
        ],
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Listens like the shell and waits for the providers to settle.
  Future<ProviderSubscription<RealtimeConnection?>> listen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final shell = container.listen(realtimeConnectionProvider, (_, _) {});
    await settle(tester);
    return shell;
  }

  testWidgets('connects to the active account v2 socket and catches up', (
    tester,
  ) async {
    await seed(fullServer270());
    final container = containerWith();

    final shell = await listen(tester, container);

    expect(shell.read()?.state, RealtimeState.live);
    expect(sync.realtime.urls, [
      Uri.parse('wss://tasks.example.org/vikunja/api/v2/ws'),
    ]);
    expect(sync.realtime.lastSocket.tokens, hasLength(1));
    expect(sync.activity.refreshCalls, 1);
    container.dispose();
    expect(sync.realtime.lastSocket.closedWith, 1000);
  });

  testWidgets('a v1-only server gets the v1 socket, a plain http server ws', (
    tester,
  ) async {
    await seed(v1OnlyServer270());
    final v1 = containerWith();
    await listen(tester, v1);
    v1.dispose();

    auth = AuthFakes();
    await seed(insecureServer());
    final insecure = containerWith();
    await listen(tester, insecure);
    insecure.dispose();

    expect(sync.realtime.urls, [
      Uri.parse('wss://vikunja.example.com/api/v1/ws'),
      Uri.parse('ws://192.168.1.20:3456/api/v2/ws'),
    ]);
  });

  group('no socket', () {
    testWidgets('while nobody is signed in', (tester) async {
      final container = containerWith();

      final shell = await listen(tester, container);

      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 0);
      container.dispose();
    });

    testWidgets('for a link-share guest, whose token the socket refuses', (
      tester,
    ) async {
      await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
      );
      final container = containerWith();

      final shell = await listen(tester, container);

      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 0);
      container.dispose();
    });

    testWidgets('in a background container', (tester) async {
      await seed(fullServer270());
      final container = containerWith([
        runsHeadlessProvider.overrideWithValue(true),
      ]);

      final shell = await listen(tester, container);

      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 0);
      container.dispose();
    });

    testWidgets('on a server without websockets', (tester) async {
      await seed(legacyServer200());
      final container = containerWith();

      final shell = await listen(tester, container);

      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 0);
      container.dispose();
    });

    testWidgets('while the session needs a sign-in; the socket closes when '
        'it ends', (tester) async {
      final entry = await seed(fullServer270());
      final container = containerWith();
      final shell = await listen(tester, container);
      expect(shell.read()?.state, RealtimeState.live);

      await container.read(accountRegistryProvider).markNeedsReauth(entry.id);
      await settle(tester);

      expect(shell.read(), isNull);
      expect(sync.realtime.lastSocket.closedWith, 1000);
      expect(sync.realtime.connectCalls, 1);
      container.dispose();
    });

    testWidgets('before the first sync; one once it completed', (tester) async {
      sync = SyncFakes(now: now, status: const SyncNeverRun());
      sync.realtime.accepts = true;
      await seed(fullServer270());
      final container = containerWith();

      final shell = await listen(tester, container);
      expect(shell.read(), isNull);
      sync.engine.emit(
        const SyncRunning(phase: SyncPhase.tasks, done: 0, initial: true),
      );
      await settle(tester);
      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 0);

      sync.engine.emit(SyncIdle(lastSyncedAt: now));
      await settle(tester);
      expect(shell.read()?.state, RealtimeState.live);
      expect(sync.realtime.connectCalls, 1);
      container.dispose();
    });

    testWidgets('during a sign-out, closed before the sign-out goes on', (
      tester,
    ) async {
      final entry = await seed(fullServer270());
      final container = containerWith([
        signOutControllerProvider.overrideWith(_SigningOut.new),
      ]);
      final shell = await listen(tester, container);
      final socket = sync.realtime.lastSocket;

      final signOut = container
          .read(signOutControllerProvider.notifier)
          .signOut(entry.id);

      expect(socket.closedWith, 1000);
      await signOut;
      await settle(tester);
      expect(shell.read(), isNull);
      expect(sync.realtime.connectCalls, 1);
      container.dispose();
    });

    testWidgets('while offline; one once a run gets through', (tester) async {
      sync.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: now,
        ),
      );
      await seed(fullServer270());
      final container = containerWith();

      final shell = await listen(tester, container);
      expect(shell.read()?.state, RealtimeState.waiting);
      expect(sync.realtime.connectCalls, 0);

      sync.engine.emit(SyncIdle(lastSyncedAt: now));
      await settle(tester);
      expect(shell.read()?.state, RealtimeState.live);
      container.dispose();
    });
  });

  testWidgets('hidden or paused closes the socket; a resume connects again', (
    tester,
  ) async {
    await seed(fullServer270());
    final container = containerWith();
    final shell = await listen(tester, container);
    final connection = shell.read()!;

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await settle(tester);
    expect(sync.realtime.sockets[0].closedWith, 1000);
    expect(connection.state, RealtimeState.idle);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(sync.realtime.connectCalls, 2);
    expect(connection.state, RealtimeState.live);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(sync.realtime.sockets[1].closedWith, 1000);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(sync.realtime.connectCalls, 3);
    expect(identical(shell.read(), connection), isTrue);
    container.dispose();
  });

  testWidgets('an account switch closes the old socket and opens the new '
      "account's", (tester) async {
    await seed(fullServer270());
    final other = await seed(v1OnlyServer270(), userId: 8, activate: false);
    final container = containerWith();
    final shell = await listen(tester, container);
    final first = shell.read();

    await container.read(accountRegistryProvider).setActive(other.id);
    await settle(tester);

    expect(sync.realtime.sockets.first.closedWith, 1000);
    expect(
      sync.realtime.urls.last,
      Uri.parse('wss://vikunja.example.com/api/v1/ws'),
    );
    expect(shell.read(), isNot(same(first)));
    expect(shell.read()?.state, RealtimeState.live);
    container.dispose();
  });

  testWidgets('rests while nothing listens and goes on when the shell '
      'listens again', (tester) async {
    await seed(fullServer270());
    final container = containerWith();
    final shell = await listen(tester, container);

    shell.close();
    await settle(tester);
    expect(sync.realtime.lastSocket.closedWith, 1000);

    final again = await listen(tester, container);
    expect(again.read()?.state, RealtimeState.live);
    expect(sync.realtime.connectCalls, 2);
    again.close();
    container.dispose();
  });

  testWidgets('a server that refuses the upgrade leaves the app polling', (
    tester,
  ) async {
    sync.realtime.accepts = false;
    await seed(fullServer270());
    final container = containerWith();

    final shell = await listen(tester, container);

    expect(shell.read()?.state, RealtimeState.unavailable);
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
    container.dispose();
  });
}
