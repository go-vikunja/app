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

  group('a paused listener', () {
    test('gets nothing until it resumes, then the newest value once', () async {
      final active = <int>[];
      final paused = <int>[];
      final a = shared.stream.listen(active.add);
      final b = shared.stream.listen(paused.add);
      upstream.add(1);
      await pumpEventQueue();

      b.pause();
      upstream
        ..add(2)
        ..add(3);
      await pumpEventQueue();
      expect(active, [1, 2, 3]);
      expect(paused, [1]);

      b.resume();
      await pumpEventQueue();
      expect(paused, [1, 3]);
      await Future.wait([a.cancel(), b.cancel()]);
    });

    test('that missed nothing gets nothing on resume', () async {
      final values = <int>[];
      final a = shared.stream.listen(values.add);
      upstream.add(1);
      await pumpEventQueue();

      a.pause();
      await pumpEventQueue();
      a.resume();
      await pumpEventQueue();

      expect(values, [1]);
      await a.cancel();
    });

    test('gets the newest value, then an error that came after it', () async {
      final values = <int>[];
      final errors = <Object>[];
      final a = shared.stream.listen((_) {}, onError: (Object _) {});
      final b = shared.stream.listen(values.add, onError: errors.add);
      upstream.add(1);
      await pumpEventQueue();

      b.pause();
      upstream
        ..add(2)
        ..addError(StateError('query failed'));
      await pumpEventQueue();
      b.resume();
      await pumpEventQueue();
      expect(values, [1, 2]);
      expect(errors, [isA<StateError>()]);

      b.pause();
      upstream
        ..addError(StateError('query failed'))
        ..add(3);
      await pumpEventQueue();
      b.resume();
      await pumpEventQueue();
      expect(values, [1, 2, 3]);
      expect(errors, hasLength(1), reason: 'a newer value replaced it');
      await Future.wait([a.cancel(), b.cancel()]);
    });

    test('gets what it missed before the end', () async {
      final values = <int>[];
      var done = false;
      final a = shared.stream.listen((_) {});
      final b = shared.stream.listen(values.add, onDone: () => done = true);
      upstream.add(1);
      await pumpEventQueue();

      b.pause();
      upstream.add(2);
      await upstream.close();
      await pumpEventQueue();
      expect(values, [1]);

      b.resume();
      await pumpEventQueue();
      expect(values, [1, 2]);
      expect(done, isTrue);
      await Future.wait([a.cancel(), b.cancel()]);
    });
  });

  test('the subscription is paused while every listener is and resumes '
      'with the first that is not', () async {
    final a = shared.stream.listen((_) {});
    final b = shared.stream.listen((_) {});
    upstream.add(1);
    await pumpEventQueue();

    a.pause();
    expect(upstream.isPaused, isFalse);
    b.pause();
    expect(upstream.isPaused, isTrue);
    upstream.add(2);
    b.resume();
    await pumpEventQueue();
    expect(upstream.isPaused, isFalse);

    b.pause();
    expect(upstream.isPaused, isTrue);
    final joined = <int>[];
    final c = shared.stream.listen(joined.add);
    expect(upstream.isPaused, isFalse, reason: 'a new listener resumes it');
    await pumpEventQueue();
    expect(joined, [2]);

    await c.cancel();
    expect(upstream.isPaused, isTrue, reason: 'the rest are paused');
    await b.cancel();
    expect(upstream.hasListener, isTrue);
    await a.cancel();
    expect(upstream.hasListener, isFalse);
    expect(opened, 1);
  });

  group('switchLatest', () {
    late StreamController<int> source;
    late Map<int, StreamController<String>> inners;
    late Stream<String> switched;

    setUp(() {
      source = StreamController<int>();
      inners = {};
      switched = switchLatest(
        source.stream,
        (value) => (inners[value] = StreamController<String>()).stream,
      );
    });

    test('a pause reaches the source and the current inner stream', () async {
      final seen = <String>[];
      final subscription = switched.listen(seen.add);
      addTearDown(subscription.cancel);
      source.add(1);
      await pumpEventQueue();

      subscription.pause();
      expect(source.isPaused, isTrue);
      expect(inners[1]!.isPaused, isTrue);

      subscription.resume();
      await pumpEventQueue();
      expect(source.isPaused, isFalse);
      expect(inners[1]!.isPaused, isFalse);
      inners[1]!.add('a');
      await pumpEventQueue();
      expect(seen, ['a']);
    });

    test('an inner stream that starts while paused starts paused', () async {
      final unpausable = _UnpausableSource();
      final inners = <int, StreamController<String>>{};
      final subscription = switchLatest(
        unpausable,
        (value) => (inners[value] = StreamController<String>()).stream,
      ).listen((_) {});
      addTearDown(subscription.cancel);

      subscription.pause();
      unpausable.add(1);
      expect(inners[1]!.isPaused, isTrue);

      subscription.resume();
      await pumpEventQueue();
      expect(inners[1]!.isPaused, isFalse);
    });
  });
}

/// Delivers even while paused, as no stream of the app does: the only way
/// to start an inner stream while the subscriber is paused.
final class _UnpausableSource extends Stream<int> {
  void Function(int value)? _onData;

  void add(int value) => _onData?.call(value);

  @override
  StreamSubscription<int> listen(
    void Function(int value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    return _UnpausableSubscription(() => _onData = null);
  }
}

final class _UnpausableSubscription extends Fake
    implements StreamSubscription<int> {
  new(this._cancel);

  final void Function() _cancel;

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<void> cancel() async => _cancel();
}
