import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

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
}
