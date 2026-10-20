import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The JavaScript channel the editor page posts its messages to.
const editorChannelName = 'RuranaEditor';

/// The editor page's commands; [heading], [setLink], [insertTable] and
/// [insertImage] take arguments, see [EditorCommand].
enum EditorCommandName {
  bold,
  italic,
  underline,
  strike,
  code,
  highlight,
  heading,
  bulletList,
  orderedList,
  taskList,
  blockquote,
  codeBlock,
  horizontalRule,
  setLink,
  unsetLink,
  insertTable,
  addRowAfter,
  addColumnAfter,
  deleteRow,
  deleteColumn,
  deleteTable,
  undo,
  redo,
  clearFormatting,
  insertImage,
}

@immutable
final class EditorCommand {
  const new(this.name, [this.args = const {}]);

  /// 0 is a paragraph.
  factory heading(int level) =>
      EditorCommand(EditorCommandName.heading, {'level': level});

  factory setLink(String href) =>
      EditorCommand(EditorCommandName.setLink, {'href': href});

  factory insertTable({required int rows, required int cols}) => EditorCommand(
    EditorCommandName.insertTable,
    {'rows': rows, 'cols': cols},
  );

  /// An attachment of this server by its address, which the page accepts
  /// only with the id the web gives it; [alt] is left out when empty.
  factory insertImage({
    required String src,
    required String id,
    String alt = '',
  }) => EditorCommand(EditorCommandName.insertImage, {
    'src': src,
    'id': id,
    if (alt.isNotEmpty) 'alt': alt,
  });

  final EditorCommandName name;
  final Map<String, Object> args;

  @override
  bool operator ==(Object other) =>
      other is EditorCommand &&
      other.name == name &&
      mapEquals(other.args, args);

  @override
  int get hashCode => Object.hash(name, Object.hashAllUnordered(args.keys));

  @override
  String toString() => 'EditorCommand(${name.name}, $args)';
}

/// CSS colours for the page, from the app's colour scheme, and the text
/// scale it applies to its own font size.
@immutable
final class EditorTheme {
  const new({
    required this.dark,
    required this.colors,
    required this.fontScale,
  });

  final bool dark;

  /// By the names the page knows: text, background, primary, outline,
  /// surface, error, selection, link, codeBackground.
  final Map<String, String> colors;
  final double fontScale;

  Map<String, Object> toJson() => {
    'dark': dark,
    'colors': colors,
    'fontScale': fontScale,
  };

  @override
  bool operator ==(Object other) =>
      other is EditorTheme &&
      other.dark == dark &&
      other.fontScale == fontScale &&
      mapEquals(other.colors, colors);

  @override
  int get hashCode =>
      Object.hash(dark, fontScale, Object.hashAllUnordered(colors.values));
}

/// What the page needs to recognise the server's task links and
/// attachment images as the web does.
@immutable
final class EditorLinks {
  const new({required this.taskLinkBases, required this.apiRoot});

  final List<String> taskLinkBases;
  final String apiRoot;

  Map<String, Object> toJson() => {
    'taskLinkBases': taskLinkBases,
    'apiRoot': apiRoot,
  };
}

/// The page's texts in the app's language: [label] names the editor for
/// screen readers, [imageLabel] marks the images it does not show, and
/// [locale] (a language tag) is the page's language, so that they are read
/// with its voice.
@immutable
final class EditorInit {
  const new({
    required this.html,
    required this.theme,
    required this.placeholder,
    required this.label,
    required this.imageLabel,
    required this.locale,
    required this.links,
  });

  final String html;
  final EditorTheme theme;
  final String placeholder;
  final String label;
  final String imageLabel;
  final String locale;
  final EditorLinks links;
}

/// A person picked from the suggestions; [id] is what the mention stores,
/// the username, as on the web.
@immutable
final class EditorMention {
  const new({required this.username, required this.label});

  final String username;
  final String label;

  String get id => username;

  @override
  bool operator ==(Object other) =>
      other is EditorMention &&
      other.username == username &&
      other.label == label;

  @override
  int get hashCode => Object.hash(username, label);
}

/// The marks and blocks at the cursor.
@immutable
final class EditorActive {
  const new({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.highlight = false,
    this.heading = 0,
    this.bulletList = false,
    this.orderedList = false,
    this.taskList = false,
    this.blockquote = false,
    this.codeBlock = false,
    this.link = false,
    this.linkHref,
    this.table = false,
  });

  factory fromJson(Map<String, Object?> json) {
    bool flag(String key) => json[key] == true;
    final heading = json['heading'];
    return EditorActive(
      bold: flag('bold'),
      italic: flag('italic'),
      underline: flag('underline'),
      strike: flag('strike'),
      code: flag('code'),
      highlight: flag('highlight'),
      heading: heading is num ? heading.toInt().clamp(0, 6) : 0,
      bulletList: flag('bulletList'),
      orderedList: flag('orderedList'),
      taskList: flag('taskList'),
      blockquote: flag('blockquote'),
      codeBlock: flag('codeBlock'),
      link: flag('link'),
      linkHref: switch (json['linkHref']) {
        final String href => href,
        _ => null,
      },
      table: flag('table'),
    );
  }

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;
  final bool highlight;

