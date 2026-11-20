import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/async/first_value.dart';

void main() {
  test('the first value, and the stream is no longer listened to', () async {
    final source = StreamController<int>();
    addTearDown(source.close);
    source
      ..add(1)
      ..add(2);

    expect(await firstValue(source.stream, orElse: 0), 1);
    expect(source.hasListener, isFalse);
  });

  test('a stream that ends without a value gives orElse', () async {
    expect(await firstValue(const Stream<int?>.empty(), orElse: null), isNull);
    expect(
      await firstValue(const Stream<List<int>>.empty(), orElse: const <int>[]),
      isEmpty,
    );
  });

  test("an error before the first value is the future's", () async {
    final source = StreamController<int>();
    addTearDown(source.close);
    source
      ..addError(StateError('broken'))
      ..add(1);

    await expectLater(
      firstValue(source.stream, orElse: 0),
      throwsA(isA<StateError>()),
    );
    expect(source.hasListener, isFalse);
  });

  test('answers although the source never completes its cancel', () async {
    final cancelled = Completer<void>();
    final source = StreamController<int>(onCancel: () => cancelled.future)
      ..add(7);

    expect(await firstValue(source.stream, orElse: 0), 7);
    expect(cancelled.isCompleted, isFalse);
  });
}
