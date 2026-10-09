import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/access_token_source.dart';
import 'package:vikunja_api/src/auth/auth_interceptor.dart';
import 'package:vikunja_api/src/transport/retry_interceptor.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A client for one account: [base]'s adapter, timeouts and headers, base URL
/// `connection.apiBaseUri(connection.preferredApiVersion)`, a retry
/// interceptor for idempotent requests and the bearer/refresh interceptor.
/// [interceptors] run after those, e.g. for logging.
///
/// Closing the returned client leaves [base]'s adapter open.
Dio createAuthenticatedDio({
  required Dio base,
  required ServerConnection connection,
  required AccessTokenSource tokens,
  Iterable<Interceptor> interceptors = const [],
  RetryInterceptor Function(Dio dio)? retry,
}) {
  final apiBase = connection.apiBaseUri(connection.preferredApiVersion);
  // The platform clients would follow redirects past AuthInterceptor's server
  // check, possibly with the bearer token. v2 answers an old task by-index
  // address with a 307 to the current one; reads that need this must check
  // the Location the same way and re-issue the request through this client.
  final dio =
      Dio(base.options.copyWith(baseUrl: '$apiBase/', followRedirects: false))
        ..httpClientAdapter = _BorrowedAdapter(base.httpClientAdapter)
        ..transformer = base.transformer;
  dio.interceptors.addAll([
    AuthInterceptor(dio, connection, tokens),
    retry?.call(dio) ?? RetryInterceptor(dio),
    ...interceptors,
  ]);
  return dio;
}

// The base Dio owns the adapter, which every account's client shares.
final class _BorrowedAdapter implements HttpClientAdapter {
  new(this._adapter);

  final HttpClientAdapter _adapter;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _adapter.fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) {}
}
