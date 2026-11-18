import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

final _log = Logger('LocationRemoval');

/// Takes the location out of a photo or video on Android and iOS, in place
/// and without encoding it again. A file without a location stays
/// untouched. Throws when the location stays in the file.
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

extension RemoveLocations on LocationRemoval {
  /// One file after the other; answers the paths of the files that keep
  /// their location, for the user to decide on before they are uploaded.
  /// The log names why, never the file.
  Future<Set<String>> removeFromAll(Iterable<String> paths) async {
    final kept = <String>{};
    for (final path in paths) {
      try {
        await removeFrom(path);
      } on PlatformException catch (error) {
        kept.add(path);
        // The platforms' messages name a reason or a type, never a path.
        _log.warning(
          'A file keeps its location: PlatformException(${error.code}, '
          '${error.message})',
        );
      } on Object catch (error) {
        kept.add(path);
        _log.warning('A file keeps its location: ${error.runtimeType}');
      }
    }
    return kept;
  }
}
