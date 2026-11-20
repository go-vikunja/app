import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/errors/streamed_error_body.dart';

ResponseBody _body(Stream<Uint8List> stream) => ResponseBody(stream, 400);

void main() {
  test('reads a small body whole', () async {
    final bytes = await readErrorBody(
      _body(
        Stream.fromIterable([
          Uint8List.fromList([1, 2]),
          Uint8List.fromList([3]),
        ]),
      ),
    );

    expect(bytes, [1, 2, 3]);
  });

  test('an empty body is empty, not null', () async {
    expect(await readErrorBody(_body(const Stream.empty())), isEmpty);
  });

  test('stops after the chunk that passes the limit and cancels the '
      'stream', () async {
    var cancelled = false;
    var sent = 0;
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        for (var i = 0; i < 5; i++) {
          controller.add(Uint8List(maxErrorBodyBytes ~/ 2 + 1));
          sent++;
        }
      },
      onCancel: () => cancelled = true,
    );

    final bytes = await readErrorBody(_body(controller.stream));

    expect(bytes, hasLength(2 * (maxErrorBodyBytes ~/ 2 + 1)));
    expect(bytes!.length, greaterThan(maxErrorBodyBytes));
    expect(cancelled, isTrue);
    expect(sent, 5);
  });

  test('a body exactly at the limit is read whole', () async {
    final bytes = await readErrorBody(
      _body(Stream.value(Uint8List(maxErrorBodyBytes))),
    );

    expect(bytes, hasLength(maxErrorBodyBytes));
  });

  test('a stream that breaks off is null', () async {
    final bytes = await readErrorBody(
      _body(
        Stream.fromIterable([
          Uint8List.fromList([1]),
        ]).followedBy(Stream.error(const FormatException('cut'))),
      ),
    );

    expect(bytes, isNull);
  });

  test('the limit is 64 KiB', () {
    expect(maxErrorBodyBytes, 64 * 1024);
  });
}

extension on Stream<Uint8List> {
  Stream<Uint8List> followedBy(Stream<Uint8List> next) async* {
    yield* this;
    yield* next;
  }
}
