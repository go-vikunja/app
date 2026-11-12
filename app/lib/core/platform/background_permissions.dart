import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'background_permissions.g.dart';

final _log = Logger('BackgroundPermissions');

/// What the OS lets the app do in the background. Null where it is unknown
/// or does not exist on this platform or OS version.
@immutable
final class BackgroundState {
  const new({
    this.ignoresBatteryOptimizations,
    this.powerSaveMode,
    this.backgroundRestricted,
    this.standbyBucket,
    this.backgroundRefresh,
    this.lowPowerMode,
  });

  static const standbyBuckets = {
    'active',
    'workingSet',
    'frequent',
    'rare',
    'restricted',
    'other',
  };

  static const backgroundRefreshStates = {
    'available',
    'denied',
    'restricted',
    'unknown',
  };

  /// Android: the app is exempt from battery optimisation.
  final bool? ignoresBatteryOptimizations;

  /// Android's battery saver.
  final bool? powerSaveMode;

  /// Android 9 and newer: the user restricted the app's background work.
  final bool? backgroundRestricted;

  /// Android 9 and newer: one of [standbyBuckets].
  final String? standbyBucket;

  /// iOS's Background App Refresh: one of [backgroundRefreshStates] or
  /// `other`.
  final String? backgroundRefresh;

  /// iOS's Low Power Mode.
  final bool? lowPowerMode;

  @override
  bool operator ==(Object other) =>
      other is BackgroundState &&
      other.ignoresBatteryOptimizations == ignoresBatteryOptimizations &&
      other.powerSaveMode == powerSaveMode &&
      other.backgroundRestricted == backgroundRestricted &&
      other.standbyBucket == standbyBucket &&
      other.backgroundRefresh == backgroundRefresh &&
      other.lowPowerMode == lowPowerMode;

  @override
  int get hashCode => Object.hash(
    ignoresBatteryOptimizations,
    powerSaveMode,
    backgroundRestricted,
    standbyBucket,
    backgroundRefresh,
    lowPowerMode,
  );
}

abstract interface class BackgroundPermissions {
  /// Never throws; what cannot be read is null.
  Future<BackgroundState> read();
}

/// The device channel's `backgroundState`, which only the UI engine of the
/// Android and iOS apps has.
final class PlatformBackgroundPermissions implements BackgroundPermissions {
  new({this._channel = deviceChannel, bool? mobile})
    : _mobile = mobile ?? (Platform.isAndroid || Platform.isIOS);

  final MethodChannel _channel;
  final bool _mobile;

  @override
  Future<BackgroundState> read() async {
    if (!_mobile) return const BackgroundState();
    final Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>('backgroundState');
    } on MissingPluginException {
      return const BackgroundState();
    } on Object catch (error) {
      _log.info('Background state unavailable: ${error.runtimeType}');
      return const BackgroundState();
    }
    if (answer is! Map<Object?, Object?>) return const BackgroundState();
    final values = answer;
    bool? flag(String key) => switch (values[key]) {
      final bool value => value,
      _ => null,
    };
    String? oneOf(String key, Set<String> allowed) => switch (values[key]) {
      final String value => allowed.contains(value) ? value : 'other',
      _ => null,
    };
    return BackgroundState(
      ignoresBatteryOptimizations: flag('ignoresBatteryOptimizations'),
      powerSaveMode: flag('powerSaveMode'),
      backgroundRestricted: flag('backgroundRestricted'),
      standbyBucket: oneOf('standbyBucket', BackgroundState.standbyBuckets),
      backgroundRefresh: oneOf(
        'backgroundRefresh',
        BackgroundState.backgroundRefreshStates,
      ),
      lowPowerMode: flag('lowPowerMode'),
    );
  }
}

@Riverpod(keepAlive: true)
BackgroundPermissions backgroundPermissions(Ref ref) =>
    PlatformBackgroundPermissions();
