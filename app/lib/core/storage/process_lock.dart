import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:logging/logging.dart';

final _log = Logger('ProcessLock');

/// A lock every isolate of this process honours: its holder registers a
/// port under [name] with the `IsolateNameServer`, which takes one port per
/// name, and its isolate's control port beside it. A file lock would not
/// do, as POSIX record locks belong to the process
/// (`file_lock_isolates_test.dart`).
final class ProcessLock {
  new(
    this.name, {
    this.pollInterval = const Duration(milliseconds: 5),
    this.checkHolderAfter = const Duration(seconds: 1),
    this.holderAnswer = const Duration(milliseconds: 500),
    this.giveUpAfter = const Duration(seconds: 10),
  });

  final String name;
  final Duration pollInterval;

  /// How long a waiter polls before it asks the holder whether its isolate
  /// still runs: one that ended while holding never lets go.
  final Duration checkHolderAfter;
  final Duration holderAnswer;

  /// Then [run] goes on without the lock, logged: a holder whose write
  /// never returns must not stop every other isolate's writes for good.
  final Duration giveUpAfter;

  String get _controlName => '$name/control';

  Future<T> run<T>(Future<T> Function() action) async {
    final port = RawReceivePort(null, 'process lock $name');
    final held = await _acquire(port.sendPort);
    try {
      return await action();
    } finally {
      if (held && IsolateNameServer.lookupPortByName(name) == port.sendPort) {
        // First, so that no waiter finds the next holder beside this
        // isolate's control port.
        if (IsolateNameServer.lookupPortByName(_controlName) ==
            Isolate.current.controlPort) {
          IsolateNameServer.removePortNameMapping(_controlName);
        }
        IsolateNameServer.removePortNameMapping(name);
      }
      port.close();
    }
  }

  Future<bool> _acquire(SendPort port) async {
    final waited = Stopwatch()..start();
    var nextCheck = checkHolderAfter;
    SendPort? seenWithoutControl;
    while (!IsolateNameServer.registerPortWithName(port, name)) {
      if (waited.elapsed >= giveUpAfter) {
        _log.warning(
          'The lock $name is still held after ${giveUpAfter.inSeconds} s; '
          'going on without it',
        );
        return false;
      }
      if (waited.elapsed >= nextCheck) {
        nextCheck = waited.elapsed + checkHolderAfter;
        final holder = IsolateNameServer.lookupPortByName(name);
        final control = IsolateNameServer.lookupPortByName(_controlName);
        final bool gone;
        if (holder == null) {
          gone = false;
        } else if (control == null) {
          // A live holder registers its control port right after the lock
          // and removes it right before letting go: one seen without it
          // twice has ended in between.
          gone = holder == seenWithoutControl;
          seenWithoutControl = holder;
        } else {
          gone =
              !await _answers(control) &&
              IsolateNameServer.lookupPortByName(name) == holder &&
              IsolateNameServer.lookupPortByName(_controlName) == control;
        }
        if (gone) {
          _log.warning('The holder of the lock $name has gone; taking it over');
          IsolateNameServer.removePortNameMapping(_controlName);
          IsolateNameServer.removePortNameMapping(name);
          continue;
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    IsolateNameServer.removePortNameMapping(_controlName);
    IsolateNameServer.registerPortWithName(
      Isolate.current.controlPort,
      _controlName,
    );
    return true;
  }

  /// A ping, at its default immediate priority, is answered between any two
  /// steps of a live isolate, also one busy with a long frame, and never by
  /// one that has ended.
  Future<bool> _answers(SendPort control) async {
    final answer = Completer<bool>();
    final reply = RawReceivePort((Object? _) {
      if (!answer.isCompleted) answer.complete(true);
    }, 'process lock $name check');
    try {
      Isolate(control).ping(reply.sendPort);
      return await answer.future.timeout(holderAnswer, onTimeout: () => false);
    } finally {
      reply.close();
    }
  }
}
