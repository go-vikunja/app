import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/storage/process_lock.dart';

// Top-level, so that the closures sent to the other isolate capture nothing
// but the name.
Future<DateTime> _takeElsewhere(String name) =>
    Isolate.run(() => ProcessLock(name).run(() async => DateTime.now()));

Future<void> _holdInAnIsolateThatEnds(String name) => Isolate.run(() async {
  final holding = Completer<void>();
  unawaited(
    ProcessLock(name, requireLock: true, checkHolderAfter: Duration.zero).run(
      () {
        holding.complete();
        return Completer<void>().future;
      },
    ),
  );
  await holding.future;
});

Future<void> _endAfterRegisteringThePort(String name) => Isolate.run(() {
  IsolateNameServer.registerPortWithName(RawReceivePort().sendPort, name);
});

Future<void> _holdUntilKilled((String, SendPort) message) {
  final (name, holding) = message;
  return ProcessLock(name, requireLock: true).run(() {
    holding.send(null);
    return Completer<void>().future;
  });
}

Future<void> _competeForDeadLock(
  String name,
  SendPort events,
  String writer,
  bool requireLock,
) => Isolate.run(
  () =>
      ProcessLock(
        name,
        requireLock: requireLock,
        checkHolderAfter: Duration.zero,
      ).run(() async {
        final release = ReceivePort();
        events.send((writer, release.sendPort));
        await release.first;
      }),
);

/// Holds the lock while its isolate's event loop is busy for [busy], as in
/// a long frame; returns when that ended.
Future<DateTime> _holdBusyElsewhere(
  String name,
  SendPort holding,
  Duration busy,
) => Isolate.run(
  () => ProcessLock(name).run(() async {
    holding.send(null);
    final clock = Stopwatch()..start();
    while (clock.elapsed < busy) {}
    return DateTime.now();
  }),
);

