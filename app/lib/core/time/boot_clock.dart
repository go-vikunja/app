import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'boot_clock.g.dart';

final _log = Logger('BootClock');

/// A clock that goes on while the device sleeps and that the user cannot
/// set: Android's `SystemClock.elapsedRealtime`, iOS's
/// `mach_continuous_time`. Dart has none: `Stopwatch` stops while Android
/// sleeps.
abstract interface class BootClock {
  /// The time since the device started; null where there is no such clock
  /// or it did not answer.
  Future<Duration?> sinceBoot();
}

final class PlatformBootClock implements BootClock {
  new({this._channel = deviceChannel, bool? supported})
    : _supported = supported ?? (Platform.isAndroid || Platform.isIOS);

  /// The app lock keeps the app covered while it waits.
  static const timeLimit = Duration(seconds: 2);

  final MethodChannel _channel;
  final bool _supported;

  @override
  Future<Duration?> sinceBoot() {
    // At once, so the app lock does not cover the app for nothing.
    if (!_supported) return SynchronousFuture(null);
    return _read();
  }

  Future<Duration?> _read() async {
    try {
      final millis = await _channel
          .invokeMethod<int>('sinceBoot')
          .timeout(timeLimit);
      return millis == null ? null : Duration(milliseconds: millis);
    } on Object catch (error) {
      _log.warning('No reading: ${error.runtimeType}');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
BootClock bootClock(Ref ref) => PlatformBootClock();
