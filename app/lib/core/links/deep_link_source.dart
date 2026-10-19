/// Links the platform hands to the app on its own scheme
/// (`<scheme>://task/…`): the one that started it and the ones that arrive
/// while it runs. Flutter's built-in deep linking delivers them as route
/// information; the router takes every URI of the app's scheme before
/// go_router can route it and passes it here, and with
/// `overridePlatformDefaultLocation` a cold start still begins at the
/// splash, so the start link is read once from the platform's default
/// route. `oauth/…` callbacks are never passed on, and no link is logged.
abstract interface class DeepLinkSource {
  /// The link that started the app, once; null when there was none.
  Future<Uri?> initialLink();

  Stream<Uri> get links;
}
