import 'package:html/dom.dart' as dom;
import 'package:html/html_escape.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/text/rich_text.dart';
import 'package:vikunja_logic/src/text/rich_text_parser.dart';

/// A mention typed into a comment: the text from [start] to [end] (UTF-16
/// offsets, [end] exclusive), usually `@` and the label, stands for the
/// user [username], shown as [label].
@immutable
final class MentionSpan {
  const new({
    required this.start,
    required this.end,
    required this.username,
    required this.label,
  });

  final int start;
  final int end;
  final String username;

  /// The display name the web writes (`name`, else `username`).
  final String label;

  @override
  bool operator ==(Object other) =>
      other is MentionSpan &&
      other.start == start &&
      other.end == end &&
      other.username == username &&
      other.label == label;

  @override
  int get hashCode => Object.hash(start, end, username, label);

  @override
  String toString() => 'MentionSpan($start, $end)';
}

/// The comment a reply quotes, with its HTML as the server sent it.
@immutable
final class QuotedComment {
  const new({required this.id, required this.html});

  final int id;
  final String html;
}

/// [text] as the web's comment editor stores it once typed: every line a
/// paragraph (an empty line an empty one), blank lines at the start and the
/// end left out, the characters HTML gives a meaning escaped, http(s)
/// addresses linked with the web's attributes and every span of [mentions]
/// the web's mention node. A span that overlaps an earlier one, leaves the
/// text, crosses a line break or names no user stays plain text.
///
/// With [reply] the web's quote comes first: the quoted comment's HTML, as
/// far as the web's editor keeps it, in a `blockquote` carrying its id, its
/// mentions turned into `@label` text so that quoting notifies nobody again
/// (the server notifies the quoted author instead); plain text in it
/// becomes a paragraph. Without text the reply ends in an empty paragraph,
/// as the web's does.
///
/// Empty text without a reply is the editor's empty `<p></p>`.
String commentHtmlFromText(
  String text, {
  List<MentionSpan> mentions = const [],
  QuotedComment? reply,
}) {
  final out = StringBuffer();
  if (reply != null) {
    out
      ..write('<blockquote data-comment-id="${reply.id}">')
      ..write(_quoteBody(reply.html))
      ..write('</blockquote>');
  }
  final lines = _lines(text, _validSpans(text, mentions));
  if (lines.isEmpty) {
    out.write('<p></p>');
  } else {
    for (final line in lines) {
      out.write('<p>');
      _writeLine(out, text, line);
      out.write('</p>');
    }
  }
  return out.toString();
}

/// The text of a comment for the preview of a reply to it: mentions as
/// `@label`, task links as their address, images left out, its own reply
/// quotes left out unless it holds nothing else, all on one line.
String quotedTextOf(String html) {
  final document = parseRichText(html, apiRoot: Uri(), taskLinkBases: const []);
  final own = _blockText(document.blocks, skipReplies: true);
  final text = own.trim().isEmpty
      ? _blockText(document.blocks, skipReplies: false)
      : own;
  return text.replaceAll(_whitespaceRun, ' ').trim();
}

final _whitespaceRun = RegExp(r'\s+');

typedef _Line = ({int start, int end, List<MentionSpan> mentions});

List<MentionSpan> _validSpans(String text, List<MentionSpan> mentions) {
  final sorted = [...mentions]
    ..sort((a, b) => a.start != b.start ? a.start - b.start : a.end - b.end);
  final valid = <MentionSpan>[];
  var previousEnd = 0;
  for (final span in sorted) {
    if (span.start < previousEnd ||
        span.end <= span.start ||
        span.end > text.length ||
        span.username.isEmpty ||
        _lineBreak.hasMatch(text.substring(span.start, span.end))) {
      continue;
    }
    valid.add(span);
    previousEnd = span.end;
  }
  return valid;
}

final _lineBreak = RegExp('[\r\n]');

List<_Line> _lines(String text, List<MentionSpan> spans) {
  final lines = <_Line>[];
  var start = 0;
  var spanIndex = 0;
  void addLine(int end) {
    final inLine = <MentionSpan>[];
    while (spanIndex < spans.length && spans[spanIndex].end <= end) {
      inLine.add(spans[spanIndex++]);
    }
    lines.add((start: start, end: end, mentions: inLine));
  }

  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit != _cr && unit != _lf) continue;
    addLine(i);
    if (unit == _cr && i + 1 < text.length && text.codeUnitAt(i + 1) == _lf) {
      i++;
    }
    start = i + 1;
  }
  addLine(text.length);

  bool blank(_Line line) =>
      line.mentions.isEmpty &&
      text.substring(line.start, line.end).trim().isEmpty;
  var first = 0;
  var last = lines.length;
  while (first < last && blank(lines[first])) {
    first++;
  }
  while (last > first && blank(lines[last - 1])) {
    last--;
  }
  return lines.sublist(first, last);
}

const _cr = 0x0D;
const _lf = 0x0A;

