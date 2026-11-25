import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart' show CancelToken;

/// Runs loads at most [maxRunning] at a time, the others in the order they
/// were added; a load given up before its turn never runs, and one given up
/// while it runs is cancelled through the token it was handed.
final class LoadQueue {
  new({required this.maxRunning});

  final int maxRunning;
  final _waiting = Queue<QueuedLoad<Object?>>();
  var _running = 0;

  QueuedLoad<T> add<T>(Future<T> Function(CancelToken cancel) load) {
    final queued = QueuedLoad<T>._(this, load);
    if (_running < maxRunning) {
      _start(queued);
    } else {
      _waiting.add(queued);
    }
    return queued;
  }

  void _start(QueuedLoad<Object?> queued) {
    _running++;
    unawaited(queued._run().whenComplete(_ended));
  }

  void _ended() {
    _running--;
    if (_waiting.isNotEmpty) _start(_waiting.removeFirst());
  }
}

final class QueuedLoad<T> {
  new _(this._queue, this._load);

  final LoadQueue _queue;
  final Future<T> Function(CancelToken cancel) _load;
  final _cancel = CancelToken();
  final _result = Completer<T>()..future.ignore();

  Future<T> get result => _result.future;

  /// Takes a waiting load out of the line; a running one keeps its place
  /// until its cancelled load ends, so no more than [LoadQueue.maxRunning]
  /// requests are ever under way (decision log: Descriptions, comments,
  /// attachments).
  void cancel() {
    if (!_queue._waiting.remove(this)) _cancel.cancel();
  }

  Future<void> _run() =>
      Future.sync(() => _load(_cancel))
          .then(_result.complete, onError: _result.completeError);
}
