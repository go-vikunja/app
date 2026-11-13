import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/webview_editor_bridge.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../helpers/fake_webview_platform.dart';

void main() {
  const token = 'load-token';
  const androidAsset =
      'file:///android_asset/flutter_assets/assets/editor/editor.html';
  const iosAsset =
      'file:///private/var/containers/Bundle/Application/X/Runner.app/'
      'Frameworks/App.framework/flutter_assets/assets/editor/editor.html';
  const init = EditorInit(
    html: '<p>Hello</p>',
    theme: EditorTheme(
      dark: false,
      colors: {'text': '#000000'},
      fontScale: 1.5,
    ),
    placeholder: 'Write a description…',
    label: 'Description',
    imageLabel: 'Image (not shown while editing)',
    locale: 'en',
    links: EditorLinks(
      taskLinkBases: ['https://tasks.example.org/'],
      apiRoot: 'https://tasks.example.org',
    ),
  );

  late FakeWebViewPlatform platform;
  late WebViewEditorBridge bridge;
  late List<EditorEvent> events;
  late StreamSubscription<EditorEvent> subscription;

  FakeWebViewController controller() => platform.controllers.single;

  const prefix = 'window.vikunja.receive(';

  Map<String, Object?> lastPayload() {
    final script = controller().scripts.last;
    return jsonDecode(script.substring(prefix.length, script.length - 1))
        as Map<String, Object?>;
  }

  void post(Map<String, Object?> message) =>
      controller().post(jsonEncode(message));

  setUp(() async {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    bridge = WebViewEditorBridge(token: token);
    events = [];
    subscription = bridge.events.listen(events.add);
    await bridge.start(init, background: const Color(0xff101010));
  });

  tearDown(() async {
    await subscription.cancel();
    bridge.dispose();
  });

  test('loads the bundled page with JavaScript, without zoom, on the '
      "theme's background, with the channel and the navigation lock", () {
    final view = controller();
    expect(view.loadedAsset, 'assets/editor/editor.html');
    expect(view.javaScriptMode, JavaScriptMode.unrestricted);
    expect(view.zoomEnabled, isFalse);
    expect(view.backgroundColor, const Color(0xff101010));
    expect(view.channels.keys, ['VikunjaEditor']);
    expect(view.navigationDelegate, isNotNull);
    expect(view.consoleHandled, isTrue);
    expect(view.scripts, isEmpty);
  });

  test(
    'only the editor page itself loads, and only until it is ready',
    () async {
      final navigation = controller().navigationDelegate!;
      expect(
        await navigation.request(androidAsset),
        NavigationDecision.navigate,
      );
      expect(await navigation.request(iosAsset), NavigationDecision.navigate);
      expect(
        await navigation.request(androidAsset, isMainFrame: false),
        NavigationDecision.prevent,
      );
      expect(
        await navigation.request('https://evil.example.org/'),
        NavigationDecision.prevent,
      );
      expect(
        await navigation.request('file:///etc/assets/editor/editor.html'),
        NavigationDecision.prevent,
      );
      expect(
        await navigation.request('$androidAsset?next=https://evil.example.org'),
        NavigationDecision.prevent,
      );

      controller().post('{"type":"ready"}');
      await pumpEventQueue();

      expect(
        await navigation.request(androidAsset),
        NavigationDecision.prevent,
      );
      expect(
        await navigation.request('https://tasks.example.org/tasks/1'),
        NavigationDecision.prevent,
      );
      expect(
        await navigation.request('mailto:someone@example.org'),
        NavigationDecision.prevent,
      );
    },
  );

  // The Android plugin turns on JavaScript windows (window.open), whose
  // loads reach this same delegate as main-frame navigations.
  test(
    'a window.open main-frame navigation after ready is prevented',
    () async {
      final navigation = controller().navigationDelegate!;
      controller().post('{"type":"ready"}');
      await pumpEventQueue();

      for (final url in [
        'about:blank',
        'data:text/html,<p>x</p>',
        'https://evil.example.org/',
        'intent://scan/#Intent;scheme=zxing;end',
      ]) {
        expect(
          await navigation.request(url),
          NavigationDecision.prevent,
          reason: url,
        );
      }
    },
  );

  test('a page that fails to load is reported, a failed subresource '
      'not', () async {
    controller().navigationDelegate!
      ..fail(const WebResourceError(errorCode: -1, description: 'image'))
      ..fail(
        const WebResourceError(
          errorCode: -6,
          description: 'missing',
          isForMainFrame: true,
        ),
      );
    await pumpEventQueue();

    expect(events, [isA<EditorFailed>()]);
  });

  test('ready hands the page its document with the token, once', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();

    expect(controller().scripts, hasLength(1));
    expect(lastPayload(), {
      'type': 'init',
      'token': token,
      'html': '<p>Hello</p>',
      'readOnly': false,
      'theme': {
        'dark': false,
        'colors': {'text': '#000000'},
        'fontScale': 1.5,
      },
      'l10n': {
        'placeholder': 'Write a description…',
        'label': 'Description',
        'image': 'Image (not shown while editing)',
        'locale': 'en',
      },
      'links': {
        'taskLinkBases': ['https://tasks.example.org/'],
        'apiRoot': 'https://tasks.example.org',
      },
    });
    expect(events, isEmpty);

    controller().post('{"type":"ready"}');
    await pumpEventQueue();
    expect(controller().scripts, hasLength(1));
    expect(events, isEmpty);
  });

  test('the page is ready once its first state says it loaded the '
      'document', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();
    post({'type': 'state', 'dirty': false, 'token': token});
    post({'type': 'state', 'dirty': true, 'token': token});
    await pumpEventQueue();

    expect(events, [
      isA<EditorReady>(),
      isA<EditorStateChanged>().having((e) => e.state.dirty, 'dirty', isFalse),
      isA<EditorStateChanged>().having((e) => e.state.dirty, 'dirty', isTrue),
    ]);
  });

  test('a page that cannot load the document fails instead of getting '
      'ready', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();
    post({'type': 'error', 'message': 'init failed', 'token': token});
    await pumpEventQueue();

    expect(events, [isA<EditorFailed>()]);
  });

  test('a fresh bridge picks its own random token', () async {
    final other = WebViewEditorBridge();
    await other.start(init, background: const Color(0xff000000));
    platform.controllers.last.post('{"type":"ready"}');
    await pumpEventQueue();

    final script = platform.controllers.last.scripts.single;
    final payload = jsonDecode(
      script.substring(prefix.length, script.length - 1),
    ) as Map<String, Object?>;
    expect(payload['token'], isA<String>());
    expect((payload['token']! as String).length, greaterThanOrEqualTo(32));
    expect(payload['token'], isNot(token));
    other.dispose();
  });

  test('messages count only with the token', () async {
    post({'type': 'state', 'dirty': true, 'token': token});
    controller().post('{"type":"ready"}');
    await pumpEventQueue();
    expect(events, isEmpty);
    post({'type': 'state', 'dirty': false, 'token': token});
    await pumpEventQueue();
    events.clear();

    post({'type': 'state', 'dirty': true});
    post({'type': 'state', 'dirty': true, 'token': 'guessed'});
    post({'type': 'mentionQuery', 'query': 'a'});
    await pumpEventQueue();
    expect(events, isEmpty);

    post({'type': 'state', 'dirty': true, 'token': token});
    post({'type': 'mentionQuery', 'query': 'ja', 'token': token});
    post({'type': 'mentionEnd', 'token': token});
    await pumpEventQueue();
    expect(events, [
      isA<EditorStateChanged>().having((e) => e.state.dirty, 'dirty', isTrue),
      isA<MentionQuery>().having((e) => e.query, 'query', 'ja'),
      isA<MentionEnd>(),
    ]);
  });

  test('nothing goes to the page before it holds the document', () async {
    await bridge.command(const EditorCommand(EditorCommandName.bold));
    await bridge.focus();
    expect(controller().scripts, isEmpty);
    await expectLater(bridge.html(), throwsStateError);
  });

  test('commands, mentions, theme, focus and read-only carry the '
      'token', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();

    await bridge.command(EditorCommand.heading(2));
    expect(lastPayload(), {
      'type': 'command',
      'token': token,
      'name': 'heading',
      'args': {'level': 2},
    });
    await bridge.insertMention(
      const EditorMention(username: 'jdoe', label: 'Jane Doe'),
    );
    expect(lastPayload()['type'], 'insertMention');
    expect(lastPayload()['token'], token);
    await bridge.setTheme(init.theme);
    expect(lastPayload()['type'], 'setTheme');
    await bridge.focus();
    expect(lastPayload(), {'type': 'focus', 'token': token});
    await bridge.setReadOnly(readOnly: true);
    expect(lastPayload(), {
      'type': 'setReadOnly',
      'token': token,
      'readOnly': true,
    });
  });

  test('html asks by request id and takes only its own answer', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();

    final answer = bridge.html();
    await pumpEventQueue();
    final request = lastPayload();
    expect(request['type'], 'getHtml');
    final requestId = request['requestId']! as int;

    post({
      'type': 'html',
      'requestId': requestId + 1,
      'html': '<p>other</p>',
      'token': token,
    });
    post({'type': 'html', 'requestId': requestId, 'html': '<p>forged</p>'});
    post({
      'type': 'html',
      'requestId': requestId,
      'html': '<p>Edited</p>',
      'dirty': true,
      'token': token,
    });

    final document = await answer;
    expect((document.html, document.dirty), ('<p>Edited</p>', true));
    expect(events.whereType<EditorHtml>(), isEmpty);
  });

  test('closing fails a pending html request', () async {
    controller().post('{"type":"ready"}');
    await pumpEventQueue();

    final answer = bridge.html();
    bridge.dispose();

    await expectLater(answer, throwsStateError);
  });

  group('a WebView process that ends', () {
    const ended = WebResourceError(
      errorCode: 1,
      description: 'terminated',
      errorType: WebResourceErrorType.webContentProcessTerminated,
      isForMainFrame: true,
    );

    Future<void> load() async {
      controller().post('{"type":"ready"}');
      await pumpEventQueue();
      post({'type': 'state', 'dirty': true, 'token': token});
      await pumpEventQueue();
      events.clear();
    }

    test('after the page was ready stops the editor: pending and later '
        'requests fail at once, nothing more is sent', () async {
      await load();
      final pending = expectLater(bridge.html(), throwsStateError);
      final sent = controller().scripts.length;

      controller().navigationDelegate!.fail(ended);
      await pumpEventQueue();

      expect(events, [isA<EditorStopped>()]);
      await pending;
      await expectLater(bridge.html(), throwsStateError);
      await bridge.command(const EditorCommand(EditorCommandName.bold));
      expect(controller().scripts, hasLength(sent));

      controller().navigationDelegate!.fail(ended);
      await pumpEventQueue();
      expect(events, hasLength(1));
    });

    test('while loading is a failed load', () async {
      controller().navigationDelegate!.fail(ended);
      await pumpEventQueue();

      expect(events, [isA<EditorFailed>()]);
    });

    test('another main-frame error after the page was ready, such as a '
        'prevented navigation, changes nothing', () async {
      await load();

      controller().navigationDelegate!.fail(
        const WebResourceError(
          errorCode: 102,
          description: 'Frame load interrupted',
          isForMainFrame: true,
        ),
      );
      await pumpEventQueue();

      expect(events, isEmpty);
    });
  });

  group('lockdown', () {
    test('Android: no file or content access, no location, media only on a '
        'gesture, text zoom pinned at 100, debugging only when '
        'debuggable', () async {
      final android = _RecordingAndroidController();
      final debugging = <bool>[];

      await lockDownWebView(
        android,
        debuggable: false,
        enableAndroidDebugging: ({required enabled}) async =>
            debugging.add(enabled),
      );

      expect(android.calls, [
        'setAllowFileAccess false',
        'setAllowContentAccess false',
        'setGeolocationEnabled false',
        'setMediaPlaybackRequiresUserGesture true',
        'setTextZoom 100',
      ]);
      expect(debugging, [false]);
    });

    test('iOS: no back and forward gestures, no link previews, inspectable '
        'only when debuggable', () async {
      final webKit = _RecordingWebKitController();

      await lockDownWebView(webKit, debuggable: false);

      expect(webKit.calls, [
        'setAllowsBackForwardNavigationGestures false',
        'setAllowsLinkPreview false',
        'setInspectable false',
      ]);
    });

    test('debugging follows the build mode by default', () async {
      final debugging = <bool>[];
      final webKit = _RecordingWebKitController();

      await lockDownWebView(
        _RecordingAndroidController(),
        enableAndroidDebugging: ({required enabled}) async =>
            debugging.add(enabled),
      );
      await lockDownWebView(webKit);

      expect(debugging, [kDebugMode]);
      expect(webKit.calls.last, 'setInspectable $kDebugMode');
    });
  });

  test('the asset path is recognised on both platforms', () {
    expect(WebViewEditorBridge.isEditorPage(androidAsset), isTrue);
    expect(WebViewEditorBridge.isEditorPage(iosAsset), isTrue);
    expect(
      WebViewEditorBridge.isEditorPage(
        'https://x/flutter_assets/assets/'
        'editor/editor.html',
      ),
      isFalse,
    );
    expect(WebViewEditorBridge.isEditorPage('about:blank'), isFalse);
  });
}

