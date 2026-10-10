import 'dart:async';

import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Records the calls and lets a test fail them or drive the status.
final class RecordingSyncEngine implements SyncEngine {
  new([SyncStatus initial = const SyncNeverRun()]) : _status = initial;

  SyncStatus _status;
  final _changes = StreamController<SyncStatus>.broadcast();
  int refreshCalls = 0;
  int ensureInitialSyncCalls = 0;
  bool disposed = false;

  /// Thrown by [refresh] and [ensureInitialSync] when set.
  Exception? error;

  /// Holds [refresh] and [ensureInitialSync] open while set.
  Completer<void>? gate;

  @override
  Stream<SyncStatus> get status => Stream.multi((subscriber) {
    subscriber.add(_status);
    final subscription = _changes.stream.listen(subscriber.add);
    subscriber.onCancel = subscription.cancel;
  });

  @override
  SyncStatus get currentStatus => _status;

  void emit(SyncStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  Future<void> ensureInitialSync() {
    ensureInitialSyncCalls++;
    return _call();
  }

  @override
  Future<void> refresh() {
    refreshCalls++;
    return _call();
  }

  Future<void> _call() async {
    await gate?.future;
    if (error case final error?) throw error;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _changes.close();
  }
}
