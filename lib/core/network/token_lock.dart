import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class TokenLock {
  static final _lock = _FilesystemTokenLock();
  static Directory? lockDirOverride;

  static void setLockDirectory(Directory? dir) => lockDirOverride = dir;

  static Future<T> synchronized<T>(Future<T> Function() callback) =>
      _lock.synchronized(callback);
}

class _FilesystemTokenLock {
  static const _retryDelay = Duration(milliseconds: 100);
  static const _staleLockThreshold = Duration(seconds: 30);
  static const _maxAttempts = 30;
  static const _lockFileName = 'vikunja_token_refresh.lock';
  static final _random = Random();

  final _mutex = _Mutex();

  Future<T> synchronized<T>(Future<T> Function() callback) {
    return _mutex.protect(() async {
      final baseDir =
          TokenLock.lockDirOverride ?? await getTemporaryDirectory();
      final lockPath = '${baseDir.path}/$_lockFileName';
      final uniqueId = _generateUniqueId();
      final tmpFile = File('${baseDir.path}/$_lockFileName.$uniqueId.tmp');

      try {
        await _acquireLock(lockPath, tmpFile, uniqueId);
        try {
          return await callback();
        } finally {
          await _releaseLock(lockPath, tmpFile);
        }
      } catch (e) {
        await _deleteQuietly(tmpFile);
        rethrow;
      }
    });
  }

  Future<void> _acquireLock(
    String lockPath,
    File tmpFile,
    String uniqueId,
  ) async {
    await tmpFile.writeAsString(uniqueId, flush: true);

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (await _tryCreateSymlink(lockPath, tmpFile.path) &&
          await _verifyOwnership(lockPath, uniqueId)) {
        return;
      }
      await Future.delayed(_retryDelay);
    }

    throw TimeoutException('Could not acquire token lock');
  }

  Future<void> _releaseLock(String lockPath, File tmpFile) async {
    try {
      final link = Link(lockPath);
      if (await link.exists()) await link.delete();
    } catch (_) {}
    await _deleteQuietly(tmpFile);
  }

  Future<bool> _tryCreateSymlink(String lockPath, String targetPath) async {
    try {
      await Link(lockPath).create(targetPath);
      return true;
    } on FileSystemException {
      await _removeIfStale(lockPath);
      return false;
    }
  }

  Future<bool> _verifyOwnership(String lockPath, String uniqueId) async {
    try {
      return await File(lockPath).readAsString() == uniqueId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _removeIfStale(String lockPath) async {
    try {
      final stat = await Link(lockPath).stat();
      if (DateTime.now().difference(stat.modified) > _staleLockThreshold) {
        await Link(lockPath).delete();
      }
    } catch (_) {}
  }

  String _generateUniqueId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final zoneHash = identityHashCode(Zone.current);
    final randomSuffix = _random.nextInt(1000000);
    return '${pid}_${zoneHash}_${timestamp}_$randomSuffix';
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
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
