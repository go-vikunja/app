import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/text/task_title_limit.dart';

/// A new task's title and the rest of what another app shared, as text.
@immutable
final class SharedTaskText {
  const new({required this.title, required this.notes});

  final String title;
  final String notes;

  /// [notes] as the description's HTML, empty when there are none.
  String get description => sharedTextHtml(notes);
}

/// The title is the [subject], else the first line of [text], else the
/// name of the one shared file; the rest of [text] is the notes. What a
/// title has beyond the server's limit starts the notes.
SharedTaskText sharedTaskText({
  String? subject,
  String? text,
  String? singleFileName,
}) {
  final body = _normaliseNewlines(text ?? '').trim();
  final cleanSubject = subject?.trim() ?? '';
  if (cleanSubject.isNotEmpty) {
    return _withTitle(_oneLine(cleanSubject), body, between: '\n\n');
  }
  if (body.isNotEmpty) {
    final newline = body.indexOf('\n');
    final first = newline < 0 ? body : body.substring(0, newline);
    final rest = newline < 0 ? '' : body.substring(newline + 1);
    return _withTitle(first.trim(), rest.trim());
  }
  return _withTitle(singleFileName?.trim() ?? '', '');
}

SharedTaskText _withTitle(String title, String notes, {String between = '\n'}) {
  final cut = cutTaskTitle(title);
  return SharedTaskText(
    title: cut.title,
    notes: [cut.rest, notes].where((part) => part.isNotEmpty).join(between),
  );
}

/// What goes into an existing task: the [subject] (a page title) and the
/// [text], unless the text already starts with the subject.
String sharedTextToAppend({String? subject, String? text}) {
  final body = _normaliseNewlines(text ?? '').trim();
  final cleanSubject = _oneLine(subject?.trim() ?? '');
  if (cleanSubject.isEmpty || body.startsWith(cleanSubject)) return body;
  return body.isEmpty ? cleanSubject : '$cleanSubject\n$body';
}

/// [text] as the editor would store it: blocks between blank lines as
/// paragraphs, single line breaks kept, everything escaped, and http(s)
/// addresses as links with the web's attributes.
String sharedTextHtml(String text) {
  final blocks = _normaliseNewlines(text)
      .split(RegExp(r'\n[ \t]*\n'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty);
  return [
    for (final block in blocks)
      '<p>${block.split('\n').map((line) => _linked(line.trim())).join('<br>')}</p>',
  ].join();
}

/// [description] with [addition] after it; an empty description, or the
/// editor's empty `<p></p>`, is replaced.
String appendToDescription(String description, String addition) {
  final trimmed = description.trim();
  if (trimmed.isEmpty || trimmed == '<p></p>') return addition;
  return '$description$addition';
}

final _webAddress = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
final _trailingPunctuation = RegExp(r'''[.,;:!?'"]+$''');
const _elementText = HtmlEscape(HtmlEscapeMode.element);
const _attributeText = HtmlEscape(HtmlEscapeMode.attribute);

String _linked(String line) {
  final out = StringBuffer();
  var start = 0;
  for (final match in _webAddress.allMatches(line)) {
    var address = match[0]!.replaceFirst(_trailingPunctuation, '');
    // A closing bracket after an address belongs to the sentence unless
    // the address opened one.
    while (address.endsWith(')') &&
        ')'.allMatches(address).length > '('.allMatches(address).length) {
      address = address
          .substring(0, address.length - 1)
          .replaceFirst(_trailingPunctuation, '');
    }
    if (Uri.tryParse(address)?.host.isEmpty ?? true) continue;
    out
      ..write(_elementText.convert(line.substring(start, match.start)))
      ..write(
        '<a target="_blank" rel="noopener noreferrer nofollow" '
        'href="${_attributeText.convert(address)}">'
        '${_elementText.convert(address)}</a>',
      );
    start = match.start + address.length;
  }
  out.write(_elementText.convert(line.substring(start)));
  return out.toString();
}

String _normaliseNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _oneLine(String text) =>
    _normaliseNewlines(text).split('\n').map((line) => line.trim()).join(' ');
