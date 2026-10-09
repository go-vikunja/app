import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/server_connections.dart';

void main() {
  late FakeServerConnector connector;
  late ProviderContainer container;
  late List<ConnectServerState> states;

  setUp(() {
    connector = FakeServerConnector();
    container = ProviderContainer.test(
      overrides: [serverConnectorProvider.overrideWithValue(connector)],
    );
    states = [];
    container.listen(
      connectServerControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
  });

  ConnectServerController controller() =>
      container.read(connectServerControllerProvider.notifier);
  ConnectServerState state() => container.read(connectServerControllerProvider);
  ServerConnection? currentServer() => container.read(currentServerProvider);

  test('starts idle without a current server', () {
    expect(state(), isA<ConnectServerIdle>());
    expect(currentServer(), isNull);
  });

  test('connects to an https server and confirms it', () async {
    final connection = oauthServer230();
    connector.handler = (_) async => connection;

    await controller().connect('vikunja.example.com');

    expect(connector.inputs, ['vikunja.example.com']);
    expect(connector.cancelTokens.single, isNotNull);
    expect(states, [
      isA<ConnectServerIdle>(),
      isA<ConnectServerConnecting>().having(
        (s) => s.input,
        'input',
        'vikunja.example.com',
      ),
      isA<ConnectServerConnected>().having(
        (s) => s.connection,
        'connection',
        same(connection),
      ),
    ]);
    expect(currentServer(), same(connection));
  });

  test('connects to an unsupported server without failing', () async {
    final connection = legacyServer100();
    connector.handler = (_) async => connection;

    await controller().connect('old.example.com');

    expect(state(), isA<ConnectServerConnected>());
    expect(currentServer()?.capabilities.tier, SupportTier.unsupported);
  });

  group('plain http', () {
    late ServerConnection connection;

    setUp(() async {
      connection = insecureServer();
      connector.handler = (_) async => connection;
      await controller().connect('192.168.1.20:3456');
    });

    test('waits for consent before confirming', () {
      expect(state(), isA<ConnectServerAwaitingInsecureConsent>());
      expect(currentServer(), isNull);
    });

    test('accepting confirms the server', () {
      controller().acceptInsecureConnection();

      expect(state(), isA<ConnectServerConnected>());
      expect(currentServer(), same(connection));
    });

    test('declining returns to idle without a server', () {
      controller().declineInsecureConnection();

      expect(state(), isA<ConnectServerIdle>());
      expect(currentServer(), isNull);
    });
  });

  test('reports a connection failure', () async {
    final failure = ServerUnreachable(Uri.parse('https://nope.example.com'));
    connector.handler = (_) async => throw failure;

    await controller().connect('nope.example.com');

    expect(
      state(),
      isA<ConnectServerFailed>()
          .having((s) => s.failure, 'failure', same(failure))
          .having((s) => s.input, 'input', 'nope.example.com'),
    );
    expect(currentServer(), isNull);
  });

  test('reports unexpected errors as a failure without a cause', () async {
    connector.handler = (_) async => throw StateError('bug');

    await controller().connect('vikunja.example.com');

    expect(
      state(),
      isA<ConnectServerFailed>().having((s) => s.failure, 'failure', isNull),
    );
  });

  test('cancel aborts the request and ignores its late result', () async {
    final pending = Completer<ServerConnection>();
    connector.handler = (_) => pending.future;

    final connecting = controller().connect('slow.example.com');
    expect(state(), isA<ConnectServerConnecting>());

    controller().cancel();
    expect(connector.cancelTokens.single?.isCancelled, isTrue);
    expect(state(), isA<ConnectServerIdle>());

    pending.complete(oauthServer230());
    await connecting;
    expect(state(), isA<ConnectServerIdle>());
    expect(currentServer(), isNull);
  });

  test('a cancelled request is not logged as a failure', () async {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    connector.handler = (_) => Completer<ServerConnection>().future;

    final connecting = controller().connect('slow.example.com');
    controller().cancel();
    await connecting;

    expect(state(), isA<ConnectServerIdle>());
    expect(records.where((record) => record.level >= Level.SEVERE), isEmpty);
  });

  test('consent and cancel do nothing outside their state', () async {
    controller()
      ..acceptInsecureConnection()
      ..declineInsecureConnection()
      ..cancel();
    expect(states, [isA<ConnectServerIdle>()]);

    connector.handler = (_) async => oauthServer230();
    await controller().connect('vikunja.example.com');
    controller()
      ..acceptInsecureConnection()
      ..declineInsecureConnection()
      ..cancel();
    expect(state(), isA<ConnectServerConnected>());
    expect(currentServer(), isNotNull);
  });

  test('ignores a second connect while one is running', () async {
    final pending = Completer<ServerConnection>();
    connector.handler = (_) => pending.future;

    final first = controller().connect('a.example.com');
    await controller().connect('b.example.com');
    pending.complete(oauthServer230());
    await first;

    expect(connector.inputs, ['a.example.com']);
  });

  test('a new attempt clears the previously confirmed server', () async {
    connector.handler = (_) async => oauthServer230();
    await controller().connect('vikunja.example.com');
    expect(currentServer(), isNotNull);

    final pending = Completer<ServerConnection>();
    connector.handler = (_) => pending.future;
    unawaited(controller().connect('other.example.com'));

    expect(currentServer(), isNull);
    controller().cancel();
  });

  test('reset clears a failure but not a running attempt', () async {
    connector.handler = (_) async => throw const InvalidServerAddress('::');
    await controller().connect('::');
    controller().reset();
    expect(state(), isA<ConnectServerIdle>());

    connector.handler = (_) => Completer<ServerConnection>().future;
    unawaited(controller().connect('vikunja.example.com'));
    controller().reset();
    expect(state(), isA<ConnectServerConnecting>());
    controller().cancel();
  });

  test('disposing the controller cancels the running request', () {
    final ownContainer = ProviderContainer(
      overrides: [serverConnectorProvider.overrideWithValue(connector)],
    )..listen(connectServerControllerProvider, (_, _) {});
    unawaited(
      ownContainer
          .read(connectServerControllerProvider.notifier)
          .connect('vikunja.example.com'),
    );

    ownContainer.dispose();

    expect(connector.cancelTokens.single?.isCancelled, isTrue);
  });
}
