import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/attachments/load_queue.dart';

void main() {
  late LoadQueue queue;
  late List<int> started;
  late List<Completer<int>> answers;
  late Map<int, CancelToken> tokens;

  QueuedLoad<int> add(int index) => queue.add((cancel) {
    started.add(index);
    tokens[index] = cancel;
    return answers[index].future;
  });

  QueuedLoad<int> addCancellable(int index) => queue.add((cancel) {
    started.add(index);
    tokens[index] = cancel;
    return Future.any([
      answers[index].future,
      cancel.whenCancel.then<int>((given) => throw given),
    ]);
  });

  setUp(() {
    queue = LoadQueue(maxRunning: 3);
    started = [];
    answers = List.generate(6, (_) => Completer<int>());
    tokens = {};
  });

  test(
    'runs three loads at once and the others in the order they were added',
    () async {
      final loads = [for (var index = 0; index < 6; index++) add(index)];
      expect(started, [0, 1, 2]);

      answers[1].complete(1);
      expect(await loads[1].result, 1);
      await pumpEventQueue();
      expect(started, [0, 1, 2, 3]);

      answers[0].complete(0);
      answers[2].complete(2);
      await pumpEventQueue();
      expect(started, [0, 1, 2, 3, 4, 5]);

      for (final index in [3, 4, 5]) {
        answers[index].complete(index);
      }
      expect(await Future.wait([for (final load in loads) load.result]), [
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );

  test(
    'a load given up while it waits never runs and frees no place',
    () async {
      final loads = [for (var index = 0; index < 5; index++) add(index)];
      var settled = false;
      loads[3].result.whenComplete(() => settled = true).ignore();

      loads[3].cancel();
      loads.add(add(5));
      await pumpEventQueue();
      expect(started, [0, 1, 2]);

      answers[0].complete(0);
      await pumpEventQueue();
      expect(started, [0, 1, 2, 4]);

      answers[1].complete(1);
      await pumpEventQueue();
      expect(started, [0, 1, 2, 4, 5]);

      for (final index in [2, 4, 5]) {
        answers[index].complete(index);
      }
      await pumpEventQueue();
      expect(started, [0, 1, 2, 4, 5]);
      expect(settled, isFalse);
    },
  );

  test('a load that fails frees its place for the next', () async {
    final loads = [
      add(0),
      queue.add<int>((_) {
        started.add(1);
        throw StateError('refused at once');
      }),
      add(2),
      add(3),
      add(4),
    ];
    expect(started, [0, 1, 2]);
    await pumpEventQueue();
    expect(started, [0, 1, 2, 3]);

    answers[0].completeError(StateError('refused'));
    await expectLater(
      loads[0].result,
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'refused')),
    );
    await pumpEventQueue();
    expect(started, [0, 1, 2, 3, 4]);

    for (final index in [2, 3, 4]) {
      answers[index].complete(index);
    }
    expect(await Future.wait([for (final load in loads.skip(2)) load.result]), [
      2,
      3,
      4,
    ]);
  });

  test('giving up a load that runs cancels it, and the next one starts as '
      'it ends', () async {
    final loads = [
      for (var index = 0; index < 5; index++) addCancellable(index),
    ];

    loads[1].cancel();
    expect(tokens[1]!.isCancelled, isTrue);
    await expectLater(
      loads[1].result,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await pumpEventQueue();
    expect(started, [0, 1, 2, 3]);
    expect(tokens[0]!.isCancelled, isFalse);
    expect(tokens[2]!.isCancelled, isFalse);
    expect(tokens[3]!.isCancelled, isFalse);

    loads[3].cancel();
    await pumpEventQueue();
    expect(started, [0, 1, 2, 3, 4]);
  });

  test('a running load that goes on despite its cancel keeps its place '
      'until it ends, so no more than three run', () async {
    final loads = [for (var index = 0; index < 4; index++) add(index)];

    loads[0].cancel();
    expect(tokens[0]!.isCancelled, isTrue);
    await pumpEventQueue();
    expect(started, [0, 1, 2]);

    answers[0].complete(0);
    expect(await loads[0].result, 0);
    await pumpEventQueue();
    expect(started, [0, 1, 2, 3]);
  });
}
