import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// `RequestOptions.extra` key for the most bytes an answer's body may have
/// as it arrives; null lifts the cap, for a body that the request cuts
/// itself or writes to a file.
const maxBodyBytesKey = 'vikunja.maxBodyBytes';

/// The cap of an answer whose request does not set [maxBodyBytesKey].
const int defaultMaxBodyBytes = 64 * 1024 * 1024;

/// Refuses an answer whose body is larger than its request's cap, by its
/// `Content-Length` or by what arrives, and closes the connection: the
/// body fails with a `DioException` that carries an [UnexpectedResponse],
/// which is never retried. Everything else passes through unchanged.
final class BodyCapAdapter implements HttpClientAdapter {
  new(this.inner, {this.defaultMaxBytes = defaultMaxBodyBytes});

  final HttpClientAdapter inner;
  final int defaultMaxBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = await inner.fetch(options, requestStream, cancelFuture);
    final maxBytes = switch (options.extra) {
      {maxBodyBytesKey: final int maxBytes} => maxBytes,
      {maxBodyBytesKey: null} => null,
      _ => defaultMaxBytes,
    };
    if (maxBytes == null) return body;
    final tooLarge = DioException(
      requestOptions: options,
      error: UnexpectedResponse(
        body.statusCode,
        message: 'a body larger than $maxBytes bytes',
      ),
    );
    final declared = int.tryParse(
      body.headers[Headers.contentLengthHeader]?.firstOrNull ?? '',
    );
    if (declared != null &&
        declared > maxBytes &&
        _mayHaveBody(options, body.statusCode)) {
      // Each adapter closes the connection when its body's subscription
      // ends.
      body.stream.listen(null).cancel().ignore();
      body.stream = Stream.error(tooLarge);
    } else {
      body.stream = _capped(body.stream, maxBytes, tooLarge);
    }
    return body;
  }

  @override
  void close({bool force = false}) => inner.close(force: force);

  // Their Content-Length is that of a body they do not have.
  static bool _mayHaveBody(RequestOptions options, int status) =>
      options.method.toUpperCase() != 'HEAD' && status != 204 && status != 304;

  static Stream<Uint8List> _capped(
    Stream<Uint8List> source,
    int maxBytes,
    DioException tooLarge,
  ) {
    late final StreamSubscription<Uint8List> subscription;
    late final StreamController<Uint8List> capped;
    var received = 0;
    capped = StreamController<Uint8List>(
      onListen: () => subscription = source.listen(
        (chunk) {
          received += chunk.length;
          if (received <= maxBytes) {
            capped.add(chunk);
          } else {
            subscription.cancel().ignore();
            capped.addError(tooLarge);
            capped.close().ignore();
          }
        },
        onError: capped.addError,
        onDone: capped.close,
      ),
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      // Not waited for: a finished source answers with a future of the root
      // zone, which would hold back the end of the body in another zone.
      onCancel: () => subscription.cancel().ignore(),
    );
    return capped.stream;
  }
}
