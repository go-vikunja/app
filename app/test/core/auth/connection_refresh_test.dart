import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/connection_refresh.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';

const _root = 'https://tasks.example.org/vikunja';
const Set<ApiVersion> _both = {ApiVersion.v1, ApiVersion.v2};

ServerConnection _connection(
  String fixture, {
  String root = _root,
  Set<ApiVersion> apiVersions = _both,
  Map<String, Object?> Function(Map<String, Object?> json)? edit,
}) {
  final json = jsonDecode(
    File('../packages/vikunja_api/test/fixtures/$fixture').readAsStringSync(),
  ) as Map<String, Object?>;
  final info = parseServerInfo(edit?.call(json) ?? json);
  return ServerConnection(
    rootUri: Uri.parse(root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

RegisteredAccount _entry(String id, ServerConnection connection) =>
    RegisteredAccount(
      account: Account(
        id: id,
        serverRoot: connection.rootUri,
        userId: 7,
        username: 'alice',
        displayName: 'Alice Example',
        addedAt: DateTime.utc(2026, 10, 9),
        needsReauth: true,
      ),
      connection: connection,
    );

String _snapshot(ServerConnection connection) => jsonEncode([
  connection.rootUri.toString(),
  [for (final version in connection.apiVersions) version.name]..sort(),
  serverInfoToJson(connection.info),
]);

void main() {
  late MemoryPreferencesStore preferences;
  late AccountRegistry registry;
  late FakeServerConnector connector;
  late DateTime now;
  late ConnectionRefresh refresh;
  final stored271 = _connection('info_v2_2.7.0.json');
  final fresh280 = _connection('info_v2_2.8.0.json');

  setUp(() async {
    preferences = MemoryPreferencesStore();
    registry = AccountRegistry(preferences);
    connector = FakeServerConnector.succeeding(fresh280);
    now = DateTime.utc(2026, 11, 9, 8);
    refresh = ConnectionRefresh(
      registry: registry,
      connector: () => connector,
      clock: () => now,
    );
    await registry.upsert(_entry('a1', stored271));
    await registry.upsert(
      _entry(
        'b2',
        _connection(
          'info_v1_2.3.0.json',
          apiVersions: {ApiVersion.v1},
          root: 'https://other.example.com',
        ),
      ),
    );
  });

  Future<ServerConnection> storedConnection(String accountId) async =>
      (await AccountRegistry(preferences).find(accountId))!.connection;

  test('a server updated since the sign-in is stored with its new version, '
      'capabilities and legal links; the account stays as it was', () async {
    final states = <AccountRegistryState>[];
    final subscription = registry.changes.listen(states.add);
    addTearDown(subscription.cancel);
    connector.handler = (_) async => _connection(
      'info_v2_2.8.0.json',
      edit: (json) => {
        ...json,
        'legal': {
          'imprint_url': '',
          'privacy_policy_url': '',
          'links': [
            {'text': 'Imprint', 'url': 'https://example.org/imprint'},
            {'text': 'Terms', 'url': 'https://example.org/terms'},
          ],
        },
      },
    );

    expect(await refresh.refresh('a1'), isTrue);

    expect(connector.inputs, [_root]);
    final state = await AccountRegistry(preferences).load();
    final entry = state.find('a1')!;
    expect(entry.connection.info.version, const ServerVersion(2, 8, 0));
    expect(entry.connection.capabilities.tier, SupportTier.full);
    expect(entry.connection.apiVersions, _both);
    expect(
      entry.connection.info.legal.imprintUrl,
      Uri.parse('https://example.org/imprint'),
    );
    expect(entry.connection.info.legal.links, hasLength(2));
    expect(entry.account, _entry('a1', stored271).account);
    expect(state.activeAccountId, 'a1');
    expect(state.find('b2')!.connection.info.version!.display, '2.3.0');
    await pumpEventQueue();
    expect(states.single.find('a1')!.connection.info.version!.display, '2.8.0');
  });

  test('an unchanged server writes nothing', () async {
    final states = <AccountRegistryState>[];
    final subscription = registry.changes.listen(states.add);
    addTearDown(subscription.cancel);
    connector.handler = (_) async => _connection('info_v2_2.7.0.json');
    final before = preferences.values[AccountRegistry.storageKey];

    expect(await refresh.refresh('a1'), isFalse);

    expect(connector.inputs, [_root]);
    await pumpEventQueue();
    expect(states, isEmpty);
    expect(preferences.values[AccountRegistry.storageKey], before);
  });

  test('a failure is silent and keeps the stored connection', () async {
    for (final failing in <ServerConnector Function()>[
      () => FakeServerConnector.failing(ServerUnreachable(Uri.parse(_root))),
      () => FakeServerConnector.failing(
        ServerUnavailable(Uri.parse(_root), statusCode: 502),
      ),
      () => FakeServerConnector.failing(StateError('unexpected')),
      () => throw UnimplementedError('no HTTP client'),
    ]) {
      final refresh = ConnectionRefresh(
        registry: registry,
        connector: failing,
        clock: () => now,
      );

      expect(await refresh.refresh('a1'), isFalse);
    }

    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));
  });

  test('another root is another server and is not stored', () async {
    connector.handler = (_) async =>
        _connection('info_v2_2.8.0.json', root: 'https://tasks.example.org');

    expect(await refresh.refresh('a1'), isFalse);

    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));
  });

  test('an unsupported answer is not stored', () async {
    connector.handler = (_) async =>
        _connection('info_v1_2.0.0.json', apiVersions: {ApiVersion.v1});

    expect(await refresh.refresh('a1'), isFalse);

    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));
  });

  test('an account keeps /api/v2 when a refresh does not find it, and '
      'gains it when one does', () async {
    connector.handler = (_) async =>
        _connection('info_v2_2.7.0.json', apiVersions: {ApiVersion.v1});

    expect(await refresh.refresh('a1'), isFalse);
    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));

    connector.handler = (_) async =>
        _connection('info_v1_2.8.0.json', apiVersions: {ApiVersion.v1});

    expect(await refresh.refresh('a1'), isTrue);
    var stored = await storedConnection('a1');
    expect(stored.apiVersions, _both);
    expect(stored.info.version, const ServerVersion(2, 8, 0));
    expect(stored.capabilities.has(Capability.apiV2), isTrue);

    await registry.upsert(
      _entry(
        'a1',
        _connection('info_v1_2.7.0.json', apiVersions: {ApiVersion.v1}),
      ),
    );
    connector.handler = (_) async => fresh280;

    expect(await refresh.refresh('a1'), isTrue);
    stored = await storedConnection('a1');
    expect(stored.apiVersions, _both);
    expect(stored.capabilities.has(Capability.apiV2), isTrue);
  });

  test('an account keeps /api/v1 when only /api/v2 answers', () async {
    connector.handler = (_) async =>
        _connection('info_v2_2.7.0.json', apiVersions: {ApiVersion.v2});

    expect(await refresh.refresh('a1'), isFalse);
    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));

    connector.handler = (_) async =>
        _connection('info_v2_2.8.0.json', apiVersions: {ApiVersion.v2});

    expect(await refresh.refresh('a1'), isTrue);
    final stored = await storedConnection('a1');
    expect(stored.apiVersions, _both);
    expect(stored.info.version, const ServerVersion(2, 8, 0));
  });

  test('an account removed meanwhile is not written back', () async {
    connector.handler = (_) async {
      await registry.remove('a1');
      return fresh280;
    };

    expect(await refresh.refresh('a1'), isFalse);

    expect((await AccountRegistry(preferences).load()).find('a1'), isNull);
    expect(await refresh.refresh('unknown'), isFalse);
    expect(connector.inputs, [_root]);
  });

  test('in front: once per account when the app starts, then at most every '
      'interval', () async {
    await refresh.onForeground('a1');
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root]);

    await refresh.onForeground('b2');
    expect(connector.inputs, [_root, 'https://other.example.com']);

    now = now.add(refresh.interval - const Duration(minutes: 1));
    await refresh.onForeground('a1');
    expect(connector.inputs, hasLength(2));

    now = now.add(const Duration(minutes: 1));
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root, 'https://other.example.com', _root]);
  });

  test('a probe that did not reach the server is tried again after a few '
      'minutes', () async {
    connector = FakeServerConnector.failing(
      ServerUnreachable(Uri.parse(_root)),
    );

    await refresh.onForeground('a1');
    now = now.add(refresh.retryAfterFailure - const Duration(seconds: 1));
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root]);

    now = now.add(const Duration(seconds: 1));
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root, _root]);

    connector = FakeServerConnector.succeeding(fresh280);
    preferences.failNextRead.add(AccountRegistry.storageKey);
    now = now.add(refresh.retryAfterFailure);
    await refresh.onForeground('a1');
    expect(connector.inputs, isEmpty);

    now = now.add(refresh.retryAfterFailure);
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root]);
    expect((await storedConnection('a1')).info.version!.display, '2.8.0');
  });

  test('an answer waits for the full interval, also one refused or '
      'unchanged', () async {
    for (final answer in [
      _connection('info_v2_2.8.0.json', root: 'https://tasks.example.org'),
      stored271,
    ]) {
      final refresh = ConnectionRefresh(
        registry: registry,
        connector: () => connector,
        clock: () => now,
      );
      connector = FakeServerConnector.succeeding(answer);

      await refresh.onForeground('a1');
      now = now.add(refresh.interval - const Duration(minutes: 1));
      await refresh.onForeground('a1');
      expect(connector.inputs, [_root]);

      now = now.add(const Duration(minutes: 1));
      await refresh.onForeground('a1');
      expect(connector.inputs, [_root, _root]);
    }
    expect(_snapshot(await storedConnection('a1')), _snapshot(stored271));
  });

  test('an attempt in flight holds off every other for its account, '
      'however late; a failure counts from its end', () async {
    final answer = Completer<ServerConnection>();
    connector.handler = (_) => answer.future;

    final first = refresh.onForeground('a1');
    await pumpEventQueue();
    now = now.add(refresh.interval * 2);
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root]);

    answer.completeError(ServerUnreachable(Uri.parse(_root)));
    await first;
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root]);

    now = now.add(refresh.retryAfterFailure);
    await refresh.onForeground('a1');
    expect(connector.inputs, [_root, _root]);
  });
}
