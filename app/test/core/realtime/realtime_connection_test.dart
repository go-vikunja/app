import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/realtime_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/zero_random.dart';

final class _Tokens implements AccessTokenSource {
  String current = 'token-1';
  Exception? failure;
  final List<String> rejected = [];
  Future<String?> Function(String rejectedToken) onRejection = (_) async =>
      null;

  @override
  Future<String> validAccessToken() async {
    if (failure case final failure?) throw failure;
    return current;
  }

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) {
    rejected.add(rejectedToken);
    return onRejection(rejectedToken);
  }
}

/// The widest jitter, up or down.
final class _WidestJitter implements Random {
  new({required this.up});

  final bool up;

  @override
  bool nextBool() => up;

  @override
  double nextDouble() => 1;

  @override
  int nextInt(int max) => 0;
}

void main() {
  final url = Uri.parse('wss://vikunja.example/sub/api/v2/ws');
  const second = Duration(seconds: 1);
  late DateTime now;
  late FakeTimers timers;
  late FakeRealtimeConnector connector;
  late _Tokens tokens;
  late FakeSyncEngine engine;
  late FakeActivityRepository activity;

  setUp(() {
    now = DateTime.utc(2026, 10, 19, 12);
    timers = FakeTimers();
    connector = FakeRealtimeConnector();
    tokens = _Tokens();
    engine = FakeSyncEngine(initialStatus: SyncIdle(lastSyncedAt: now));
    activity = FakeActivityRepository();
  });

  RealtimeConnection connection({Random? random}) {
    final connection = RealtimeConnection(
      connector: connector,
      url: url,
      tokens: tokens,
      engine: engine,
      activity: activity,
      headers: const {'User-Agent': 'Rurana/test'},
      clock: () => now,
      createTimer: timers.create,
      random: random ?? ZeroRandom(),
    );
    addTearDown(connection.dispose);
    return connection;
  }

  Future<RealtimeConnection> live({Random? random}) async {
    final live = connection(random: random)..start();
    await pumpEventQueue();
    expect(live.state, RealtimeState.live);
    return live;
  }

  FakeTimer timerOf(Duration duration) =>
      timers.active.singleWhere((timer) => timer.duration == duration);

  bool hasTimerOf(Duration duration) =>
      timers.active.any((timer) => timer.duration == duration);

  /// The retry wait: the only timer while not connected.
  Duration retryWait() => timers.pendingWait;

  Future<void> fireRetry() async {
    timers.fireNext();
    await pumpEventQueue();
  }

  group('the sequence', () {
    test('upgrade, auth with the session token, subscribe, one catch-up of '
        'the activity, live', () async {
      final states = <RealtimeState>[];
      final realtime = connection();
      realtime.states.listen(states.add);

      realtime.start();
      await pumpEventQueue();

      expect(connector.urls, [url]);
      expect(connector.headers.single, {'User-Agent': 'Rurana/test'});
      final socket = connector.lastSocket;
      expect(socket.tokens, ['token-1']);
      expect(socket.sent, ['auth', 'subscribe notification.created']);
      expect(activity.refreshCalls, 1);
      expect(states, [
        RealtimeState.idle,
        RealtimeState.connecting,
        RealtimeState.live,
      ]);
    });

    test('nothing is subscribed or caught up before auth.success', () async {
      connector.autoAuthenticate = false;
      final realtime = connection()..start();
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.connecting);
      expect(connector.lastSocket.sent, ['auth']);
      expect(activity.refreshCalls, 0);

      connector.lastSocket.push(const RealtimeAuthSucceeded());
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(connector.lastSocket.subscriptions, ['notification.created']);
      expect(activity.refreshCalls, 1);
    });

    test('no auth.success within 10 s closes the socket and reconnects '
        'after the backoff', () async {
      connector.autoAuthenticate = false;
      final realtime = connection()..start();
      await pumpEventQueue();

      timerOf(RealtimeConnection.authTimeout).fire();
      await pumpEventQueue();

      expect(connector.lastSocket.closedWith, 1000);
      expect(realtime.state, RealtimeState.waiting);
      expect(retryWait(), second * 2);
      await fireRetry();
      expect(connector.connectCalls, 2);
    });

    test('a failed catch-up leaves the socket live', () async {
      activity.refreshFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );

      final realtime = await live();
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(connector.lastSocket.isClosed, isFalse);
    });

    test('the token is asked for after the upgrade, so a refused upgrade '
        'costs no refresh', () async {
      tokens.failure = Exception('no token expected');
      connector.accepts = false;

      final realtime = connection()..start();
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.unavailable);
    });

    test('a token that cannot be had now closes the socket and retries '
        'later; an ended session gives up until the next resume', () async {
      tokens.failure = const NetworkFailure(NetworkProblem.timeout);
      final realtime = connection()..start();
      await pumpEventQueue();

      expect(connector.lastSocket.closedWith, 1000);
      expect(realtime.state, RealtimeState.waiting);

      tokens.failure = const SessionEnded(SessionEndReason.expired);
      await fireRetry();
      expect(realtime.state, RealtimeState.unavailable);

      tokens.failure = null;
      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();
      expect(realtime.state, RealtimeState.live);
    });
  });

  group('pushed notifications', () {
    test('are stored at once, and those that name a task or project ask '
        'for one sync 2 s later', () async {
      await live();
      final socket = connector.lastSocket;
      const syncing = [
        'task.comment',
        'task.assigned',
        'task.mentioned',
        'task.created',
        'task.deleted',
        'project.created',
      ];
      const quiet = [
        'team.member.added',
        'task.reminder',
        'api_token.expiring',
      ];

      var id = 100;
      for (final kind in syncing) {
        final notification = sampleNotification(id: ++id, name: kind);
        socket.push(RealtimeNotification(notification));
        await pumpEventQueue();
        expect(activity.received.last, notification, reason: kind);
        final before = engine.refreshCalls;
        timerOf(RealtimeConnection.syncDebounce).fire();
        await pumpEventQueue();
        expect(engine.refreshCalls, before + 1, reason: kind);
      }
      for (final kind in quiet) {
        socket.push(
          RealtimeNotification(sampleNotification(id: ++id, name: kind)),
        );
        await pumpEventQueue();
        expect(activity.received.last.name, kind);
        expect(hasTimerOf(RealtimeConnection.syncDebounce), isFalse);
      }
      expect(activity.received, hasLength(syncing.length + quiet.length));
    });

    test(
      'the badge counts what arrives, without the server reminders',
      () async {
        await live();
        final socket = connector.lastSocket
          ..push(
            RealtimeNotification(
              sampleNotification(id: 1, name: 'task.comment'),
            ),
          )
          ..push(
            RealtimeNotification(
              sampleNotification(id: 2, name: 'task.reminder'),
            ),
          );
        await pumpEventQueue();

        expect(await activity.watchUnreadCount().first, 1);
        expect(activity.notifications.map((n) => n.id), [2, 1]);
        expect(socket.isClosed, isFalse);
      },
    );

    test('a burst asks for one sync, 2 s after the last one', () async {
      await live();
      final socket = connector.lastSocket;

      for (var id = 1; id <= 3; id++) {
        socket.push(
          RealtimeNotification(
            sampleNotification(id: id, name: 'task.comment'),
          ),
        );
        await pumpEventQueue();
      }

      expect(
        timers.active.where(
          (timer) => timer.duration == RealtimeConnection.syncDebounce,
        ),
        hasLength(1),
      );
      timerOf(RealtimeConnection.syncDebounce).fire();
      await pumpEventQueue();
      expect(engine.refreshCalls, 1);
      expect(activity.received, hasLength(3));
    });

    test('a run in progress is followed by one run after it, however many '
        'arrive meanwhile', () async {
      await live();
      final socket = connector.lastSocket;
      final running = Completer<void>();
      engine.onRefresh = () => running.future;
      unawaited(engine.refresh());
      await pumpEventQueue();
      expect(engine.refreshCalls, 1);

      for (var id = 1; id <= 2; id++) {
        socket.push(
          RealtimeNotification(
            sampleNotification(id: id, name: 'task.created'),
          ),
        );
        await pumpEventQueue();
        timerOf(RealtimeConnection.syncDebounce).fire();
        await pumpEventQueue();
      }
      expect(engine.refreshCalls, 1);

      running.complete();
      await pumpEventQueue();
      expect(engine.refreshCalls, 2);
      await pumpEventQueue();
      expect(engine.refreshCalls, 2);
    });

    test('a store that fails leaves the socket live', () async {
      activity.receiveFailure = Exception('database closed');
      final realtime = await live();

      connector.lastSocket.push(
        RealtimeNotification(sampleNotification(id: 1, name: 'task.comment')),
      );
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(connector.lastSocket.isClosed, isFalse);
      expect(hasTimerOf(RealtimeConnection.syncDebounce), isTrue);
    });
  });

  group('re-auth', () {
    test('a refreshed token is sent on the open socket within 20 s; the '
        'same token is not sent again', () async {
      await live();
      final socket = connector.lastSocket;

      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();
      expect(socket.tokens, ['token-1']);

      tokens.current = 'token-2';
      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();
      expect(socket.tokens, ['token-1', 'token-2']);
      expect(hasTimerOf(RealtimeConnection.authTimeout), isFalse);

      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();
      expect(socket.tokens, ['token-1', 'token-2']);
      expect(socket.subscriptions, ['notification.created']);
      expect(socket.isClosed, isFalse);
      expect(activity.refreshCalls, 1);
    });

    test(
      'no auth.success within 10 s of a re-auth closes and reconnects',
      () async {
        final realtime = await live();
        final socket = connector.lastSocket..autoAuthenticate = false;
        tokens.current = 'token-2';
        timerOf(RealtimeConnection.tokenCheckInterval).fire();
        await pumpEventQueue();

        timerOf(RealtimeConnection.authTimeout).fire();
        await pumpEventQueue();

        expect(socket.closedWith, 1000);
        expect(realtime.state, RealtimeState.waiting);
        await fireRetry();
        expect(connector.lastSocket.tokens, ['token-2']);
        expect(realtime.state, RealtimeState.live);
      },
    );

    test('a token of another session reconnects instead of '
        're-authenticating', () async {
      String tokenOf(String session) => fakeJwt(
        userId: 7,
        username: 'alice',
        sessionId: session,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      tokens.current = tokenOf('session-1');
      final realtime = await live();
      final first = connector.lastSocket;

      final refreshed = tokenOf('session-1');
      tokens.current = refreshed;
      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();
      expect(first.tokens.last, refreshed);
      expect(first.isClosed, isFalse);

      final signedInAgain = tokenOf('session-2');
      tokens.current = signedInAgain;
      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();

      expect(first.tokens, hasLength(2));
      expect(first.closedWith, 1000);
      expect(connector.connectCalls, 2);
      expect(connector.lastSocket.tokens, [signedInAgain]);
      expect(tokens.rejected, isEmpty);
      expect(realtime.state, RealtimeState.live);
    });

    test('a token check that fails tries again at the next one', () async {
      final realtime = await live();
      tokens.failure = const NetworkFailure(NetworkProblem.timeout);

      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(hasTimerOf(RealtimeConnection.tokenCheckInterval), isTrue);
    });
  });

  group('a rejected token', () {
    test('invalid_token asks the session manager; a newer token reconnects '
        'at once', () async {
      connector.autoAuthenticate = false;
      tokens.onRejection = (_) async => tokens.current = 'token-2';
      final realtime = connection()..start();
      await pumpEventQueue();

      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();

      expect(tokens.rejected, ['token-1']);
      expect(connector.sockets.first.isClosed, isTrue);
      expect(connector.connectCalls, 2);
      expect(connector.lastSocket.tokens, ['token-2']);
      connector.lastSocket.push(const RealtimeAuthSucceeded());
      await pumpEventQueue();
      expect(realtime.state, RealtimeState.live);
    });

    test('no newer token: unavailable until the next resume', () async {
      connector.autoAuthenticate = false;
      final realtime = connection()..start();
      await pumpEventQueue();

      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.unavailable);
      expect(connector.connectCalls, 1);
      expect(timers.active, isEmpty);

      realtime.onResume();
      await pumpEventQueue();
      expect(connector.connectCalls, 1, reason: 'a resume without a pause');

      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();
      expect(connector.connectCalls, 2);
      expect(realtime.state, RealtimeState.connecting);
    });

    test('a session check that throws gives up too', () async {
      connector.autoAuthenticate = false;
      tokens.onRejection = (_) async =>
          throw const SessionEnded(SessionEndReason.invalidRefreshToken);
      final realtime = connection()..start();
      await pumpEventQueue();

      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.unavailable);
      expect(connector.connectCalls, 1);
    });

    test('a second rejection after the reconnect gives up without another '
        'refresh', () async {
      connector.autoAuthenticate = false;
      tokens.onRejection = (_) async => tokens.current = 'token-2';
      final realtime = connection()..start();
      await pumpEventQueue();

      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();
      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();

      expect(tokens.rejected, ['token-1']);
      expect(connector.connectCalls, 2);
      expect(realtime.state, RealtimeState.unavailable);
    });

    test('a rejection after an auth.success gets its own recovery', () async {
      tokens.onRejection = (_) async => tokens.current = 'token-2';
      await live();
      connector.lastSocket.serverClose(1008, 'session revoked');
      await pumpEventQueue();
      expect(connector.connectCalls, 2);

      tokens.onRejection = (_) async => tokens.current = 'token-3';
      connector.lastSocket.serverClose(1008, 'session revoked');
      await pumpEventQueue();

      expect(tokens.rejected, ['token-1', 'token-2']);
      expect(connector.connectCalls, 3);
    });

    test('a rejected re-auth names the new token', () async {
      await live();
      final socket = connector.lastSocket..autoAuthenticate = false;
      tokens.current = 'token-2';
      timerOf(RealtimeConnection.tokenCheckInterval).fire();
      await pumpEventQueue();

      socket.push(const RealtimeError(RealtimeError.invalidToken));
      await pumpEventQueue();

      expect(tokens.rejected, ['token-2']);
      expect(socket.isClosed, isTrue);
    });

    test('1008 "session revoked" asks the session manager with the '
        "socket's token", () async {
      tokens.onRejection = (_) async =>
          throw const SessionEnded(SessionEndReason.invalidRefreshToken);
      final realtime = await live();

      connector.lastSocket.serverClose(1008, 'session revoked');
      await pumpEventQueue();

      expect(tokens.rejected, ['token-1']);
      expect(realtime.state, RealtimeState.unavailable);
      expect(connector.connectCalls, 1);
    });

    test('a close that arrives after dispose is ignored', () async {
      final realtime = await live();
      final socket = connector.lastSocket..awaitsServerClose = true;

      realtime.dispose();
      socket.serverClose(1008, 'session revoked');
      await pumpEventQueue();

      expect(socket.closedWith, 1000);
      expect(tokens.rejected, isEmpty);
      expect(connector.connectCalls, 1);
      expect(timers.active, isEmpty);
    });

    test('other server errors are ignored', () async {
      final realtime = await live();

      connector.lastSocket
        ..push(const RealtimeError(RealtimeError.invalidEvent, event: 'x'))
        ..push(const RealtimeError(RealtimeError.authRequired))
        ..push(const RealtimeError('something_new'))
        ..push(const RealtimeUnknown());
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(tokens.rejected, isEmpty);
    });
  });

  group('drops reconnect after a backoff', () {
    const drops = <(int?, String?)>[
      (1008, 'token expired'),
      (1008, 'auth timeout'),
      (1013, null),
      (1001, null),
      (1006, null),
      (1000, null),
      (null, null),
    ];
    for (final (code, reason) in drops) {
      test('close ${code ?? 'without a frame'} ${reason ?? ''}', () async {
        final realtime = await live();

        connector.lastSocket.serverClose(code, reason);
        await pumpEventQueue();

        expect(realtime.state, RealtimeState.waiting);
        expect(tokens.rejected, isEmpty);
        expect(retryWait(), second * 2);
        await fireRetry();
        expect(connector.connectCalls, 2);
        expect(realtime.state, RealtimeState.live);
        expect(activity.refreshCalls, 2, reason: 'a catch-up per connect');
      });
    }

    final retried = <Exception>[
      const SocketException('refused'),
      TimeoutException('connect'),
      const HttpException('closed early'),
      const RealtimeUpgradeRefused(500),
      const RealtimeUpgradeRefused(502),
      const RealtimeUpgradeRefused(503),
      const HandshakeException('Connection terminated during handshake'),
    ];
    for (final error in retried) {
      test('connect failing with $error', () async {
        connector.onConnect = (_) async => throw error;
        final realtime = connection()..start();
        await pumpEventQueue();

        expect(realtime.state, RealtimeState.waiting);
        expect(retryWait(), second * 2);
        connector.onConnect = null;
        await fireRetry();
        expect(realtime.state, RealtimeState.live);
      });
    }

    test('the backoff doubles from 2 s to 60 s while sockets keep dropping '
        'early', () async {
      final realtime = await live();

      final waits = <Duration>[];
      for (var i = 0; i < 7; i++) {
        connector.lastSocket.serverClose(1006);
        await pumpEventQueue();
        waits.add(retryWait());
        await fireRetry();
        expect(realtime.state, RealtimeState.live);
      }

      expect(waits, [
        for (final seconds in [2, 4, 8, 16, 32, 60, 60])
          Duration(seconds: seconds),
      ]);
    });

    test('with up to 25 % jitter either way', () async {
      connector
        ..accepts = false
        ..refusedStatus = 503;
      connection(random: _WidestJitter(up: true)).start();
      await pumpEventQueue();
      expect(retryWait(), const Duration(milliseconds: 2500));
      await fireRetry();
      expect(retryWait(), const Duration(seconds: 5));
      timers.active.single.cancel();

      final down = RealtimeConnection(
        connector: connector,
        url: url,
        tokens: tokens,
        engine: engine,
        activity: activity,
        clock: () => now,
        createTimer: timers.create,
        random: _WidestJitter(up: false),
      )..start();
      addTearDown(down.dispose);
      await pumpEventQueue();
      expect(retryWait(), const Duration(milliseconds: 1500));
    });

    test('a socket live for 60 s resets the backoff', () async {
      connector
        ..accepts = false
        ..refusedStatus = 503;
      final realtime = connection()..start();
      await pumpEventQueue();
      await fireRetry();
      expect(retryWait(), second * 4);
      connector.accepts = true;
      await fireRetry();
      expect(realtime.state, RealtimeState.live);

      now = now.add(const Duration(seconds: 30));
      connector.lastSocket.serverClose(1006);
      await pumpEventQueue();
      expect(retryWait(), second * 8, reason: 'live for 30 s only');

      await fireRetry();
      now = now.add(const Duration(seconds: 61));
      connector.lastSocket.serverClose(1006);
      await pumpEventQueue();
      expect(retryWait(), second * 2);
    });

    test('a socket live for 60 s resets the backoff however it ends', () async {
      connector
        ..accepts = false
        ..refusedStatus = 503;
      tokens.onRejection = (_) async => tokens.current = 'token-2';
      final realtime = connection()..start();
      await pumpEventQueue();
      await fireRetry();
      await fireRetry();
      expect(retryWait(), second * 8);
      connector.accepts = true;
      await fireRetry();
      expect(realtime.state, RealtimeState.live);

      now = now.add(RealtimeConnection.stableAfter);
      connector.onConnect = (_) async => throw const SocketException('down');
      connector.lastSocket.push(
        const RealtimeError(RealtimeError.invalidToken),
      );
      await pumpEventQueue();

      expect(tokens.rejected, ['token-1']);
      expect(connector.connectCalls, 5);
      expect(retryWait(), second * 2);
    });

    test('a resume starts again from the shortest wait', () async {
      connector.onConnect = (_) async => throw const SocketException('down');
      final realtime = connection()..start();
      await pumpEventQueue();
      await fireRetry();
      await fireRetry();
      expect(retryWait(), second * 8);

      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();

      expect(connector.connectCalls, 4);
      expect(retryWait(), second * 2);
    });
  });

  group('attempts that never get to auth.success', () {
    test('give up until the next resume after 6 in a row; a rate-limited '
        'one does not count', () async {
      var attempt = 0;
      connector.onConnect = (_) async {
        attempt++;
        if (attempt == 3) {
          throw const RealtimeUpgradeRefused(
            429,
            retryAfter: Duration(seconds: 5),
          );
        }
        if (attempt == 5) return connector.open()..autoAuthenticate = false;
        throw const SocketException('refused');
      };
      final realtime = connection()..start();
      await pumpEventQueue();

      // The 429, then a socket whose auth.success times out, in between.
      for (var fire = 0; fire < 7; fire++) {
        expect(realtime.state, isNot(RealtimeState.unavailable));
        await fireRetry();
      }

      expect(connector.connectCalls, 7);
      expect(realtime.state, RealtimeState.unavailable);
      expect(timers.active, isEmpty);
      realtime
        ..setOffline(offline: true)
        ..setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 7);

      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();
      expect(connector.connectCalls, 8);
      expect(realtime.state, RealtimeState.waiting);
      connector.onConnect = null;
      await fireRetry();
      expect(realtime.state, RealtimeState.live);
    });

    test('an auth.success starts the count again', () async {
      connector.onConnect = (_) async => throw const SocketException('down');
      final realtime = connection()..start();
      await pumpEventQueue();
      for (var fire = 0; fire < 4; fire++) {
        await fireRetry();
      }
      connector.onConnect = null;
      await fireRetry();
      expect(realtime.state, RealtimeState.live);

      connector.onConnect = (_) async => throw const SocketException('down');
      connector.lastSocket.serverClose(1006);
      await pumpEventQueue();
      for (var fire = 0; fire < 5; fire++) {
        await fireRetry();
      }

      expect(connector.connectCalls, 11);
      expect(realtime.state, RealtimeState.waiting);
    });
  });

  group('a rate-limited upgrade', () {
    test('waits out Retry-After and does not count as a failure', () async {
      connector.onConnect = (_) async => throw const RealtimeUpgradeRefused(
        429,
        retryAfter: Duration(seconds: 43),
      );
      final realtime = connection()..start();
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.waiting);
      expect(retryWait(), const Duration(seconds: 43));

      connector.onConnect = null;
      await fireRetry();
      expect(realtime.state, RealtimeState.live);
      connector.lastSocket.serverClose(1006);
      await pumpEventQueue();
      expect(retryWait(), second * 2);
    });

    test('adds up to 25 % to it', () async {
      connector.onConnect = (_) async => throw const RealtimeUpgradeRefused(
        429,
        retryAfter: Duration(seconds: 40),
      );
      connection(random: _WidestJitter(up: false)).start();
      await pumpEventQueue();

      expect(retryWait(), const Duration(seconds: 50));
    });

    test('waits a whole limiter window without Retry-After', () async {
      connector.onConnect = (_) async =>
          throw const RealtimeUpgradeRefused(429);
      connection().start();
      await pumpEventQueue();

      expect(retryWait(), const Duration(seconds: 60));
    });

    test('waits at least 2 s, doubling with every 429 in a row', () async {
      connector.onConnect = (_) async =>
          throw const RealtimeUpgradeRefused(429, retryAfter: Duration.zero);
      connection().start();
      await pumpEventQueue();
      expect(retryWait(), second * 2);

      await fireRetry();
      expect(connector.connectCalls, 2);
      expect(retryWait(), second * 4);

      await fireRetry();
      expect(retryWait(), second * 8);
    });

    test('waits at most 5 minutes, however long Retry-After says', () async {
      connector.onConnect = (_) async => throw const RealtimeUpgradeRefused(
        429,
        retryAfter: Duration(days: 1),
      );
      connection().start();
      await pumpEventQueue();

      expect(retryWait(), const Duration(minutes: 5));
    });

    test('is waited out across a pause and the network coming back', () async {
      connector.onConnect = (_) async => throw const RealtimeUpgradeRefused(
        429,
        retryAfter: Duration(seconds: 43),
      );
      final realtime = connection()..start();
      await pumpEventQueue();
      connector.onConnect = null;

      realtime
        ..onPause()
        ..onResume()
        ..setOffline(offline: true)
        ..setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 1);
      expect(retryWait(), const Duration(seconds: 43));

      now = now.add(const Duration(seconds: 44));
      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();
      expect(connector.connectCalls, 2);
    });
  });

  group('unavailable', () {
    final givenUp = <Exception>[
      const RealtimeUpgradeRefused(400),
      const RealtimeUpgradeRefused(401),
      const RealtimeUpgradeRefused(403),
      const RealtimeUpgradeRefused(404),
      const RealtimeUpgradeRefused(426),
      const RealtimeUpgradeRefused(302),
      const WebSocketException('Wrong Sec-WebSocket-Accept'),
    ];
    for (final error in givenUp) {
      test('after $error before any socket was live, also across resumes, '
          'until a new connection', () async {
        connector.onConnect = (_) async => throw error;
        final realtime = connection()..start();
        await pumpEventQueue();

        expect(realtime.state, RealtimeState.unavailable);
        expect(timers.active, isEmpty);
        realtime
          ..onPause()
          ..onResume()
          ..setOffline(offline: true)
          ..setOffline(offline: false);
        await pumpEventQueue();
        expect(connector.connectCalls, 1);
        expect(realtime.state, RealtimeState.unavailable);

        connector.onConnect = null;
        final next = connection()..start();
        await pumpEventQueue();
        expect(next.state, RealtimeState.live);
      });
    }

    final passing = <Exception>[
      const RealtimeUpgradeRefused(404),
      const WebSocketException('Wrong Sec-WebSocket-Accept'),
      const HandshakeException('Connection terminated during handshake'),
    ];
    for (final error in passing) {
      test('after a live socket, $error is retried with the backoff', () async {
        final realtime = await live();
        connector.onConnect = (_) async => throw error;
        connector.lastSocket.serverClose(1001);
        await pumpEventQueue();

        await fireRetry();
        expect(realtime.state, RealtimeState.waiting);
        expect(retryWait(), second * 4);

        connector.onConnect = null;
        await fireRetry();
        expect(realtime.state, RealtimeState.live);
      });
    }

    test('after a live socket, refusals in a row give up until the next '
        'resume', () async {
      const attempts = RealtimeConnection.maxAttemptsWithoutAuth;
      final realtime = await live();
      connector.onConnect = (_) async =>
          throw const RealtimeUpgradeRefused(404);
      connector.lastSocket.serverClose(1001);
      await pumpEventQueue();

      for (var fire = 0; fire < attempts; fire++) {
        expect(realtime.state, RealtimeState.waiting);
        await fireRetry();
      }

      expect(realtime.state, RealtimeState.unavailable);
      expect(timers.active, isEmpty);
      expect(connector.connectCalls, 1 + attempts);
      realtime
        ..setOffline(offline: true)
        ..setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 1 + attempts);

      connector.onConnect = null;
      realtime
        ..onPause()
        ..onResume();
      await pumpEventQueue();
      expect(realtime.state, RealtimeState.live);
    });

    final tlsFailures = <Exception>[
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      const TlsException('protocol'),
    ];
    for (final error in tlsFailures) {
      test('after $error until the next resume', () async {
        connector.onConnect = (_) async => throw error;
        final realtime = connection()..start();
        await pumpEventQueue();

        expect(realtime.state, RealtimeState.unavailable);
        expect(timers.active, isEmpty);
        realtime
          ..setOffline(offline: true)
          ..setOffline(offline: false);
        await pumpEventQueue();
        expect(connector.connectCalls, 1);

        connector.onConnect = null;
        realtime
          ..onPause()
          ..onResume();
        await pumpEventQueue();
        expect(connector.connectCalls, 2);
        expect(realtime.state, RealtimeState.live);
      });
    }
  });

  group('connection settings that refuse the socket', () {
    final failures = <Exception>[
      const CleartextBlockedException('http://192.168.1.20:3456'),
      const ConnectionProfileLockedException('https://vikunja.example:443'),
      const ConnectionProfileIncompleteException('https://vikunja.example:443'),
      const ConnectionProfilesDamagedException(),
      const ClientCertificateRefusedException('https://vikunja.example:443'),
    ];
    for (final error in failures) {
      test('${error.runtimeType}: unavailable until the next resume', () async {
        connector.onConnect = (_) async => throw error;
        final realtime = connection()..start();
        await pumpEventQueue();

        expect(realtime.state, RealtimeState.unavailable);
        expect(timers.active, isEmpty);

        connector.onConnect = null;
        realtime
          ..onPause()
          ..onResume();
        await pumpEventQueue();
        expect(connector.connectCalls, 2);
        expect(realtime.state, RealtimeState.live);
      });
    }
  });

  group('offline', () {
    test('no attempt while offline; one at once when online again', () async {
      final realtime = connection()
        ..setOffline(offline: true)
        ..start();
      await pumpEventQueue();

      expect(connector.connectCalls, 0);
      expect(realtime.state, RealtimeState.waiting);
      expect(timers.active, isEmpty);

      realtime.setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 1);
      expect(realtime.state, RealtimeState.live);
    });

    test('a retry that comes due offline waits for the network, which '
        'cuts a backoff short', () async {
      final realtime = await live();
      connector.lastSocket.serverClose(null);
      await pumpEventQueue();

      realtime.setOffline(offline: true);
      await fireRetry();
      expect(connector.connectCalls, 1);
      expect(realtime.state, RealtimeState.waiting);

      realtime.setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 2);

      connector.lastSocket.serverClose(null);
      await pumpEventQueue();
      expect(retryWait(), second * 4);
      realtime
        ..setOffline(offline: true)
        ..setOffline(offline: false);
      await pumpEventQueue();
      expect(connector.connectCalls, 3);
    });

    test('a live socket stays when the sync runs go offline', () async {
      final realtime = await live();

      realtime.setOffline(offline: true);
      await pumpEventQueue();

      expect(realtime.state, RealtimeState.live);
      expect(connector.lastSocket.isClosed, isFalse);
    });
  });

  group('lifecycle', () {
    test('a pause closes with 1000 and a resume connects again with a new '
        'catch-up', () async {
      final realtime = await live();
      final first = connector.lastSocket;

      realtime.onPause();
      await pumpEventQueue();
      expect(first.closedWith, 1000);
      expect(realtime.state, RealtimeState.idle);
      expect(timers.active, isEmpty);

      realtime.onResume();
      await pumpEventQueue();
      expect(connector.connectCalls, 2);
      expect(realtime.state, RealtimeState.live);
      expect(activity.refreshCalls, 2);
    });

    test('a resume without a pause changes nothing', () async {
      final realtime = await live();

      realtime.onResume();
      await pumpEventQueue();

      expect(connector.connectCalls, 1);
    });

    test('a pause cancels a pending retry and a requested sync', () async {
      final realtime = await live();
      connector.lastSocket.push(
        RealtimeNotification(sampleNotification(id: 1, name: 'task.comment')),
      );
      await pumpEventQueue();
      expect(hasTimerOf(RealtimeConnection.syncDebounce), isTrue);

      realtime.onPause();

      expect(timers.active, isEmpty);
    });

    test('at most one attempt is in flight', () async {
      final pending = Completer<RealtimeSocket>();
      connector.onConnect = (_) => pending.future;
      final realtime = connection()..start();
      await pumpEventQueue();

      realtime
        ..onPause()
        ..onResume()
        ..setOffline(offline: true)
        ..setOffline(offline: false)
        ..start();
      await pumpEventQueue();
      expect(connector.connectCalls, 1);
      expect(realtime.state, RealtimeState.connecting);

      pending.complete(connector.open());
      await pumpEventQueue();
      expect(realtime.state, RealtimeState.live);
      expect(connector.connectCalls, 1);
    });

    test('a socket that arrives after a pause is closed', () async {
      final pending = Completer<RealtimeSocket>();
      connector.onConnect = (_) => pending.future;
      final realtime = connection()..start();
      await pumpEventQueue();

      realtime.onPause();
      final late = connector.open();
      pending.complete(late);
      await pumpEventQueue();

      expect(late.closedWith, 1000);
      expect(late.tokens, isEmpty);
      expect(realtime.state, RealtimeState.idle);
    });

    test('dispose closes the socket and stops everything', () async {
      final realtime = await live();
      final socket = connector.lastSocket;

      realtime.dispose();
      socket.push(
        RealtimeNotification(sampleNotification(id: 1, name: 'task.comment')),
      );
      await pumpEventQueue();

      expect(socket.closedWith, 1000);
      expect(activity.received, isEmpty);
      expect(timers.active, isEmpty);
      expect(realtime.state, RealtimeState.idle);
    });
  });

  test('the log has states, statuses and close codes at FINE, never a '
      'token, a frame or a title', () async {
    final records = <LogRecord>[];
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = Level.INFO);
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    tokens
      ..current = 'secret-token-1'
      ..onRejection = (_) async => tokens.current = 'secret-token-3';

    await live();
    tokens.current = 'secret-token-2';
    timerOf(RealtimeConnection.tokenCheckInterval).fire();
    await pumpEventQueue();
    connector.lastSocket.push(
      RealtimeNotification(
        sampleNotification(
          id: 7,
          name: 'task.comment',
          taskTitle: 'Secret title',
        ),
      ),
    );
    await pumpEventQueue();
    connector.lastSocket.push(const RealtimeError(RealtimeError.invalidToken));
    await pumpEventQueue();
    connector.lastSocket.serverClose(1008, 'token expired');
    await pumpEventQueue();

    final realtimeRecords = [
      for (final record in records)
        if (record.loggerName == 'Realtime') record,
    ];
    expect(realtimeRecords, isNotEmpty);
    expect(
      realtimeRecords.map((record) => record.message),
      containsAll([
        'State live',
        'Re-authenticated',
        'Notification 7 (task.comment)',
        'Reconnecting in 2000 ms: closed with 1008',
      ]),
    );
    for (final record in realtimeRecords) {
      expect(record.level < Level.INFO, isTrue, reason: record.message);
      expect(record.message, isNot(contains('secret-token')));
      expect(record.message, isNot(contains('Secret title')));
      expect(record.message, isNot(contains('"action"')));
    }
  });
}
