import 'dart:async';

class _WebTokenLock {
  final _mutex = _Mutex();

  Future<T> synchronized<T>(Future<T> Function() callback) {
    return _mutex.protect(callback);
  }
}

class _Mutex {
  Future<void> _last = Future.value();

  Future<T> protect<T>(Future<T> Function() callback) async {
    final completer = Completer<void>();
    final prev = _last;
    _last = completer.future;

    try {
      await prev;
    } catch (_) {}

    try {
      return await callback();
    } finally {
      completer.complete();
    }
  }
}

final tokenLock = _WebTokenLock();

void setTokenLockDirectory(dynamic dir) {
  // No-op on web
}