  /// 0 for a paragraph; the toolbar offers levels 1 to 3, the web's text
  /// may hold up to 6.
  final int heading;
  final bool bulletList;
  final bool orderedList;
  final bool taskList;
  final bool blockquote;
  final bool codeBlock;
  final bool link;

  /// The address of the link at the cursor.
  final String? linkHref;
  final bool table;
}

@immutable
final class EditorState {
  const new({
    this.dirty = false,
    this.canUndo = false,
    this.canRedo = false,
    this.active = const EditorActive(),
  });

  /// The document differs from the one the page was given.
  final bool dirty;
  final bool canUndo;
  final bool canRedo;
  final EditorActive active;
}

/// What the page reports, once its token checked out.
@immutable
sealed class EditorEvent {
  const new();
}

/// The page has loaded its document and takes commands.
final class EditorReady extends EditorEvent {
  const new();
}

final class EditorStateChanged extends EditorEvent {
  const new(this.state);

  final EditorState state;
}

/// The user typed `@` and [query] after it.
final class MentionQuery extends EditorEvent {
  const new(this.query);

  final String query;
}

final class MentionEnd extends EditorEvent {
  const new();
}

final class EditorHtml extends EditorEvent {
  const new(this.requestId, this.document);

  final int requestId;
  final EditorDocument document;
}

/// The page failed; [message] carries no content of the document.
final class EditorFailed extends EditorEvent {
  const new(this.message);

  final String message;
}

/// The WebView's process ended after the page was ready (iOS ends it under
/// memory pressure): the page is blank and what it held is gone.
final class EditorStopped extends EditorEvent {
  const new();
}

/// The page's document as it serialises it, and whether that differs from
/// the one it was given, decided when it answered.
@immutable
final class EditorDocument {
  const new(this.html, {required this.dirty});

  final String html;
  final bool dirty;
}

/// Messages to the page, as the script that delivers them.
abstract final class EditorMessages {
  static String init(EditorInit init, {required String token}) => _script({
    'type': 'init',
    'token': token,
    'html': init.html,
    'readOnly': false,
    'theme': init.theme.toJson(),
    'l10n': {
      'placeholder': init.placeholder,
      'label': init.label,
      'image': init.imageLabel,
      'locale': init.locale,
    },
    'links': init.links.toJson(),
  });

  static String command(EditorCommand command, {required String token}) =>
      _script({
        'type': 'command',
        'token': token,
        'name': command.name.name,
        'args': command.args,
      });

  static String insertMention(EditorMention mention, {required String token}) =>
      _script({
        'type': 'insertMention',
        'token': token,
        'id': mention.id,
        'username': mention.username,
        'label': mention.label,
      });

  static String getHtml(int requestId, {required String token}) =>
      _script({'type': 'getHtml', 'token': token, 'requestId': requestId});

  static String setTheme(EditorTheme theme, {required String token}) =>
      _script({'type': 'setTheme', 'token': token, 'theme': theme.toJson()});

  static String focus({required String token}) =>
      _script({'type': 'focus', 'token': token});

  static String setReadOnly({required bool readOnly, required String token}) =>
      _script({'type': 'setReadOnly', 'token': token, 'readOnly': readOnly});

  // JSON is a valid JavaScript literal, U+2028 and U+2029 included since
  // ES2019, so the payload needs no further escaping.
  static String _script(Map<String, Object?> message) =>
      'window.rurana.receive(${jsonEncode(message)})';
}

/// [message] from the page as an event, or null when it is not one: not
/// JSON, an unknown type, or without [token]. Before the page has a token
/// ([token] null) only its `ready` counts, which carries none.
EditorEvent? decodeEditorMessage(String message, {required String? token}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(message);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  final type = decoded['type'];
  if (token == null) return type == 'ready' ? const EditorReady() : null;
  if (decoded['token'] != token) return null;
  return switch (type) {
    'state' => EditorStateChanged(
      EditorState(
        dirty: decoded['dirty'] == true,
        canUndo: decoded['canUndo'] == true,
        canRedo: decoded['canRedo'] == true,
        active: switch (decoded['active']) {
          final Map<String, Object?> active => EditorActive.fromJson(active),
          _ => const EditorActive(),
        },
      ),
    ),
    'mentionQuery' => MentionQuery(switch (decoded['query']) {
      final String query => query,
      _ => '',
    }),
    'mentionEnd' => const MentionEnd(),
    'html' => switch ((decoded['requestId'], decoded['html'])) {
      (final int requestId, final String html) => EditorHtml(
        requestId,
        EditorDocument(html, dirty: decoded['dirty'] == true),
      ),
      _ => null,
    },
    'error' => EditorFailed(switch (decoded['message']) {
      final String text => text,
      _ => '',
    }),
    _ => null,
  };
}
