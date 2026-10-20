import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_bridge.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/webview_editor_bridge.dart';

/// The editor page without a WebView: it records what the app sends, and a
/// test plays the page with [emit]. Ready right after [start] unless
/// [readyOnStart] is false.
final class FakeEditorBridge implements EditorBridge {
  new({this.readyOnStart = true});

  static const viewKey = Key('fake-editor-view');

  final bool readyOnStart;
  // Synchronous, so that the page has the event before the test pumps the
  // frame that shows it.
  final _events = StreamController<EditorEvent>.broadcast(sync: true);
  EditorInit? init;
  Color? background;
  final List<EditorCommand> commands = [];
  final List<EditorMention> mentions = [];
  final List<EditorTheme> themes = [];

  /// Every `setReadOnly`, in order.
  final List<bool> readOnly = [];
  int focusCalls = 0;
  int htmlCalls = 0;
  bool disposed = false;

  /// What [html] answers, the document of [start] until an [edit], dirty
  /// as the last state said; it throws [htmlFailure] instead when that is
  /// set.
  String document = '';
  bool dirty = false;
  Exception? htmlFailure;

  void emit(EditorEvent event) {
    if (event case EditorStateChanged(:final state)) dirty = state.dirty;
    if (!_events.isClosed) _events.add(event);
  }

  /// The user changed the document to [html].
  void edit(String html, {EditorActive active = const EditorActive()}) {
    document = html;
    emit(
      EditorStateChanged(
        EditorState(dirty: true, canUndo: true, active: active),
      ),
    );
  }

  @override
  Stream<EditorEvent> get events => _events.stream;

  @override
  Future<void> start(EditorInit init, {required Color background}) async {
    this.init = init;
    this.background = background;
    document = init.html;
    if (readyOnStart) scheduleMicrotask(() => emit(const EditorReady()));
  }

  @override
  Future<void> command(EditorCommand command) async => commands.add(command);

  @override
  Future<void> insertMention(EditorMention mention) async =>
      mentions.add(mention);

  @override
  Future<EditorDocument> html() async {
    htmlCalls++;
    if (htmlFailure case final failure?) throw failure;
    return EditorDocument(document, dirty: dirty);
  }

  @override
  Future<void> setReadOnly({required bool readOnly}) async =>
      this.readOnly.add(readOnly);

  @override
  Future<void> setTheme(EditorTheme theme) async => themes.add(theme);

  @override
  Future<void> focus() async => focusCalls++;

  @override
  Widget buildView(BuildContext context) =>
      const ColoredBox(key: viewKey, color: Color(0x00000000));

  @override
  void dispose() {
    disposed = true;
    unawaited(_events.close());
  }
}

/// A new [FakeEditorBridge] for every page load, kept in [created].
final class FakeEditorBridges {
  bool readyOnStart = true;
  final List<FakeEditorBridge> created = [];

  FakeEditorBridge get last => created.last;

  Override get override => editorBridgeFactoryProvider.overrideWithValue(() {
    final bridge = FakeEditorBridge(readyOnStart: readyOnStart);
    created.add(bridge);
    return bridge;
  });
}
