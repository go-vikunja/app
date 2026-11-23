import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show defaultMaxBodyBytes, normalizeError;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';

const _url = 'https://vikunja.example.com/api/v1/tasks';

final class _Answer implements HttpClientAdapter {
  new(this.body);

  final ResponseBody Function() body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => body();

  @override
  void close({bool force = false}) {}
}

void main() {
  Dio dio(ResponseBody Function() body) => createDio(
    userAgent: 'Vikunja-App/test',
    httpClientAdapter: _Answer(body),
    logRequests: false,
  );

  final tooLarge = isA<DioException>().having(
    normalizeError,
    'normalized',
    isA<UnexpectedResponse>().having(
      (failure) => failure.message,
      'message',
      'a body larger than $defaultMaxBodyBytes bytes',
    ),
  );

  test('an answer that declares more than 64 MiB is refused', () async {
    final declared = dio(
      () => ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentLengthHeader: ['${64 * 1024 * 1024 + 1}'],
        },
      ),
    );

    await expectLater(declared.get<Object?>(_url), throwsA(tooLarge));
  });

  test('an endless answer is refused once it passes 64 MiB', () async {
    final chunk = Uint8List(1024 * 1024);
    var cancelled = false;
    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () async {
        while (!cancelled) {
          controller.add(chunk);
          await Future<void>.delayed(Duration.zero);
        }
      },
      onCancel: () => cancelled = true,
    );
    final endless = dio(() => ResponseBody(controller.stream, 200));

    await expectLater(endless.get<Object?>(_url), throwsA(tooLarge));
    expect(cancelled, isTrue);
  }, timeout: const Timeout(Duration(seconds: 20)));

  testWidgets('an answer within the cap ends in a widget test too', (
    tester,
  ) async {
    final small = dio(() => ResponseBody.fromString('{"id":1}', 200));
    Object? data;
    unawaited(
      small.get<Object?>(_url).then((response) => data = response.data),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(data, '{"id":1}');
  });
}
