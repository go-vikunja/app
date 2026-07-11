import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

class BackgroundPort {
  final ReceivePort _receivePort = ReceivePort();

  BackgroundPort();

  SendPort get sendPort => _receivePort.sendPort;

  void listen(void Function(dynamic)? callback) {
    _receivePort.listen(callback);
  }

  static SendPort? lookupPortByName(String name) =>
      IsolateNameServer.lookupPortByName(name);

  static bool registerPortWithName(SendPort port, String name) =>
      IsolateNameServer.registerPortWithName(port, name);

  static void removePortNameMapping(String name) =>
      IsolateNameServer.removePortNameMapping(name);
}