void main() {
  var count = 0;
  late String name;

  setUp(() {
    name = 'process-lock-test.${count++}';
    addTearDown(() => IsolateNameServer.removePortNameMapping(name));
  });

  test('another isolate waits until the holder lets go', () async {
    final release = Completer<void>();
    final events = <String>[];
    final holding = ProcessLock(name).run(() async {
      events.add('held');
      await release.future;
      events.add('released');
    });
    await pumpEventQueue();

    final other = _takeElsewhere(name);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final releasedAt = DateTime.now();
    release.complete();
    await holding;

    expect((await other).isBefore(releasedAt), isFalse);
    expect(events, ['held', 'released']);
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test('a holder whose isolate is busy cannot be taken over', () async {
    final holding = ReceivePort();
    final releasedAt = _holdBusyElsewhere(
      name,
      holding.sendPort,
      const Duration(milliseconds: 1500),
    );
    await holding.first;

    final ranAt = await ProcessLock(
      name,
      checkHolderAfter: const Duration(milliseconds: 20),
      giveUpAfter: const Duration(seconds: 30),
    ).run(() async => DateTime.now());

    expect(ranAt.isBefore(await releasedAt), isFalse);
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test('two holders in one isolate take turns', () async {
    final events = <String>[];
    Future<void> hold(String who) => ProcessLock(name).run(() async {
      events.add('$who in');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      events.add('$who out');
    });

    await Future.wait([hold('a'), hold('b')]);

    expect(events, ['a in', 'a out', 'b in', 'b out']);
  });

  for (final (how, end) in [
    ('while holding', _holdInAnIsolateThatEnds),
    ('just after registering the port', _endAfterRegisteringThePort),
  ]) {
    test('a strict lock is recovered after its holder exits $how', () async {
      await end(name);
      expect(IsolateNameServer.lookupPortByName(name), isNotNull);

      final ran = await ProcessLock(
        name,
        requireLock: true,
        checkHolderAfter: const Duration(milliseconds: 20),
        giveUpAfter: const Duration(seconds: 1),
      ).run(() async => IsolateNameServer.lookupPortByName(name) != null);

      expect(ran, isTrue);
      expect(IsolateNameServer.lookupPortByName(name), isNull);
    });
  }

  test('a replacement can recover the lock even if its predecessor took '
      'over and then died', () async {
    await _holdInAnIsolateThatEnds(name);
    await _holdInAnIsolateThatEnds(name);

    final ran = await ProcessLock(
      name,
      requireLock: true,
      checkHolderAfter: Duration.zero,
      giveUpAfter: const Duration(seconds: 1),
    ).run(() async => true);

    expect(ran, isTrue);
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  for (final (policy, requireLock) in [
    ('strict', true),
    ('non-strict', false),
  ]) {
    test(
      '$policy waiters serialize after their live holder is killed',
      () async {
        final holding = ReceivePort();
        final exited = ReceivePort();
        final isolate = await Isolate.spawn(_holdUntilKilled, (
          name,
          holding.sendPort,
        ), onExit: exited.sendPort);
        addTearDown(() {
          isolate.kill(priority: Isolate.immediate);
          holding.close();
          exited.close();
        });
        await holding.first;

        final events = ReceivePort();
        final entered = StreamIterator(events.cast<(String, SendPort)>());
        final writers = [
          _competeForDeadLock(name, events.sendPort, 'a', requireLock),
          _competeForDeadLock(name, events.sendPort, 'b', requireLock),
        ];
        addTearDown(() async {
          await entered.cancel();
          events.close();
        });

        isolate.kill(priority: Isolate.immediate);
        await exited.first;
        expect(await entered.moveNext(), isTrue);
        final (first, releaseFirst) = entered.current;
        final secondEntered = entered.moveNext();
        final overlapped = await secondEntered.timeout(
          const Duration(milliseconds: 100),
          onTimeout: () => false,
        );
        releaseFirst.send(null);
        expect(await secondEntered, isTrue);
        final (second, releaseSecond) = entered.current;
        releaseSecond.send(null);
        await Future.wait(writers);

        expect(overlapped, isFalse);
        expect({first, second}, {'a', 'b'});
        expect(IsolateNameServer.lookupPortByName(name), isNull);
      },
    );
  }

  test('a live holder that never lets go is waited for until the limit, '
      'then the action runs without the lock and leaves it alone', () async {
    final release = Completer<void>();
    final holding = ProcessLock(name).run(() => release.future);
    await pumpEventQueue();
    final holder = IsolateNameServer.lookupPortByName(name);

    final waited = Stopwatch()..start();
    final ran = await ProcessLock(
      name,
      checkHolderAfter: const Duration(milliseconds: 20),
      giveUpAfter: const Duration(milliseconds: 200),
    ).run(() async => true);

    expect(ran, isTrue);
    expect(
      waited.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 200)),
    );
    expect(IsolateNameServer.lookupPortByName(name), holder);
    release.complete();
    await holding;
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test('an action that throws lets go of the lock', () async {
    await expectLater(
      ProcessLock(name).run<void>(() async => throw StateError('write')),
      throwsStateError,
    );

    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test('a strict waiter times out without running its write', () async {
    final release = Completer<void>();
    final holding = ProcessLock(name).run(() => release.future);
    await pumpEventQueue();
    var wrote = false;
    try {
      await expectLater(
        ProcessLock(
          name,
          requireLock: true,
          checkHolderAfter: Duration.zero,
          giveUpAfter: const Duration(milliseconds: 20),
        ).run(() async => wrote = true),
        throwsA(isA<ProcessLockTimeout>()),
      );
      expect(wrote, isFalse);
    } finally {
      release.complete();
      await holding;
    }
  });

  test('a strict waiter times out while a live isolate is paused', () async {
    final holding = ReceivePort();
    final exited = ReceivePort();
    final isolate = await Isolate.spawn(_holdUntilKilled, (
      name,
      holding.sendPort,
    ), onExit: exited.sendPort);
    try {
      await holding.first;
      isolate.pause();
      final holder = IsolateNameServer.lookupPortByName(name);
      var wrote = false;
      await expectLater(
        ProcessLock(
          name,
          requireLock: true,
          checkHolderAfter: Duration.zero,
          giveUpAfter: const Duration(milliseconds: 100),
        ).run(() async => wrote = true),
        throwsA(isA<ProcessLockTimeout>()),
      );
      expect(wrote, isFalse);
      expect(IsolateNameServer.lookupPortByName(name), holder);
    } finally {
      isolate.kill(priority: Isolate.immediate);
      await exited.first;
    }
  });
}