// Only what the lockdown calls; anything else would throw.
final class _RecordingAndroidController implements AndroidWebViewController {
  final List<String> calls = [];

  @override
  Future<void> setAllowFileAccess(bool allow) async =>
      calls.add('setAllowFileAccess $allow');

  @override
  Future<void> setAllowContentAccess(bool enabled) async =>
      calls.add('setAllowContentAccess $enabled');

  @override
  Future<void> setGeolocationEnabled(bool enabled) async =>
      calls.add('setGeolocationEnabled $enabled');

  @override
  Future<void> setMediaPlaybackRequiresUserGesture(bool require) async =>
      calls.add('setMediaPlaybackRequiresUserGesture $require');

  @override
  Future<void> setTextZoom(int textZoom) async =>
      calls.add('setTextZoom $textZoom');

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _RecordingWebKitController implements WebKitWebViewController {
  final List<String> calls = [];

  @override
  Future<void> setAllowsBackForwardNavigationGestures(bool enabled) async =>
      calls.add('setAllowsBackForwardNavigationGestures $enabled');

  @override
  Future<void> setAllowsLinkPreview(bool allow) async =>
      calls.add('setAllowsLinkPreview $allow');

  @override
  Future<void> setInspectable(bool inspectable) async =>
      calls.add('setInspectable $inspectable');

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
