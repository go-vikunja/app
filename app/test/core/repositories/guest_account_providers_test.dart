import 'dart:convert';
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

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

typedef _Answer = ({int status, Object? body, Map<String, String> headers});

/// Answers by path and records every request.
final class _Server implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, _Answer> answers = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = answers[options.uri.path];
    if (answer == null) throw StateError('unexpected ${options.uri.path}');
    return ResponseBody.fromString(
      jsonEncode(answer.body),
      answer.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final MapEntry(:key, :value) in answer.headers.entries)
          key: [value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

_Answer _ok(Object? body, {Map<String, String> headers = const {}}) =>
    (status: 200, body: body, headers: headers);

Map<String, Object?> _projectJson({Object? maxPermission}) => {
  'id': 1378,
  'title': 'Garden',
  'parent_project_id': 0,
  'max_permission': maxPermission,
};

void main() {
  late DateTime now;
  late AuthFakes auth;
  late _Server server;
  late ProviderContainer container;

  setUp(() async {
    now = DateTime.now().toUtc();
    auth = AuthFakes();
    server = _Server();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        dioProvider.overrideWithValue(
          createDio(
            userAgent: 'test',
            httpClientAdapter: server,
            logRequests: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<RegisteredAccount> seedGuest(
    ServerConnection connection,
    LinkShareToken token,
  ) async {
    final guest = await auth.seedGuest(connection, token: token);
    await container.read(accountsProvider.future);
    return guest;
  }

  // Listened, so the client is not disposed between two requests.
  VikunjaReadClient readClient(String accountId) {
    final subscription = container.listen(
      readClientProvider(accountId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return subscription.read();
  }

  Future<bool> needsReauth(String accountId) async =>
      (await auth.registry.find(accountId))!.account.needsReauth;

  test("a guest's reads carry its link-share token, and the shared "
      "project's permission comes from its single read", () async {
    final token = issueLinkShareToken(issuedAt: now);
    final guest = await seedGuest(fullServer270(), token);
    server.answers
      ..['/vikunja/api/v2/projects'] = _ok({
        'items': [_projectJson()],
        'total': 0,
        'page': 1,
        'per_page': 50,
        'total_pages': 0,
      })
      ..['/vikunja/api/v2/projects/1378'] = _ok(_projectJson(maxPermission: 1));

    final projects = await readClient(guest.id).projects.list();

    expect(projects.items.single.maxPermission, Permission.write);
    expect(server.requests.map((r) => r.uri.path), [
      '/vikunja/api/v2/projects',
      '/vikunja/api/v2/projects/1378',
    ]);
    expect(
      server.requests.map((r) => r.headers['Authorization']),
      everyElement('Bearer ${token.jwt}'),
    );
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
    expect(auth.linkShareGateway.renewedTokens, isEmpty);
  });

  test("an unnamed guest takes its project's title from its reads", () async {
    final guest = await auth.seedGuest(
      fullServer270(),
      token: issueLinkShareToken(issuedAt: now),
      shareName: null,
    );
    await container.read(accountsProvider.future);
    server.answers['/vikunja/api/v2/projects'] = _ok({
      'items': [
        {..._projectJson(maxPermission: 0), 'title': 'Garden 2026'},
      ],
      'total': 1,
      'page': 1,
      'per_page': 50,
      'total_pages': 1,
    });

    await readClient(guest.id).projects.list();

    expect(
      (await auth.registry.find(guest.id))?.account.displayName,
      'Garden 2026',
    );
  });

  test("a user's reads stay with the session manager", () async {
    final tokens = issueTokens(issuedAt: now);
    final alice = await auth.seedAccount(fullServer270(), tokens: tokens);
    await container.read(accountsProvider.future);
    server.answers['/vikunja/api/v2/projects'] = _ok({
      'items': [_projectJson()],
      'total': 1,
      'page': 1,
      'per_page': 50,
      'total_pages': 1,
    });

    final projects = await readClient(alice.id).projects.list();

    expect(projects.items.single.maxPermission, isNull);
    expect(
      server.requests.single.headers['Authorization'],
      'Bearer ${tokens.accessToken}',
    );
    expect(container.read(accountIsGuestProvider(alice.id)), isFalse);
  });

  group('a deleted share ends the guest session', () {
    test('as v1 answers it, 400 code 13003', () async {
      final guest = await seedGuest(
        v1OnlyServer270(),
        issueLinkShareToken(issuedAt: now),
      );
      server.answers['/api/v1/projects/1378'] = (
        status: 400,
        body: {'code': 13003, 'message': 'The link share token is invalid.'},
        headers: const {},
      );

      await expectLater(
        readClient(guest.id).projects.read(1378),
        throwsA(isA<LinkShareGone>()),
      );
      await pumpEventQueue();

      expect(await needsReauth(guest.id), isTrue);
    });

    test('as v2 answers it, 401 without a code', () async {
      final guest = await seedGuest(
        fullServer270(),
        issueLinkShareToken(issuedAt: now),
      );
      server.answers['/vikunja/api/v2/projects/1378'] = (
        status: 401,
        body: {'title': 'Unauthorized', 'status': 401},
        headers: const {},
      );

      await expectLater(
        readClient(guest.id).projects.read(1378),
        throwsA(isA<LinkShareGone>()),
      );
      await pumpEventQueue();

      expect(await needsReauth(guest.id), isTrue);
      expect(auth.linkShareGateway.authentications, isEmpty);
    });
  });

  test('401 code 1027 (needs a user) does not end a guest session', () async {
    final guest = await seedGuest(
      fullServer270(),
      issueLinkShareToken(issuedAt: now),
    );
    server.answers['/vikunja/api/v2/projects/1378'] = (
      status: 401,
      body: {'code': 1027, 'message': 'This is not a user.'},
      headers: const {},
    );

    await expectLater(
      readClient(guest.id).projects.read(1378),
      throwsA(isA<DomainError>()),
    );
    await pumpEventQueue();

    expect(await needsReauth(guest.id), isFalse);
    expect(auth.linkShareGateway.authentications, isEmpty);
  });

  test('the guest flags follow the active account', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final guest = await seedGuest(
      fullServer270(),
      issueLinkShareToken(issuedAt: now),
    );

    expect(container.read(activeAccountIsGuestProvider), isTrue);
    expect(container.read(accountIsGuestProvider(guest.id)), isTrue);
    expect(container.read(accountIsGuestProvider(alice.id)), isFalse);

    await container.read(accountRegistryProvider).setActive(alice.id);
    await pumpEventQueue();

    expect(container.read(activeAccountIsGuestProvider), isFalse);
  });
}
