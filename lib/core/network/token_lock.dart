import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TokenLock {
  static TokenLockInterface _lock = _TokenLockFilesystem();

  static Future<T> synchronized<T>(Future<T> Function() callback) async {
    return _lock.synchronized(callback);
  }

  static void setLockImplementation(TokenLockInterface lock) {
    _lock = lock;
  }
}

abstract class TokenLockInterface {
  Future<T> synchronized<T>(Future<T> Function() callback);
}

class _TokenLockFilesystem implements TokenLockInterface {
  @override
  Future<T> synchronized<T>(Future<T> Function() callback) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vikunja_token_refresh.lock');
    if (!await file.exists()) {
      try {
        await file.create();
      } catch (_) {
        // Ignore likely race condition on creation
      }
    }

    final raf = await file.open(mode: FileMode.append);

    try {
      await raf.lock(FileLock.blockingExclusive);
      return await callback();
    } finally {
      await raf.unlock();
      await raf.close();
    }
  }
}
