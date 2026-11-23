import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/negotiation/info_probe.dart';
import 'package:vikunja_api/src/transport/body_cap_adapter.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

/// Answers every request with [body] and records whether the probe closed
/// the connection, which only a cancel does.
final class _StreamingAdapter implements HttpClientAdapter {
  new(this.body, {this.declaredLength});

  final Stream<Uint8List> Function() body;
  final int? declaredLength;
  bool closedByCaller = false;
  int sentBytes = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    unawaited(cancelFuture?.then((_) => closedByCaller = true));
    return ResponseBody(
      body().map((chunk) {
        sentBytes += chunk.length;
        return chunk;
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
        if (declaredLength != null)
          Headers.contentLengthHeader: ['$declaredLength'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Chunks [every] so long, as a socket delivers them: a stream that never
/// waits would starve the timers.
Stream<Uint8List> _endless(
  int chunkSize, {
  Duration every = Duration.zero,
}) async* {
  final chunk = Uint8List(chunkSize)..fillRange(0, chunkSize, 0x61);
  while (true) {
    await Future<void>.delayed(every);
    yield chunk;
  }
}

final Uri _root = Uri.parse('https://example.com');

void main() {
  test('an answer within the limits is read whole', () async {
    final dio = fakeDio({
      'https://example.com/api/v1/info': fixture('info_v1_2.7.0.json'),
    });

    final result = await probeInfo(
      dio,
      _root,
      ApiVersion.v1,
      timeout: const Duration(seconds: 5),
    );

    expect(
      result,
      isA<InfoAnswer>()
          .having((a) => a.statusCode, 'statusCode', 200)
          .having((a) => a.vikunjaInfo?['version'], 'version', 'v2.7.0'),
    );
  });

  test(
    'a body without end is cut at the limit and its connection closed',
    () async {
      final adapter = _StreamingAdapter(() => _endless(64 * 1024));
      final dio = Dio()..httpClientAdapter = adapter;

      final result = await probeInfo(
        dio,
        _root,
        ApiVersion.v1,
        timeout: const Duration(seconds: 2),
      );

      expect(
        result,
        isA<InfoAnswer>().having(
          (a) => a.body.length,
          'body length',
          maxProbeBodyBytes,
        ),
      );
      expect(adapter.sentBytes, lessThan(2 * maxProbeBodyBytes));
      await pumpEventQueue();
      expect(adapter.closedByCaller, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test('an answer that declares more than the transport cap is still read '
      'up to the limit', () async {
    final adapter = _StreamingAdapter(
      () => _endless(64 * 1024),
      declaredLength: defaultMaxBodyBytes + 1,
    );
    final dio = Dio()..httpClientAdapter = BodyCapAdapter(adapter);

    final result = await probeInfo(
      dio,
      _root,
      ApiVersion.v1,
      timeout: const Duration(seconds: 2),
    );

    expect(
      result,
      isA<InfoAnswer>()
          .having((a) => a.statusCode, 'statusCode', 200)
          .having((a) => a.body.length, 'body length', maxProbeBodyBytes),
    );
    await pumpEventQueue();
    expect(adapter.closedByCaller, isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a server that sends without end ends the probe after twice the '
      'timeout, as one that could not be reached in time', () async {
    final adapter = _StreamingAdapter(
      () => _endless(1, every: const Duration(milliseconds: 10)),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final watch = Stopwatch()..start();

    final result = await probeInfo(
      dio,
      _root,
      ApiVersion.v1,
      timeout: const Duration(milliseconds: 200),
    );

    expect(
      result,
      isA<InfoTransportError>().having(
        (e) => e.exception.type,
        'type',
        DioExceptionType.receiveTimeout,
      ),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    await pumpEventQueue();
    expect(adapter.closedByCaller, isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test("the caller's cancel still ends the probe with the cancel", () async {
    final adapter = _StreamingAdapter(
      () => _endless(1, every: const Duration(milliseconds: 10)),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final cancel = CancelToken();

    final probe = probeInfo(
      dio,
      _root,
      ApiVersion.v1,
      timeout: const Duration(seconds: 5),
      cancelToken: cancel,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancel.cancel();

    await expectLater(
      probe,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(adapter.closedByCaller, isTrue);
  });
}
