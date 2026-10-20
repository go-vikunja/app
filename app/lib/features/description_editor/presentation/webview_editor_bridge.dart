import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_bridge.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

part 'webview_editor_bridge.g.dart';

final _log = Logger('DescriptionEditor');

@riverpod
EditorBridgeFactory editorBridgeFactory(Ref ref) => WebViewEditorBridge.new;

/// The bundled editor page in a system WebView, locked to that one page:
/// every navigation after it loaded is prevented, the page itself forbids
/// every remote load by its CSP, and messages count only with the token
/// this load handed it.
final class WebViewEditorBridge implements EditorBridge {
  new({String? token}) : _token = token ?? _newToken();

  static const assetKey = 'assets/editor/editor.html';
  static const htmlTimeout = Duration(seconds: 10);

  final _controller = WebViewController();
  final String _token;
  final _events = StreamController<EditorEvent>.broadcast();
  final _pendingHtml = <int, Completer<EditorDocument>>{};
  EditorInit? _init;
  bool _loading = false;
  bool _initSent = false;
  bool _loaded = false;
  bool _stopped = false;
  int _lastRequest = 0;

  @override
  Stream<EditorEvent> get events => _events.stream;

  static String _newToken() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 24; i++) random.nextInt(256)]);
  }

  @override
  Future<void> start(EditorInit init, {required Color background}) async {
    _init = init;
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.enableZoom(false);
    await _controller.setBackgroundColor(background);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _decide,
        onWebResourceError: _onResourceError,
      ),
    );
    await _controller.setOnConsoleMessage(
      (message) => _log.fine('Editor page console: ${message.level.name}'),
    );
    await _controller.addJavaScriptChannel(
      editorChannelName,
      onMessageReceived: _receive,
    );
    await lockDownWebView(_controller.platform);
    _loading = true;
    await _controller.loadFlutterAsset(assetKey);
  }

  /// iOS reports the end of the WebView's process as a main-frame error;
  /// a prevented navigation can be one too, so only that one counts once
  /// the page is up.
  void _onResourceError(WebResourceError error) {
    _log.fine('Editor page resource error: ${error.errorType}');
    if (!(error.isForMainFrame ?? false)) return;
    final ended =
        error.errorType == WebResourceErrorType.webContentProcessTerminated;
    if (_loading || (ended && !_loaded)) {
      _add(const EditorFailed('load'));
    } else if (ended && !_stopped) {
      _log.warning('The editor page stopped');
      _stopped = true;
      _failPending(StateError('The editor page stopped'));
      _add(const EditorStopped());
    }
  }

  /// Only the editor page itself, and only until it is ready: links never
  /// open while editing.
  NavigationDecision _decide(NavigationRequest request) {
    if (_loading && request.isMainFrame && isEditorPage(request.url)) {
      return NavigationDecision.navigate;
    }
    _log.fine('Editor page navigation prevented');
    return NavigationDecision.prevent;
  }

  /// Where the platforms put the asset: Android under
  /// `file:///android_asset/flutter_assets/`, iOS in the app bundle's
  /// `flutter_assets`.
  @visibleForTesting
  static bool isEditorPage(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'file' &&
        !uri.hasQuery &&
        uri.path.endsWith('/flutter_assets/$assetKey');
  }

  void _receive(JavaScriptMessage message) {
    final event = decodeEditorMessage(
      message.message,
      token: _initSent ? _token : null,
    );
    switch (event) {
      case null:
        return;
      case EditorReady():
        _loading = false;
        _initSent = true;
        unawaited(_sendInit());
      case EditorHtml(:final requestId, :final document):
        _pendingHtml.remove(requestId)?.complete(document);
      // The page's first state means it has loaded the document; a failure
      // reported before that means it will not.
      case EditorStateChanged() when !_loaded:
        _loaded = true;
        _add(const EditorReady());
        _add(event);
      case final event:
        _add(event);
    }
  }

  Future<void> _sendInit() async {
    final init = _init;
    if (init == null) return;
    try {
      await _controller.runJavaScript(EditorMessages.init(init, token: _token));
    } on Object catch (error) {
      _log.warning('The editor page took no document: ${error.runtimeType}');
      _add(const EditorFailed('init'));
    }
  }

  void _add(EditorEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _run(String script) async {
    if (!_initSent || _stopped || _events.isClosed) return;
    try {
      await _controller.runJavaScript(script);
    } on Object catch (error) {
      _log.warning('A message to the editor page failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> command(EditorCommand command) =>
      _run(EditorMessages.command(command, token: _token));

  @override
  Future<void> insertMention(EditorMention mention) =>
      _run(EditorMessages.insertMention(mention, token: _token));

  @override
  Future<EditorDocument> html() {
    if (!_initSent || _stopped) {
      return Future.error(StateError('The editor is not ready'));
    }
    final requestId = ++_lastRequest;
    final answer = Completer<EditorDocument>();
    _pendingHtml[requestId] = answer;
    unawaited(_run(EditorMessages.getHtml(requestId, token: _token)));
    return answer.future.timeout(
      htmlTimeout,
      onTimeout: () {
        _pendingHtml.remove(requestId);
        throw TimeoutException('The editor page did not answer', htmlTimeout);
      },
    );
  }

  @override
  Future<void> setTheme(EditorTheme theme) =>
      _run(EditorMessages.setTheme(theme, token: _token));

  @override
  Future<void> focus() => _run(EditorMessages.focus(token: _token));

  @override
  Future<void> setReadOnly({required bool readOnly}) =>
      _run(EditorMessages.setReadOnly(readOnly: readOnly, token: _token));

  @override
  Widget buildView(BuildContext context) =>
      WebViewWidget(controller: _controller);

  void _failPending(Object error) {
    for (final pending in _pendingHtml.values) {
      pending.completeError(error);
    }
    _pendingHtml.clear();
  }

  @override
  void dispose() {
    _failPending(StateError('The editor closed'));
    unawaited(_events.close());
  }
}

/// What the page needs of the platform's WebView (a controller's
/// `platform`) and nothing more: no file or content access, no location, no
/// gestures that leave the page, and debugging only in debug builds.
@visibleForTesting
Future<void> lockDownWebView(
  Object platform, {
  bool debuggable = kDebugMode,
  Future<void> Function({required bool enabled}) enableAndroidDebugging =
      _enableAndroidDebugging,
}) async {
  switch (platform) {
    case final AndroidWebViewController platform:
      await platform.setAllowFileAccess(false);
      await platform.setAllowContentAccess(false);
      await platform.setGeolocationEnabled(false);
      await platform.setMediaPlaybackRequiresUserGesture(true);
      // The page scales its text by the app's text scale itself; the
      // system font size would apply on top of it.
      await platform.setTextZoom(100);
      await enableAndroidDebugging(enabled: debuggable);
    case final WebKitWebViewController platform:
      await platform.setAllowsBackForwardNavigationGestures(false);
      await platform.setAllowsLinkPreview(false);
      await platform.setInspectable(debuggable);
  }
}

Future<void> _enableAndroidDebugging({required bool enabled}) =>
    AndroidWebViewController.enableDebugging(enabled);
