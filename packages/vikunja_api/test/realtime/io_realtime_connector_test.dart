import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/loopback_server.dart';

const _connector = IoRealtimeConnector();

const _userAgent = 'Rurana/1.4.0+7 (android 15)';

final String _commentFrame = jsonEncode(
  (fixtureJson('realtime/frames_2.7.0.json')['notifications']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .first['frame'],
);

Future<List<RealtimeMessage>> _allMessages(RealtimeSocket socket) =>
    socket.messages.toList().timeout(const Duration(seconds: 10));

Matcher _refused(int status, {Duration? retryAfter}) =>
    isA<RealtimeUpgradeRefused>()
        .having((e) => e.statusCode, 'statusCode', status)
        .having((e) => e.retryAfter, 'retryAfter', retryAfter);

void main() {
  late LoopbackServer server;

  Future<void> serve(
    FutureOr<void> Function(HttpRequest request) handle,
  ) async {
    server = await LoopbackServer.start(handle);
    addTearDown(server.close);
  }

  group('a 101', () {
    test(
      'gives a socket that authenticates, subscribes and receives',
      () async {
        final received = <Object?>[];
        await serve((request) async {
          final webSocket = await WebSocketTransformer.upgrade(request);
          await for (final frame in webSocket) {
            received.add(jsonDecode(frame as String));
            if (received.length == 1) {
              webSocket.add('{"action":"auth.success","success":true}');
            } else {
              webSocket.add(_commentFrame);
            }
          }
        });

        final socket = await _connector.connect(server.url);
        final messages = StreamIterator(socket.messages);
        socket.authenticate('header.payload.signature');
        expect(await messages.moveNext(), isTrue);
        final authenticated = messages.current;
        socket.subscribe(RealtimeSocket.notificationCreated);
        expect(await messages.moveNext(), isTrue);
        final pushed = messages.current;
        await socket.close();

        expect(authenticated, isA<RealtimeAuthSucceeded>());
        expect(
          pushed,
          isA<RealtimeNotification>().having(
            (m) => m.notification.id,
            'id',
            185,
          ),
        );
        expect(received, [
          {'action': 'auth', 'token': 'header.payload.signature'},
          {'action': 'subscribe', 'event': 'notification.created'},
        ]);
      },
    );

    test(
      "sends the caller's User-Agent, no Origin and no compression offer",
      () async {
        await serve((request) async {
          final webSocket = await WebSocketTransformer.upgrade(request);
          await webSocket.close();
        });

        final socket = await _connector.connect(
          server.url,
          headers: {'User-Agent': _userAgent},
        );
        await _allMessages(socket);

        final request = server.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v2/ws');
        expect(request.headers.value('user-agent'), _userAgent);
        expect(request.headers.value('origin'), isNull);
        expect(request.headers.value('sec-websocket-extensions'), isNull);
        expect(request.headers.value('sec-websocket-version'), '13');
        expect(
          base64.decode(request.headers.value('sec-websocket-key')!),
          hasLength(16),
        );
      },
    );

    test('on an IPv6 loopback address', () async {
      try {
        server = await LoopbackServer.start((request) async {
          final webSocket = await WebSocketTransformer.upgrade(request);
          await webSocket.close(4000, 'bye');
        }, address: InternetAddress.loopbackIPv6);
      } on SocketException {
        markTestSkipped('no IPv6 loopback here');
        return;
      }
      addTearDown(server.close);

      final socket = await _connector.connect(server.url);
      await _allMessages(socket);

      expect(server.url.toString(), startsWith('ws://[::1]:'));
      expect(socket.closeCode, 4000);
    });
  });

  group('a refused upgrade', () {
    test('429 carries Retry-After', () async {
      await serve(
        (request) => answer(
          request,
          HttpStatus.tooManyRequests,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': '43',
            'X-RateLimit-Limit': '10',
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': '1792414000',
          },
          body: '{"message":"Too Many Requests"}',
        ),
      );

      await expectLater(
        _connector.connect(server.url),
        throwsA(_refused(429, retryAfter: const Duration(seconds: 43))),
      );
    });

    test('429 without Retry-After waits until X-RateLimit-Reset', () async {
      await serve((request) {
        final now = DateTime.now().toUtc();
        return answer(
          request,
          HttpStatus.tooManyRequests,
          headers: {
            'Date': HttpDate.format(now),
            'X-RateLimit-Reset': '${now.millisecondsSinceEpoch ~/ 1000 + 20}',
          },
        );
      });

      await expectLater(
        _connector.connect(server.url),
        throwsA(
          isA<RealtimeUpgradeRefused>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.retryAfter?.inSeconds,
                'retryAfter',
                inInclusiveRange(20, 21),
              ),
        ),
      );
    });

    for (final status in const [400, 401, 403, 404, 426, 500, 502, 503]) {
      test('$status carries no wait', () async {
        await serve(
          (request) => answer(
            request,
            status,
            headers: {'Retry-After': '30', 'X-RateLimit-Reset': '1792414000'},
            body: 'WebSocket protocol violation',
          ),
        );

        await expectLater(
          _connector.connect(server.url),
          throwsA(_refused(status)),
        );
      });
    }

    test('200 from something that is no WebSocket server', () async {
      await serve((request) => answer(request, HttpStatus.ok, body: '<html>'));

      await expectLater(_connector.connect(server.url), throwsA(_refused(200)));
    });

    test('a redirect is not followed', () async {
      await serve((request) {
        if (request.uri.path == '/elsewhere') {
          return WebSocketTransformer.upgrade(request).then((ws) => ws.close());
        }
        return answer(
          request,
          HttpStatus.found,
          headers: {'Location': '/elsewhere'},
        );
      });

      await expectLater(_connector.connect(server.url), throwsA(_refused(302)));
      expect(server.requests, hasLength(1));
    });
  });

  group('a broken handshake', () {
    test('a wrong Sec-WebSocket-Accept is a WebSocketException', () async {
      await serve(
        (request) => acceptByHand(
          request,
          accept: (key) => webSocketAccept('$key-other'),
        ),
      );

      await expectLater(
        _connector.connect(server.url),
        throwsA(isA<WebSocketException>()),
      );
    });

    test('a missing Sec-WebSocket-Accept is a WebSocketException', () async {
      await serve((request) => acceptByHand(request, accept: (_) => null));

      await expectLater(
        _connector.connect(server.url),
        throwsA(isA<WebSocketException>()),
      );
    });

    test('a 101 without Upgrade: websocket is a WebSocketException', () async {
      await serve((request) => acceptByHand(request, upgradeHeader: false));

      await expectLater(
        _connector.connect(server.url),
        throwsA(isA<WebSocketException>()),
      );
    });
  });

  group('no answer', () {
    test('a server that never answers times out', () async {
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(silent.close);
      final peerClosed = Completer<void>();
      silent.listen((peer) => peer.listen(null, onDone: peerClosed.complete));
      const connector = IoRealtimeConnector(
        connectTimeout: Duration(milliseconds: 300),
      );

      await expectLater(
        connector.connect(Uri.parse('ws://127.0.0.1:${silent.port}/api/v2/ws')),
        throwsA(isA<TimeoutException>()),
      );
      await peerClosed.future.timeout(const Duration(seconds: 5));
    });

    test('a closed port is a SocketException', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();

      await expectLater(
        _connector.connect(Uri.parse('ws://127.0.0.1:$port/api/v2/ws')),
        throwsA(isA<SocketException>()),
      );
    });

    test('wss to a plain HTTP port fails the TLS handshake', () async {
      await serve((request) => answer(request, HttpStatus.badRequest));

      await expectLater(
        _connector.connect(server.url.replace(scheme: 'wss')),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('a URL that is not ws or wss is a programming error', () {
      expect(
        () => _connector.connect(Uri.parse('https://example.com/api/v2/ws')),
        throwsArgumentError,
      );
    });
  });

  group('the socket', () {
    test("ends with the server's close code and reason", () async {
      await serve((request) async {
        final webSocket = await WebSocketTransformer.upgrade(request);
        await webSocket.close(1008, 'session revoked');
      });

      final socket = await _connector.connect(server.url);
      final messages = await _allMessages(socket);

      expect(messages, isEmpty);
      expect(socket.closeCode, 1008);
      expect(socket.closeReason, 'session revoked');
    });

    test('delivers invalid_token before the close 1000 after it', () async {
      await serve((request) async {
        final webSocket = await WebSocketTransformer.upgrade(request);
        await webSocket.first;
        webSocket.add('{"error":"invalid_token"}');
        await webSocket.close(1000);
      });

      final socket = await _connector.connect(server.url);
      socket.authenticate('tk_not_a_jwt');
      final messages = await _allMessages(socket);

      expect(messages, [const RealtimeError(RealtimeError.invalidToken)]);
      expect(socket.closeCode, 1000);
      expect(socket.closeReason, isEmpty);
    });

    test('a drop without a close frame has no close code', () async {
      await serve((request) async {
        final connection = await acceptByHand(request);
        connection.add(const [0x81, 0x02, 0x7b, 0x7d]); // text frame '{}'
        await Future<void>.delayed(const Duration(milliseconds: 100));
        connection.destroy();
      });

      final socket = await _connector.connect(server.url);
      final messages = await _allMessages(socket);

      expect(messages, [isA<RealtimeUnknown>()]);
      expect(socket.closeCode, isNull);
      expect(socket.closeReason, isNull);
    });

    test('a connection reset has no close code either', () async {
      var resetAvailable = true;
      await serve((request) async {
        final connection = await acceptByHand(request);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        resetAvailable = withResetOnClose(connection) != null;
        connection.destroy();
      });

      final socket = await _connector.connect(server.url);
      await _allMessages(socket);
      if (!resetAvailable) {
        markTestSkipped('SO_LINGER is unknown on this platform');
        return;
      }

      expect(socket.closeCode, isNull);
      expect(socket.closeReason, isNull);
    });

    test('a server that stops answering pings is given up', () async {
      await serve((request) async {
        final connection = await acceptByHand(request);
        // Reads nothing, so it never answers a ping.
        connection.listen(null, onError: (Object _) {});
      });
      const connector = IoRealtimeConnector(
        pingInterval: Duration(milliseconds: 100),
      );

      final socket = await connector.connect(server.url);
      await _allMessages(socket);

      expect(socket.closeCode, WebSocketStatus.goingAway);
    });

    test('close sends 1000 to the server', () async {
      final serverSaw = Completer<int?>();
      await serve((request) async {
        final webSocket = await WebSocketTransformer.upgrade(request);
        await webSocket.drain<void>();
        serverSaw.complete(webSocket.closeCode);
      });

      final socket = await _connector.connect(server.url);
      final done = _allMessages(socket);
      await socket.close();
      await done;

      expect(await serverSaw.future.timeout(const Duration(seconds: 5)), 1000);
      expect(socket.closeCode, 1000);
    });

    test('sending after close does nothing', () async {
      await serve((request) async {
        final webSocket = await WebSocketTransformer.upgrade(request);
        await webSocket.drain<void>();
      });

      final socket = await _connector.connect(server.url);
      await socket.close();

      expect(() => socket.authenticate('a.b.c'), returnsNormally);
      expect(() => socket.subscribe('notification.created'), returnsNormally);
    });

    test('sending after the server closed does nothing', () async {
      await serve((request) async {
        final webSocket = await WebSocketTransformer.upgrade(request);
        await webSocket.close(1008, 'token expired');
      });

      final socket = await _connector.connect(server.url);
      await _allMessages(socket);

      expect(() => socket.authenticate('a.b.c'), returnsNormally);
      expect(socket.closeReason, 'token expired');
    });
  });
}
