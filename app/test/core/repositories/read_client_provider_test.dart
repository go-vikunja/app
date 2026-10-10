import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

/// Answers every list with an empty v2 page and records the requests.
final class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'items': <Object>[],
        'total': 0,
        'page': 1,
        'per_page': 50,
        'total_pages': 1,
      }),
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
  test("reads go to the account's API with its session token", () async {
    final auth = AuthFakes();
    final tokens = issueTokens(issuedAt: DateTime.now().toUtc());
    final alice = await auth.seedAccount(fullServer270(), tokens: tokens);
    final adapter = _RecordingAdapter();
    final dio = createDio(
      userAgent: 'test',
      httpClientAdapter: adapter,
      logRequests: false,
    );
    final container = ProviderContainer(
      overrides: [...auth.overrides, dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);

    final client = container.read(readClientProvider(alice.id));
    final projects = await client.projects.listAll();

    expect(projects, isEmpty);
    final request = adapter.requests.single;
    expect(
      request.uri.replace(query: '').toString(),
      'https://tasks.example.org/vikunja/api/v2/projects?',
    );
    expect(request.headers['Authorization'], 'Bearer ${tokens.accessToken}');
    expect(request.headers['User-Agent'], 'test');
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
  });

  test('the repositories read through the same client', () async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final adapter = _RecordingAdapter();
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

    await container.read(projectRepositoryProvider)!.refresh();
    await container.read(taskRepositoryProvider)!.refreshOpenTasks();

    expect(adapter.requests.map((r) => r.uri.path), [
      '/vikunja/api/v2/projects',
      '/vikunja/api/v2/tasks',
    ]);
    final tasks = adapter.requests.last.uri.queryParametersAll;
    expect(tasks['filter'], ['done = false']);
    expect(tasks['sort_by'], ['due_date', 'id']);
    expect(tasks['order_by'], ['asc', 'desc']);
  });

  test('signing out drops the client and the repositories quietly', () async {
    final auth = AuthFakes();
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        dioProvider.overrideWithValue(
          createDio(
            userAgent: 'test',
            httpClientAdapter: _RecordingAdapter(),
            logRequests: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);
    final errors = <Object>[];
    container
      ..listen(projectsProvider, (_, next) {
        if (next case AsyncError(:final error)) errors.add(error);
      }, onError: (error, _) => errors.add(error))
      ..listen(openTasksProvider, (_, _) {});
    await pumpEventQueue();

    await container.read(signOutProvider).call(alice.id);
    await pumpEventQueue();

    expect(container.read(activeAccountIdProvider), isNull);
    expect(container.read(projectRepositoryProvider), isNull);
    expect(container.read(taskRepositoryProvider), isNull);
    expect(errors, isEmpty);
  });
}
