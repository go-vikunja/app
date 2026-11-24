import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/test_database.dart';

/// Records each request as `METHOD path Authorization` and answers it with
/// task 1.
final class _TaskAdapter implements HttpClientAdapter {
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      '${options.method} ${options.uri.path} '
      '${options.headers['Authorization']}',
    );
    return ResponseBody.fromString(
      jsonEncode({'id': 1, 'title': 'Water the plants', 'project_id': 7}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('re-adding an account that is still signed in: a change sent while '
      'its new tokens are stored waits a short backoff, the sender is never '
      'paused, and the change goes out with the new session', () async {
    final now = DateTime.now().toUtc();
    var clock = now;
    final connection = fullServer270();
    final auth = AuthFakes();
    final alice = await auth.seedAccount(
      connection,
      tokens: issueTokens(issuedAt: now, sessionId: 'old-session'),
    );
    final fresh = issueTokens(issuedAt: now, sessionId: 'new-session');
    auth.serveUser(
      User(
        id: alice.account.userId,
        username: alice.account.username,
        name: alice.account.displayName,
      ),
      now: now,
    );
    auth.tokenGateway.onExchange = (_) async => fresh;
    final db = testDatabase();
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Water the plants', projectId: 7),
    ], syncRunId: 'run');
    final adapter = _TaskAdapter();
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
        clockProvider.overrideWithValue(() => clock),
        appDatabaseProvider.overrideWith((ref, _) => db),
        accountDatabaseFilesProvider.overrideWithValue(
          FakeAccountDatabaseFiles(),
        ),
        syncEngineProvider.overrideWith((ref, accountId) {
          final engine = RecordingSyncEngine(SyncIdle(lastSyncedAt: now));
          ref.onDispose(() => unawaited(engine.dispose()));
          return engine;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);
    final sender = container.read(outboxSenderProvider(alice.id));
    final states = <OutboxSenderState>[];
    final subscription = sender.states.listen(states.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    final writing = Completer<void>();
    final gate = Completer<void>();
    auth.secureStore.beforeWrite = (_) {
      if (!writing.isCompleted) writing.complete();
      return gate.future;
    };
    final signingIn = container.read(browserSignInProvider).signIn(connection);
    await writing.future;

    expect(
      await db.outboxDao.queueUpdate(
        1,
        TaskChanges(dueDate: DateChange.set(DateTime.utc(2026, 12, 1, 9))),
        now: now,
      ),
      isTrue,
    );
    await sender.drain();

    expect(adapter.requests, isEmpty);
    expect(sender.state, OutboxSenderState.waiting);
    expect(
      sender.blockedBy,
      isA<NetworkFailure>().having(
        (f) => f.cause,
        'cause',
        RefreshDeferred.signIn,
      ),
    );
    final op = (await db.outboxDao.all()).single;
    expect(op.state, OutboxState.pending.name);
    expect(op.sentAt, isNull);
    expect(
      op.nextAttemptAt,
      isA<DateTime>()
          .having((at) => at.isAfter(now), 'after the attempt', isTrue)
          .having(
            (at) => at.isAfter(now.add(OutboxSender.initialBackoff)),
            'beyond the first backoff',
            isFalse,
          ),
    );
    expect((await auth.registry.find(alice.id))!.account.needsReauth, isFalse);

    gate.complete();
    await signingIn;
    // A drain is what the queue lane's timer starts once the backoff is
    // over; the provider's sender runs on real timers.
    clock = op.nextAttemptAt!;
    await sender.drain();

    expect(
      [
        for (final request in adapter.requests)
          if (request.startsWith('PATCH ')) request,
      ],
      ['PATCH /vikunja/api/v2/tasks/1 Bearer ${fresh.accessToken}'],
    );
    expect(
      adapter.requests,
      everyElement(endsWith(' Bearer ${fresh.accessToken}')),
    );
    expect(await db.outboxDao.count(), 0);
    expect(states, isNot(contains(OutboxSenderState.paused)));
  });
}
