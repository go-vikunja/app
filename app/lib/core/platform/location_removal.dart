import 'package:flutter/services.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

/// Takes the location out of a photo or video picked on iOS, in place and
/// without encoding a JPEG, HEIC or video again, as Android's photo picker
/// does on its own. A file without a location stays untouched.
abstract interface class LocationRemoval {
  Future<void> removeFrom(String path);
}

final class PlatformLocationRemoval implements LocationRemoval {
  new({this._channel = deviceChannel});

  final MethodChannel _channel;

  @override
  Future<void> removeFrom(String path) =>
      _channel.invokeMethod<void>('removeLocation', {'path': path});
}
