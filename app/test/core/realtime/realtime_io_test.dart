import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/recording_sync_engine.dart';

final class _StaticToken implements AccessTokenSource {
  @override
  Future<String> validAccessToken() async => 'token-1';

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async => null;
}

// Over dart:io sockets on a loopback port, so what the real connector and
// the server see is checked too.
void main() {
  test("the upgrade carries the app's User-Agent and no Origin", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <HttpHeaders>[];
    server.listen((request) {
      requests.add(request.headers);
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
    });
    final container = ProviderContainer(
      overrides: [
        clientIdentityProvider.overrideWithValue(
          const ClientIdentity(
            appVersion: '1.2.0',
            buildNumber: '7',
            platform: 'android',
            osVersion: '15',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final connecting = container
        .read(realtimeConnectorProvider)
        .connect(
          Uri.parse('ws://127.0.0.1:${server.port}/api/v2/ws'),
          headers: const {'User-Agent': 'replaced'},
        );

    await expectLater(
      connecting,
      throwsA(
        isA<RealtimeUpgradeRefused>().having(
          (refused) => refused.statusCode,
          'statusCode',
          HttpStatus.notFound,
        ),
      ),
    );
    final headers = requests.single;
    expect(
      headers.value(HttpHeaders.userAgentHeader),
      'Rurana/1.2.0+7 (android 15)',
    );
    expect(headers.value('origin'), isNull);
  });

  test('a pause closes the real socket with 1000', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final frames = <Map<String, Object?>>[];
    final serverSide = Completer<WebSocket>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      serverSide.complete(socket);
      socket.listen((frame) {
        final json = jsonDecode(frame as String) as Map<String, Object?>;
        frames.add(json);
        if (json['action'] == 'auth') {
          socket.add(jsonEncode({'action': 'auth.success', 'success': true}));
        }
      });
    });
    final activity = FakeActivityRepository();
    final realtime = RealtimeConnection(
      connector: const IoRealtimeConnector(),
      url: Uri.parse('ws://127.0.0.1:${server.port}/api/v2/ws'),
      tokens: _StaticToken(),
      engine: RecordingSyncEngine(SyncIdle(lastSyncedAt: DateTime.now())),
      activity: activity,
    );
    addTearDown(realtime.dispose);

    realtime.start();
    await realtime.states
        .firstWhere((state) => state == RealtimeState.live)
        .timeout(const Duration(seconds: 5));
    final socket = await serverSide.future;
    while (frames.length < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    realtime.onPause();
    await socket.done.timeout(const Duration(seconds: 5));

    expect(frames.map((frame) => frame['action']), ['auth', 'subscribe']);
    expect(frames.last['event'], 'notification.created');
    expect(socket.closeCode, 1000);
    expect(activity.refreshCalls, 1);
  });
}
