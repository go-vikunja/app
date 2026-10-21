import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';

import '../../helpers/server_connections.dart';

final class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 500);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // The server names a session after the User-Agent of the request that
  // created it, so the sessions list shows "Rurana" only if the exchange
  // sends it.
  test('the code exchange and the refresh send the app User-Agent', () async {
    const userAgent = 'Rurana/0.31.0+31 (android 15)';
    final adapter = _RecordingAdapter();
    final gateway = ApiTokenGateway(
      createDio(
        userAgent: userAgent,
        httpClientAdapter: adapter,
        logRequests: false,
      ),
    );
    final connection = fullServer270();

    await expectLater(
      gateway.exchangeCode(
        connection,
        code: 'code',
        request: AuthorizationRequest.create(connection, appOAuthClient),
      ),
      throwsA(isA<VikunjaFailure>()),
    );
    await expectLater(
      gateway.refresh(connection, 'refresh'),
      throwsA(isA<VikunjaFailure>()),
    );

    expect(adapter.requests, hasLength(2));
    for (final request in adapter.requests) {
      expect(request.path, endsWith('/oauth/token'));
      expect(request.headers['User-Agent'], userAgent);
    }
  });
}
