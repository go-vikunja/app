import 'package:flutter/widgets.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';

/// The editor page as the app sees it: commands out, events in, and the
/// view that shows it. One bridge serves one page load.
abstract interface class EditorBridge {
  /// The page's events whose token checked out; [EditorReady] once it holds
  /// the document of [start], [EditorStopped] when it died after that.
  Stream<EditorEvent> get events;

  /// Loads the page, which gets [init] once it is ready. [background] shows
  /// until then.
  Future<void> start(EditorInit init, {required Color background});

  Future<void> command(EditorCommand command);

  Future<void> insertMention(EditorMention mention);

  /// The document as the page serialises it; throws when the page does not
  /// answer.
  Future<EditorDocument> html();

  Future<void> setTheme(EditorTheme theme);

  Future<void> focus();

  /// While [readOnly], neither typing nor commands change the document.
  Future<void> setReadOnly({required bool readOnly});

  Widget buildView(BuildContext context);

  void dispose();
}

typedef EditorBridgeFactory = EditorBridge Function();
