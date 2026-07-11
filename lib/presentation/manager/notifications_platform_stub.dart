class BackgroundPort {
  BackgroundPort();

  dynamic get sendPort => null;

  void listen(void Function(dynamic)? callback) {}

  static dynamic lookupPortByName(String name) => null;

  static bool registerPortWithName(dynamic port, String name) => false;

  static void removePortNameMapping(String name) {}
}
