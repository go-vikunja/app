import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/repositories/local/shared_latest.dart';

void main() {
  late StreamController<int> upstream;
  late int opened;
  late SharedLatest<int> shared;

  setUp(() {
    opened = 0;
    upstream = StreamController<int>();
    shared = SharedLatest(() {
      opened++;
      upstream = StreamController<int>();
      return upstream.stream;
    });
  });

  test('every listener shares one subscription, a late one starts from '
      'the newest event', () async {
    final first = <int>[];
    final second = <int>[];
    final a = shared.stream.listen(first.add);
    final b = shared.stream.listen(second.add);
    upstream.add(1);
    await pumpEventQueue();

    final late = <int>[];
    final c = shared.stream.listen(late.add);
    await pumpEventQueue();
    upstream.add(2);
    await pumpEventQueue();

    expect(opened, 1);
    expect(first, [1, 2]);
    expect(second, [1, 2]);
    expect(late, [1, 2]);
    await Future.wait([a.cancel(), b.cancel(), c.cancel()]);
  });

  test('ends with the last listener and starts afresh with the next', () async {
    final a = shared.stream.listen((_) {});
    final b = shared.stream.listen((_) {});
    upstream.add(1);
    await pumpEventQueue();
    final ended = upstream;

    await a.cancel();
    expect(ended.hasListener, isTrue);
    await b.cancel();
    expect(ended.hasListener, isFalse);

    final again = <int>[];
    final c = shared.stream.listen(again.add);
    await pumpEventQueue();
    expect(opened, 2);
    expect(again, isEmpty, reason: 'no stale event from the last run');
    upstream.add(3);
    await pumpEventQueue();
    expect(again, [3]);
    await c.cancel();
  });

  test('passes errors to every listener and keeps going', () async {
    final errors = <Object>[];
    final values = <int>[];
    final a = shared.stream.listen(values.add, onError: errors.add);
    final b = shared.stream.listen((_) {}, onError: errors.add);

    upstream
      ..addError(StateError('query failed'))
      ..add(4);
    await pumpEventQueue();

    expect(errors, hasLength(2));
    expect(values, [4]);
    await Future.wait([a.cancel(), b.cancel()]);
  });
}
