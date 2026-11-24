import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/test_database.dart';

/// Answers every request with a trash count.
final class _CountAdapter implements HttpClientAdapter {
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      '{"total":2,"by_others":1}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _ImageAdapter implements HttpClientAdapter {
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromBytes(
      [1, 2, 3],
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Without `/api/v1`, so previews take v2's own route from 2.7.1 on.
ServerConnection _v2Only(Map<String, Object?> changes) {
  final info = parseServerInfo({
    ...serverInfoToJson(fullServer270().info),
    ...changes,
  });
  return ServerConnection(
    rootUri: fullServer270().rootUri,
    apiVersions: const {ApiVersion.v2},
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: const {ApiVersion.v2},
    ),
  );
}

void main() {
  test('a stored server upgrade reaches the read client; another message of '
      'the day leaves it as it is', () async {
    final auth = AuthFakes();
    final alice = await auth.seedAccount(
      _v2Only({}),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final adapter = _ImageAdapter();
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        dioProvider.overrideWithValue(
          createDio(
            userAgent: 'test',
            httpClientAdapter: adapter,
            logRequests: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);
    final client = container.listen(readClientProvider(alice.id), (_, _) {});
    final registry = container.read(accountRegistryProvider);
    Future<String> previewRequest() async {
      await client.read().attachments.fetch(
        1,
        2,
        preview: AttachmentPreviewSize.medium,
      );
      final uri = adapter.requests.last;
      return '${uri.path}?${uri.query}';
    }

    expect(
      await previewRequest(),
      '/vikunja/api/v2/tasks/1/attachments/2?preview_size=md',
    );

    final before = client.read();
    await registry.updateConnection(
      alice.id,
      (_) => _v2Only({'motd': 'Back on Monday.'}),
    );
    await pumpEventQueue();
    expect(client.read(), same(before));

    await registry.updateConnection(
      alice.id,
      (_) => _v2Only({'motd': 'Back on Monday.', 'version': 'v2.7.1'}),
    );
    await pumpEventQueue();
    expect(
      await previewRequest(),
      '/vikunja/api/v2/tasks/1/attachments/2/preview?size=md',
    );
  });

  test('the trash port follows a server upgrade to 2.8: refused before any '
      'request until then', () async {
    final auth = AuthFakes();
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final adapter = _CountAdapter();
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        dioProvider.overrideWithValue(
          createDio(
            userAgent: 'test',
            httpClientAdapter: adapter,
            logRequests: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);
    final port = container.listen(trashPortProvider(alice.id), (_, _) {});

    await expectLater(
      port.read().taskCount(),
      throwsA(isA<NotFound>().having((f) => f.routeAbsent, 'route', true)),
    );
    expect(adapter.requests, isEmpty);

    await container
        .read(accountRegistryProvider)
        .updateConnection(alice.id, (_) => fullServer280());
    await pumpEventQueue();

    expect(
      await port.read().taskCount(),
      const TrashCount(total: 2, byOthers: 1),
    );
    expect(adapter.requests.single.path, '/vikunja/api/v2/tasks/deleted/count');
  });

  group('the sync status', () {
    late AuthFakes auth;
    late RegisteredAccount alice;
    late _CountAdapter adapter;
    late ProviderContainer container;
    late List<SyncStatus?> seen;

    setUp(() async {
      auth = AuthFakes();
      alice = await auth.seedAccount(
        _v2Only({}),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      auth.accountGateway.onCurrentUser = (_) async => User(
        id: alice.account.userId,
        username: alice.account.username,
        name: alice.account.displayName,
      );
      final db = testDatabase();
      final synced = DateTime.now().toUtc().toIso8601String();
      await db.syncStateDao.write({
        SyncStateKeys.lastSyncedAt: synced,
        SyncStateKeys.lastFullSyncAt: synced,
      });
      adapter = _CountAdapter();
      container = ProviderContainer(
        overrides: [
          ...auth.overrides,
          dioProvider.overrideWithValue(
            createDio(
              userAgent: 'test',
              httpClientAdapter: adapter,
              logRequests: false,
            ),
          ),
          appDatabaseProvider.overrideWith((ref, _) => db),
        ],
      );
      addTearDown(container.dispose);
      await container.read(accountsProvider.future);
      // As the router reads it: without a value carried over a reload.
      seen = [];
      container.listen(
        accountSyncStatusProvider(alice.id),
        (_, next) => seen.add(next.unwrapPrevious().value),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(seen.last, isA<SyncIdle>());
      seen.clear();
    });

    test('goes on over the engine a stored server upgrade rebuilds, and '
        'follows the new engine', () async {
      final engine = container.read(syncEngineProvider(alice.id));

      await container
          .read(accountRegistryProvider)
          .updateConnection(alice.id, (_) => _v2Only({'version': 'v2.7.1'}));
      await pumpEventQueue();

      final rebuilt = container.read(syncEngineProvider(alice.id));
      expect(rebuilt, isNot(same(engine)));
      // A status that started over would send the router to the first sync.
      expect(seen, everyElement(isA<SyncIdle>()));
      expect(
        container
            .read(accountSyncStatusProvider(alice.id))
            .unwrapPrevious()
            .value,
        isA<SyncIdle>(),
      );

      await expectLater(rebuilt.refresh(), throwsA(isA<VikunjaFailure>()));
      expect(adapter.requests, isNotEmpty);
      expect(
        container.read(accountSyncStatusProvider(alice.id)).value,
        isA<SyncFailed>(),
      );
    });

    test('starts over for an account that was removed and is signed in '
        'again', () async {
      await container.read(accountRegistryProvider).remove(alice.id);
      await pumpEventQueue();
      expect(
        container.read(accountSyncStatusProvider(alice.id)).hasError,
        isTrue,
      );
      seen.clear();

      await auth.seedAccount(
        _v2Only({}),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      await pumpEventQueue();

      expect(seen.first, isNull);
      expect(seen.last, isA<SyncIdle>());
    });
  });
}
