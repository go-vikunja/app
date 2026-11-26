import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

final _log = Logger('ProcessLock');

// The C function returns bool; NativeApi declares its pointer with Int8.
final bool Function(int, Pointer<Dart_CObject>) _postMessage = NativeApi
    .postCObject
    .cast<NativeFunction<Bool Function(Int64, Pointer<Dart_CObject>)>>()
    .asFunction<bool Function(int, Pointer<Dart_CObject>)>();

// Dart_CObject is opaque in dart:ffi. For kNull, the union is unused.
// Its largest and most strictly aligned fields determine the layout
// (`dart_native_api.h`).
final class _NullMessage extends Struct {
  @Int()
  external int type;

  external _MessageStorage value;
}

final class _MessageStorage extends Union {
  @Int64()
  external int asInt64;

  @Double()
  external double asDouble;

  external _ExternalTypedData asExternalTypedData;
}

final class _ExternalTypedData extends Struct {
  @Int()
  external int type;

  @IntPtr()
  external int length;

  external Pointer<Uint8> data;
  external Pointer<Void> peer;
  external Pointer<NativeFunction<Void Function(Pointer<Void>, Pointer<Void>)>>
  callback;
}

final class ProcessLockTimeout implements Exception {
  const new(this.name);

  final String name;

  @override
  String toString() => 'Could not acquire process lock $name';
}

/// A lock every isolate of this process honours: its holder registers a
/// port with the `IsolateNameServer`, which takes one port per name.
/// A POSIX record lock would not do, as it belongs to the process
/// (`file_lock_isolates_test.dart`).
final class ProcessLock {
  new(
    this.name, {
    this.pollInterval = const Duration(milliseconds: 5),
    this.checkHolderAfter = const Duration(seconds: 1),
    this.giveUpAfter = const Duration(seconds: 10),
    this.requireLock = false,
  });

  final String name;
  final Duration pollInterval;

  /// How long a waiter polls before checking whether the holder's port closed.
  final Duration checkHolderAfter;

  /// Then [run] goes on without the lock, unless [requireLock] is set.
  final Duration giveUpAfter;

  /// For security-sensitive writes: never proceed unlocked or take over
  /// from an unresponsive holder that may still finish its write. Every
  /// caller for a security-sensitive [name] must set this.
  final bool requireLock;

  Future<T> run<T>(Future<T> Function() action) async {
    final port = RawReceivePort((Object? _) {}, 'process lock $name');
    List<String>? claims;
    try {
      claims = await _acquire(port.sendPort);
      if (claims != null && claims.length > 1) {
        _log.warning('The holder of the lock $name has gone; taking it over');
      }
      return await action();
    } finally {
      // Detach the chain before removing its links and closing our port.
      claims?.forEach(IsolateNameServer.removePortNameMapping);
      port.close();
    }
  }

  Future<List<String>?> _acquire(SendPort port) async {
    final waited = Stopwatch()..start();
    var nextCheck = checkHolderAfter;
    while (!IsolateNameServer.registerPortWithName(port, name)) {
      if (waited.elapsed >= giveUpAfter) {
        if (requireLock) throw ProcessLockTimeout(name);
        _log.warning(
          'The lock $name is still held after ${giveUpAfter.inSeconds} s; '
          'going on without it',
        );
        return null;
      }
      if (waited.elapsed >= nextCheck) {
        nextCheck = waited.elapsed + checkHolderAfter;
        final claims = _takeOver(port);
        if (claims != null) return claims;
      }
      await Future<void>.delayed(pollInterval);
    }
    return [name];
  }

  List<String>? _takeOver(SendPort port) {
    final root = IsolateNameServer.lookupPortByName(name);
    if (root == null) return null;
    final claims = [name];
    var holder = root;
    while (true) {
      // Claim a successor slot atomically. Looking up and then removing the
      // dead holder's mapping could otherwise remove another waiter's claim.
      final successorName =
          '$name/successor/${root.nativePort}/${holder.nativePort}';
      final successor = IsolateNameServer.lookupPortByName(successorName);
      claims.add(successorName);
      if (successor != null) {
        holder = successor;
      } else {
        if (_portIsOpen(holder) ||
            !IsolateNameServer.registerPortWithName(port, successorName)) {
          return null;
        }
        // The old chain may have been released while we walked it.
        if (IsolateNameServer.lookupPortByName(name) != root) {
          IsolateNameServer.removePortNameMapping(successorName);
          return null;
        }
        return claims;
      }
    }
  }

  /// The VM reports whether it enqueued a message, without needing the
  /// receiver to answer. A lock port closes only after release or isolate exit.
  static bool _portIsOpen(SendPort port) {
    final message = calloc<_NullMessage>(); // Dart_CObject_kNull == 0.
    try {
      return _postMessage(port.nativePort, message.cast());
    } finally {
      calloc.free(message);
    }
  }
}