void _writeLine(StringBuffer out, String text, _Line line) {
  var position = line.start;
  for (final span in line.mentions) {
    _writeLinked(out, text.substring(position, span.start));
    out
      ..write('<mention-user data-id="')
      ..write(_attribute(span.username))
      ..write('"');
    if (span.label.isNotEmpty) {
      out
        ..write(' data-label="')
        ..write(_attribute(span.label))
        ..write('"');
    }
    out.write(' data-mention-suggestion-char="@"></mention-user>');
    position = span.end;
  }
  _writeLinked(out, text.substring(position, line.end));
}

// Only addresses with a scheme: the web's autolink also takes bare domains
// by their top-level domain, which this does not try to match.
final _webAddress = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
final _trailingPunctuation = RegExp(r'''[.,;:!?'"]+$''');

void _writeLinked(StringBuffer out, String text) {
  var start = 0;
  for (final match in _webAddress.allMatches(text)) {
    var address = match[0]!.replaceFirst(_trailingPunctuation, '');
    // A closing bracket after an address belongs to the sentence unless the
    // address opened one.
    while (address.endsWith(')') &&
        ')'.allMatches(address).length > '('.allMatches(address).length) {
      address = address
          .substring(0, address.length - 1)
          .replaceFirst(_trailingPunctuation, '');
    }
    if (Uri.tryParse(address)?.host.isEmpty ?? true) continue;
    out
      ..write(_text(text.substring(start, match.start)))
      ..write('<a target="_blank" rel="noopener noreferrer nofollow" href="')
      ..write(_attribute(address))
      ..write('">')
      ..write(_text(address))
      ..write('</a>');
    start = match.start + address.length;
  }
  out.write(_text(text.substring(start)));
}

String _text(String text) => htmlSerializeEscape(text);

String _attribute(String value) =>
    htmlSerializeEscape(value, attributeMode: true);

// The web's stripMentionsForQuote: the comment parsed inside a `div`, each
// mention replaced by `@` and its label (else its text) without leading
// `@`s, or by nothing without either, and the `div`'s inner HTML. A comment
// that opens with a frameset takes the body's place there, which leaves
// nothing to quote. The web's editor then saves only what its schema
// knows, so only that is copied.
String _quoteBody(String html) {
  final source = html_parser
      .parse('<div>$html</div>')
      .body
      ?.children
      .firstOrNull;
  final wrapper = dom.Element.tag('div');
  if (source != null) _copySchemaMarkup(source, wrapper);
  if (!wrapper.nodes.every(_isInline)) return wrapper.innerHtml;
  // Plain text, as other clients write it: the editor puts it into a
  // paragraph and turns its line breaks into hard breaks.
  final paragraph = StringBuffer('<p>');
  for (final node in wrapper.nodes) {
    paragraph.write(
      node is dom.Text
          ? _text(node.data).replaceAll(_anyLineBreak, '<br>')
          : (node as dom.Element).outerHtml,
    );
  }
  return (paragraph..write('</p>')).toString();
}

final _anyLineBreak = RegExp('\r\n?|\n');

final _leadingAts = RegExp('^@+');

// The children of [from] into [into]: the schema's elements with the
// attributes it reads (a link without an allowed address as its text, an
// image without one left out), other blocks as bare `div`s, other inline
// elements as their content, mentions as text, and nothing of what runs,
// embeds or asks for input. Without recursion: a hostile comment may nest
// elements thousands deep.
void _copySchemaMarkup(dom.Element from, dom.Element into) {
  final pending = [(from.nodes.iterator, into)];
  while (pending.isNotEmpty) {
    final (children, target) = pending.last;
    if (!children.moveNext()) {
      pending.removeLast();
      continue;
    }
    final node = children.current;
    if (node is dom.Text) {
      target.append(dom.Text(node.data));
      continue;
    }
    if (node is! dom.Element) continue;
    final name = node.localName ?? '';
    if (name == 'mention-user') {
      final label = (node.attributes['data-label'] ?? node.text)
          .trim()
          .replaceFirst(_leadingAts, '');
      if (label.isNotEmpty) target.append(dom.Text('@$label'));
      continue;
    }
    final into = switch (_quotedAttributes[name]) {
      final allowed? => switch (_copyOf(node, allowed)) {
        final link when name == 'a' && !link.attributes.containsKey('href') =>
          target,
        final copy
            when (name == 'img' && !copy.attributes.containsKey('src')) ||
                (name == 'input' && !copy.attributes.containsKey('type')) =>
          null,
        final copy => copy,
      },
      null when droppedTags.contains(name) => null,
      null when blockTags.contains(name) => dom.Element.tag('div'),
      null => target,
    };
    if (into == null) continue;
    if (into != target) target.append(into);
    pending.add((node.nodes.iterator, into));
  }
}

