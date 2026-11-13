import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A WebView platform that records what the app asks of it; a test plays
/// the page through [FakeWebViewController.post] and the WebView's own
/// navigations through [FakeNavigationDelegate.request].
final class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeWebViewController> controllers = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

final class FakeWebViewController extends PlatformWebViewController {
  new(super.params) : super.implementation();

  String? loadedAsset;
  JavaScriptMode? javaScriptMode;
  bool? zoomEnabled;
  Color? backgroundColor;
  FakeNavigationDelegate? navigationDelegate;
  bool consoleHandled = false;
  final Map<String, void Function(JavaScriptMessage)> channels = {};
  final List<String> scripts = [];

  /// A message the page posts to the channel [channel].
  void post(String message, {String channel = 'VikunjaEditor'}) =>
      channels[channel]!(JavaScriptMessage(message: message));

  @override
  Future<void> loadFlutterAsset(String key) async => loadedAsset = key;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      this.javaScriptMode = javaScriptMode;

  @override
  Future<void> enableZoom(bool enabled) async => zoomEnabled = enabled;

  @override
  Future<void> setBackgroundColor(Color color) async => backgroundColor = color;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => navigationDelegate = handler as FakeNavigationDelegate;

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage,
  ) async => consoleHandled = true;

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async => channels[javaScriptChannelParams.name] =
      javaScriptChannelParams.onMessageReceived;

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);
}

final class FakeNavigationDelegate extends PlatformNavigationDelegate {
  new(super.params) : super.implementation();

  late NavigationRequestCallback _onNavigationRequest;

  /// What the app decides for a navigation to [url].
  Future<NavigationDecision> request(
    String url, {
    bool isMainFrame = true,
  }) async => await _onNavigationRequest(
    NavigationRequest(url: url, isMainFrame: isMainFrame),
  );

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => _onNavigationRequest = onNavigationRequest;

  late WebResourceErrorCallback _onWebResourceError;

  /// The WebView failed to load a resource.
  void fail(WebResourceError error) => _onWebResourceError(error);

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => _onWebResourceError = onWebResourceError;
}

final class _FakeWebViewWidget extends PlatformWebViewWidget {
  new(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
