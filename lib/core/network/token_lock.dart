import 'dart:async';

import 'package:vikunja_app/core/network/token_lock_stub.dart'
    if (dart.library.io) 'package:vikunja_app/core/network/token_lock_native.dart';

class TokenLock {
  static void setLockDirectory(dynamic dir) => setTokenLockDirectory(dir);

  static Future<T> synchronized<T>(Future<T> Function() callback) =>
      tokenLock.synchronized(callback);
}
