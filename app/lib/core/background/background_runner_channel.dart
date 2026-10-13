import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:logging/logging.dart';

final _log = Logger('BackgroundRunnerChannel');

/// How a sign-out in one isolate reaches a background run in another of
/// the same process: the run lets go of the account (its database client,
/// so the database isolate can close before the files are deleted, and its
/// session manager, so a refresh still on its way writes no tokens back).
/// A periodic run and a drain may overlap, hence a few slots.
final class BackgroundRunnerChannel {
  new _(this._port, this._name);

  static const _slots = 3;

  static String _slot(int index) => 'rurana.background-runner.$index';

  final ReceivePort _port;
  final String _name;

  /// Null when every slot is taken; the run then goes without.
  static BackgroundRunnerChannel? open(
    void Function(String accountId) onRelease,
  ) {
    for (var index = 0; index < _slots; index++) {
      final port = ReceivePort('background runner');
      final name = _slot(index);
      if (IsolateNameServer.registerPortWithName(port.sendPort, name)) {
        port.listen((message) {
          if (message is String) onRelease(message);
        });
        return BackgroundRunnerChannel._(port, name);
      }
      port.close();
    }
    _log.info('No channel slot free for this background run');
    return null;
  }

  /// Sign-out, before the account's database is closed for deletion.
  static void release(String accountId) {
    for (var index = 0; index < _slots; index++) {
      IsolateNameServer.lookupPortByName(_slot(index))?.send(accountId);
    }
  }

  void close() {
    IsolateNameServer.removePortNameMapping(_name);
    _port.close();
  }
}