dom.Element _copyOf(
  dom.Element element,
  Map<String, bool Function(String value)> allowed,
) {
  final copy = dom.Element.tag(element.localName);
  for (final MapEntry(:key, :value) in element.attributes.entries) {
    if (key is String && (allowed[key]?.call(value) ?? false)) {
      copy.attributes[key] = value;
    }
  }
  return copy;
}

bool _anyValue(String _) => true;

bool _allowedAddress(String value) => allowedLinkHref(value) != null;

final _positiveId = RegExp(r'^[1-9]\d{0,15}$');
final _listStart = RegExp(r'^-?\d{1,9}$');
final _listType = RegExp(r'^[aAiI1]$');
final _taskItemId = RegExp(r'^[\w-]{1,64}$');
final _codeLanguage = RegExp(r'^language-\S+$');
final _imageId = RegExp(r'^tiptap-image-\d+-\d+$');
final _cellSpan = RegExp(r'^\d{1,5}$');
final _columnWidths = RegExp(r'^\d{1,5}(,\d{1,5})*$');
final _hexColor = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

const _noAttributes = <String, bool Function(String)>{};

// The editor schema's elements and the attributes its parse rules read
// (style left out: the editor rebuilds what it needs from the rest).
final Map<String, Map<String, bool Function(String value)>> _quotedAttributes =
    {
      for (final tag in const [
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'pre',
        'hr',
        'br',
        'strong',
        'b',
        'em',
        'i',
        's',
        'del',
        'strike',
        'u',
        'sub',
        'sup',
        'table',
        'colgroup',
        'col',
        'thead',
        'tbody',
        'tfoot',
        'tr',
        'div',
        'span',
        'label',
      ])
        tag: _noAttributes,
      'blockquote': {'data-comment-id': _positiveId.hasMatch},
      'ul': {'data-type': (value) => value == 'taskList'},
      'ol': {'start': _listStart.hasMatch, 'type': _listType.hasMatch},
      'li': {
        'data-checked': (value) => const {'true', 'false', ''}.contains(value),
        'data-task-id': _taskItemId.hasMatch,
        'data-type': (value) => value == 'taskItem',
      },
      'input': {
        'type': (value) => value.toLowerCase() == 'checkbox',
        'checked': _anyValue,
      },
      'code': {'class': _codeLanguage.hasMatch},
      'a': {
        'target': _anyValue,
        'rel': _anyValue,
        'href': _allowedAddress,
        'title': _anyValue,
      },
      'img': {
        'data-src': _allowedAddress,
        'src': _allowedAddress,
        'alt': _anyValue,
        'title': _anyValue,
        'id': _imageId.hasMatch,
      },
      'th': {
        'colspan': _cellSpan.hasMatch,
        'rowspan': _cellSpan.hasMatch,
        'colwidth': _columnWidths.hasMatch,
      },
      'td': {
        'colspan': _cellSpan.hasMatch,
        'rowspan': _cellSpan.hasMatch,
        'colwidth': _columnWidths.hasMatch,
        'data-background-color': _hexColor.hasMatch,
      },
    };

// What the editor's schema keeps inline; the rest starts a block, so the
// editor would not wrap it into a paragraph.
const _inlineTags = {
  'a',
  'b',
  'br',
  'code',
  'del',
  'em',
  'i',
  's',
  'span',
  'strike',
  'strong',
  'sub',
  'sup',
  'u',
};

bool _isInline(dom.Node node) => switch (node) {
  dom.Text() => true,
  dom.Element(:final localName) => _inlineTags.contains(localName),
  _ => false,
};

String _blockText(List<RichBlock> blocks, {required bool skipReplies}) => [
  for (final block in blocks)
    switch (block) {
      RichParagraph(:final inlines) ||
      RichHeading(:final inlines) => _inlineText(inlines),
      RichBulletList(:final items) || RichOrderedList(:final items) => [
        for (final item in items)
          _blockText(item.blocks, skipReplies: skipReplies),
      ].join(' '),
      RichTaskList(:final items) => [
        for (final item in items)
          _blockText(item.blocks, skipReplies: skipReplies),
      ].join(' '),
      RichBlockquote(:final commentId) when skipReplies && commentId != null =>
        '',
      RichBlockquote(:final blocks) => _blockText(
        blocks,
        skipReplies: skipReplies,
      ),
      RichCodeBlock(:final text) => text,
      RichTable(:final rows) => [
        for (final row in rows)
          for (final cell in row.cells)
            _blockText(cell.blocks, skipReplies: skipReplies),
      ].join(' '),
      RichHorizontalRule() || RichImage() => '',
    },
].join(' ');

String _inlineText(List<RichInline> inlines) => inlines
    .map(
      (inline) => switch (inline) {
        RichTextRun(:final text) => text,
        RichHardBreak() => ' ',
        RichMention(:final username, :final label) => _mentionText(
          label.isEmpty ? username : label,
        ),
        RichTaskLink(:final href) => href,
      },
    )
    .join();

String _mentionText(String label) => '@${label.replaceFirst(_leadingAts, '')}';
