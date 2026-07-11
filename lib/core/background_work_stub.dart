@pragma('vm:entry-point')
Future<void> widgetCallback(Uri? uri) async {
  // Widget callbacks are not supported on web
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Background work is not supported on web
}
