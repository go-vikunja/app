import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:vikunja_logic/src/links/attachment_urls.dart';
import 'package:vikunja_logic/src/links/task_links.dart';
import 'package:vikunja_logic/src/links/url_text.dart';
import 'package:vikunja_logic/src/text/checklist.dart';
import 'package:vikunja_logic/src/text/rich_text.dart';
import 'package:vikunja_logic/src/text/rich_text_schema.dart';

// ProseMirror's DOMParser (prosemirror-model 1.25) over the editor schema,
// with the parse rules TipTap and Vikunja register, ported to work on
// package:html. Only what this schema can reach is ported: no open slices,
// no position tracking, and whitespace is always preserved because TipTap
// parses with `preserveWhitespace: true`.

const _bodyPrefix = '<body>';

// Deeper markup is flattened to its text, so that neither this parser nor
// a widget tree built from the result can run out of stack.
const _maxDepth = 96;

RichDocument buildRichDocument(
  String html, {
  required Uri apiRoot,
  required List<Uri> taskLinkBases,
}) {
  final source = '$_bodyPrefix$html</body>';
  final body = html_parser.parse(source, generateSpans: true).body!;
  _prepare(body);
  final context = _ParseContext(
    _Rules(taskLinkBases: taskLinkBases, offsets: _SourceOffsets(html, source)),
  )..addAll(body, const []);
  return _Converter(apiRoot).document(context.finish());
}

// Never visited: ProseMirror's ignored tags plus everything that embeds,
// executes or asks for input.
const droppedTags = {
  'head',
  'noscript',
  'object',
  'script',
  'style',
  'title',
  'iframe',
  'template',
  'svg',
  'math',
  'embed',
  'video',
  'audio',
  'canvas',
  'noembed',
  'noframes',
  'frameset',
  'frame',
  'button',
  'input',
  'select',
  'option',
  'optgroup',
  'datalist',
  'textarea',
};

const blockTags = {
  'address',
  'article',
  'aside',
  'blockquote',
  'body',
  'canvas',
  'dd',
  'div',
  'dl',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hgroup',
  'hr',
  'li',
  'noscript',
  'ol',
  'output',
  'p',
  'pre',
  'section',
  'table',
  'tfoot',
  'ul',
};

// TipTap's `removeWhitespaces`: `\s` as in JavaScript.
final _tipTapBlank = RegExp(r'^(\n\s\s|\n)$');

/// Removes TipTap's blank text nodes and flattens what is nested deeper
/// than [_maxDepth], without recursion.
void _prepare(dom.Element body) {
  final pending = <(dom.Element, int)>[(body, 0)];
  while (pending.isNotEmpty) {
    final (element, depth) = pending.removeLast();
    if (droppedTags.contains(element.localName)) continue;
    if (depth >= _maxDepth) {
      final text = _visibleText(element);
      element.nodes.clear();
      if (text.isNotEmpty) element.append(dom.Text(text));
      continue;
    }
    for (var i = element.nodes.length - 1; i >= 0; i--) {
      final child = element.nodes[i];
      if (child is dom.Text && _tipTapBlank.hasMatch(child.data)) {
        child.remove();
      } else if (child is dom.Element) {
        pending.add((child, depth + 1));
      }
    }
  }
}

String _visibleText(dom.Element root) {
  final text = StringBuffer();
  final pending = <dom.Node>[root];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    switch (node) {
      case dom.Text(:final data):
        text.write(data);
      case dom.Element(:final localName) when !droppedTags.contains(localName):
        if (localName == 'br') text.write('\n');
        pending.addAll(node.nodes.reversed);
      default:
        break;
    }
  }
  return text.toString();
}

final class _Attrs {
  const new({
    this.level = 1,
    this.start = 1,
    this.commentId,
    this.language,
    this.checked = false,
    this.sourceOffset,
    this.taskItemId,
    this.colspan = 1,
    this.rowspan = 1,
    this.align,
    this.backgroundColor,
    this.href = '',
    this.taskId = 0,
    this.username = '',
    this.label = '',
    this.src = '',
    this.dataSrc,
    this.alt = '',
    this.title = '',
  });

  final int level;
  final int start;
  final int? commentId;
  final String? language;
  final bool checked;
  final int? sourceOffset;
  final String? taskItemId;
  final int colspan;
  final int rowspan;
  final RichAlign? align;
  final int? backgroundColor;
  final String href;
  final int taskId;
  final String username;
  final String label;
  final String src;
  final String? dataSrc;
  final String alt;
  final String title;
}

final class _Node {
  new(
    this.kind,
    this.attrs,
    this.content, {
    this.text = '',
    this.marks = const [],
  });

  new ofText(String text)
    : this(NodeKind.text, const _Attrs(), const [], text: text);

  /// ProseMirror's `Fragment.from`: adjacent text with the same marks is
  /// one text node.
  factory create(NodeKind kind, _Attrs attrs, List<_Node> content) {
    final joined = <_Node>[];
    for (final node in content) {
      final previous = joined.lastOrNull;
      if (previous != null &&
          previous.kind == NodeKind.text &&
          node.kind == NodeKind.text &&
          _sameMarks(previous.marks, node.marks)) {
        joined[joined.length - 1] = previous.withText(
          previous.text + node.text,
        );
      } else {
        joined.add(node);
      }
    }
    return _Node(kind, attrs, joined);
  }

  factory createAndFill(NodeKind kind) => _Node.create(kind, const _Attrs(), [
    for (final filler
        in kind.contentMatch.fillBefore(const [], toEnd: true) ??
            const <NodeKind>[])
      _Node.createAndFill(filler),
  ]);

  final NodeKind kind;
  final _Attrs attrs;
  final List<_Node> content;
  final String text;
  final List<ParsedMark> marks;

  _Node withMarks(List<ParsedMark> marks) =>
      _Node(kind, attrs, content, text: text, marks: marks);

  _Node withText(String text) =>
      _Node(kind, attrs, content, text: text, marks: marks);
}

bool _sameMarks(List<ParsedMark> a, List<ParsedMark> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const _preserveWhitespace = 1;
const _preserveWhitespaceFull = 2;

final class _NodeContext {
  new(this.kind, this.attrs, {required this.solid, required this.options})
    : match = kind.contentMatch;

  final NodeKind kind;
  final _Attrs attrs;
  final bool solid;
  int options;
  ContentMatch? match;
  final List<_Node> content = [];

  List<NodeKind>? findWrapping(NodeKind node) => match?.findWrapping(node);

  _Node finish() => _Node.create(kind, attrs, [
    ...content,
    for (final filler
        in match?.fillBefore(const [], toEnd: true) ?? const <NodeKind>[])
      _Node.createAndFill(filler),
  ]);
}

typedef _Rule = ({
  NodeKind? node,
  ParsedMark? mark,
  _Attrs attrs,
  bool preserveFull,
  dom.Element Function(dom.Element element)? contentElement,
});

_Rule _nodeRule(
  NodeKind node, [
  _Attrs attrs = const _Attrs(),
  dom.Element Function(dom.Element element)? contentElement,
]) => (
  node: node,
  mark: null,
  attrs: attrs,
  preserveFull: node == NodeKind.codeBlock,
  contentElement: contentElement,
);

_Rule _markRule(ParsedMark mark) => (
  node: null,
  mark: mark,
  attrs: const _Attrs(),
  preserveFull: false,
  contentElement: null,
);

const _bold = ParsedMark(MarkKind.bold);
const _italic = ParsedMark(MarkKind.italic);
const _strike = ParsedMark(MarkKind.strike);
const _underline = ParsedMark(MarkKind.underline);

final class _ParseContext {
  new(this._rules)
    : _nodes = [
        _NodeContext(
          NodeKind.doc,
          const _Attrs(),
          solid: true,
          options: _preserveWhitespace,
        ),
      ];

  final _Rules _rules;
  final List<_NodeContext> _nodes;
  int _open = 0;
  bool _localPreserveWhitespace = false;

  _NodeContext get _top => _nodes[_open];

  void addAll(dom.Node parent, List<ParsedMark> marks) {
    for (final child in List.of(parent.nodes)) {
      switch (child) {
        case dom.Text(:final data):
          _addText(data, marks);
        case dom.Element():
          _addElement(child, marks);
        default:
          break;
      }
    }
  }

  _Node finish() {
    _open = 0;
    _closeExtra();
    return _nodes.first.finish();
  }

  void _addText(String value, List<ParsedMark> marks) {
    final top = _top;
    final full = top.options & _preserveWhitespaceFull != 0;
    if (!full && !top.kind.inlineContent && !_nonWhitespace.hasMatch(value)) {
      return;
    }
    var text = value;
    if (full) {
      text = text.replaceAll(_carriageReturns, '\n');
    } else if (_lineBreak.hasMatch(text) &&
        top.findWrapping(NodeKind.hardBreak) != null) {
      final lines = text.split(_lineBreaks);
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) {
          _insertNode(
            _Node(NodeKind.hardBreak, const _Attrs(), const []),
            marks,
            cautious: true,
          );
        }
        final line = lines[i];
        if (line.isNotEmpty) {
          _insertNode(
            _Node.ofText(line),
            marks,
            cautious: !_nonSpace.hasMatch(line),
          );
        }
      }
      text = '';
    } else {
      text = text.replaceAll(_lineBreaks, ' ');
    }
    if (text.isNotEmpty) {
      _insertNode(
        _Node.ofText(text),
        marks,
        cautious: !_nonSpace.hasMatch(text),
      );
    }
  }

  void _addElement(dom.Element element, List<ParsedMark> marks) {
    final outerPreserve = _localPreserveWhitespace;
    final name = element.localName ?? '';
    if (droppedTags.contains(name)) return;
    final style = _styleOf(element);
    if (name == 'pre' || (style['white-space']?.contains('pre') ?? false)) {
      _localPreserveWhitespace = true;
    }
    if (name == 'ul' || name == 'ol') _normalizeList(element);
    final rule = _rules.match(element, style);
    if (rule == null) {
      var top = _top;
      var sync = false;
      if (blockTags.contains(name)) {
        if (top.content.isNotEmpty &&
            top.content.first.kind.isInline &&
            _open > 0) {
          _open--;
          top = _top;
        }
        sync = true;
      } else if (element.nodes.isEmpty) {
        _leafFallback(element, marks);
        _localPreserveWhitespace = outerPreserve;
        return;
      }
      addAll(element, _readStyles(style, marks));
      if (sync) _sync(top);
    } else {
      _addElementByRule(element, rule, _readStyles(style, marks));
    }
    _localPreserveWhitespace = outerPreserve;
  }

  void _leafFallback(dom.Element element, List<ParsedMark> marks) {
    if (element.localName == 'br' && _top.kind.inlineContent) {
      _addText('\n', marks);
    }
  }

  /// The mark rules TipTap registers for `style`, in their priority order.
  List<ParsedMark> _readStyles(
    Map<String, String> style,
    List<ParsedMark> marks,
  ) {
    if (style.isEmpty) return marks;
    var result = marks;
    switch (style['font-weight']) {
      case '400':
        result = [...result.where((mark) => mark != _bold)];
      case final String weight when _boldWeight.hasMatch(weight):
        result = [...result, _bold];
    }
    switch (style['font-style']) {
      case 'normal':
        result = [...result.where((mark) => mark != _italic)];
      case 'italic':
        result = [...result, _italic];
    }
    final decoration = style['text-decoration'];
    if (decoration != null && decoration.contains('line-through')) {
      result = [...result, _strike];
    }
    switch (style['vertical-align']) {
      case 'sub':
        result = [...result, const ParsedMark(MarkKind.subscript)];
      case 'super':
        result = [...result, const ParsedMark(MarkKind.superscript)];
    }
    if (decoration != null && decoration.contains('underline')) {
      result = [...result, _underline];
    }
    return result;
  }

  void _addElementByRule(
    dom.Element element,
    _Rule rule,
    List<ParsedMark> marks,
  ) {
    var sync = false;
    var innerMarks = marks;
    final node = rule.node;
    if (node != null) {
      if (!node.isLeaf) {
        sync = _enter(node, rule.attrs, preserveFull: rule.preserveFull);
      } else if (!_insertNode(
        _Node(node, rule.attrs, const []),
        marks,
        cautious: element.localName == 'br',
      )) {
        _leafFallback(element, marks);
      }
    } else {
      innerMarks = [...marks, rule.mark!];
    }
    final startIn = _top;
    if (node == null || !node.isLeaf) {
      addAll(rule.contentElement?.call(element) ?? element, innerMarks);
    }
    if (sync && _sync(startIn)) _open--;
  }

  /// Moves to the nearest open node that takes [node], directly or
  /// through the fewest new wrappers, closing what is in between; a solid
  /// node (one the markup opened) costs two wrappers to leave and stops a
  /// [cautious] search.
  bool _findPlace(NodeKind node, {required bool cautious}) {
    List<NodeKind>? route;
    _NodeContext? target;
    var penalty = 0;
    for (var depth = _open; depth >= 0; depth--) {
      final context = _nodes[depth];
      final found = context.findWrapping(node);
      if (found != null &&
          (route == null || route.length > found.length + penalty)) {
        route = found;
        target = context;
        if (found.isEmpty) break;
      }
      if (context.solid) {
        if (cautious) break;
        penalty += 2;
      }
    }
    if (route == null) return false;
    _sync(target!);
    for (final wrapper in route) {
      _enterInner(wrapper, const _Attrs(), solid: false);
    }
    return true;
  }

  bool _insertNode(
    _Node node,
    List<ParsedMark> marks, {
    required bool cautious,
  }) {
    if (!_findPlace(node.kind, cautious: cautious)) return false;
    _closeExtra();
    final top = _top;
    top.match = top.match?.matchKind(node.kind);
    var nodeMarks = const <ParsedMark>[];
    if (top.kind.allowsMarks) {
      for (final mark in marks) {
        nodeMarks = addMarkToSet(mark, nodeMarks);
      }
    }
    top.content.add(node.withMarks(nodeMarks));
    return true;
  }

  bool _enter(NodeKind node, _Attrs attrs, {required bool preserveFull}) {
    if (!_findPlace(node, cautious: false)) return false;
    _enterInner(node, attrs, solid: true, preserveFull: preserveFull);
    return true;
  }

  // ProseMirror gives a new node the marks its parent allows; only
  // paragraphs and headings allow marks and only leaves go into them, so
  // the marks always pass on to the content instead.
  void _enterInner(
    NodeKind node,
    _Attrs attrs, {
    required bool solid,
    bool preserveFull = false,
  }) {
    _closeExtra();
    final top = _top;
    top.match = top.match?.matchKind(node);
    _nodes.add(
      _NodeContext(
        node,
        attrs,
        solid: solid,
        options: preserveFull
            ? _preserveWhitespace | _preserveWhitespaceFull
            : top.options,
      ),
    );
    _open++;
  }

  void _closeExtra() {
    for (var i = _nodes.length - 1; i > _open; i--) {
      _nodes[i - 1].content.add(_nodes[i].finish());
    }
    _nodes.length = _open + 1;
  }

  bool _sync(_NodeContext to) {
    for (var i = _open; i >= 0; i--) {
      if (identical(_nodes[i], to)) {
        _open = i;
        return true;
      }
      if (_localPreserveWhitespace) {
        _nodes[i].options |= _preserveWhitespace;
      }
    }
    return false;
  }
}

final _nonWhitespace = RegExp(r'[^ \t\r\n\f]');
final _nonSpace = RegExp(r'\S');
final _lineBreak = RegExp(r'[\r\n]');
final _lineBreaks = RegExp(r'\r?\n|\r');
final _carriageReturns = RegExp(r'\r\n?');
final _boldWeight = RegExp(r'^(bold(er)?|[5-9]\d{2,})$');

/// ProseMirror's fix for lists nested directly in a list: they move into
/// the list item before them.
void _normalizeList(dom.Element list) {
  dom.Element? previousItem;
  var i = 0;
  while (i < list.nodes.length) {
    final child = list.nodes[i];
    if (child is dom.Element) {
      final name = child.localName;
      if ((name == 'ul' || name == 'ol') && previousItem != null) {
        previousItem.append(child);
        continue;
      }
      previousItem = name == 'li' ? child : null;
    }
    i++;
  }
}

/// The declarations of the `style` attribute, names and values lower-cased
/// like a browser serialises keywords; the last one of a name wins.
Map<String, String> _styleOf(dom.Element element) {
  final style = element.attributes['style'];
  if (style == null || style.isEmpty) return const {};
  final declarations = <String, String>{};
  for (final declaration in _withoutCssComments(style).split(';')) {
    final colon = declaration.indexOf(':');
    if (colon <= 0) continue;
    final name = declaration.substring(0, colon).trim().toLowerCase();
    final value = _withoutImportant(declaration.substring(colon + 1).trim())
        .toLowerCase();
    if (name.isNotEmpty && value.isNotEmpty) declarations[name] = value;
  }
  return declarations;
}

// Index loops instead of regular expressions: style values are attacker
// controlled and backtracking patterns are quadratic on long ones.
String _withoutCssComments(String style) {
  var open = style.indexOf('/*');
  if (open < 0) return style;
  final kept = StringBuffer();
  var from = 0;
  while (open >= 0) {
    kept.write(style.substring(from, open));
    final close = style.indexOf('*/', open + 2);
    if (close < 0) return kept.toString();
    from = close + 2;
    open = style.indexOf('/*', from);
  }
  kept.write(style.substring(from));
  return kept.toString();
}

String _withoutImportant(String value) {
  final bang = value.lastIndexOf('!');
  if (bang < 0 ||
      value.substring(bang + 1).trimLeft().toLowerCase() != 'important') {
    return value;
  }
  return value.substring(0, bang).trimRight();
}

final class _Rules {
  new({required this.taskLinkBases, required this.offsets});

  final List<Uri> taskLinkBases;
  final _SourceOffsets offsets;
  final _TaskItemIds taskItemIds = _TaskItemIds();

  /// The first tag rule of the schema, by priority, that matches.
  _Rule? match(dom.Element element, Map<String, String> style) {
    final attributes = element.attributes;
    switch (element.localName) {
      case 'a':
        final href = attributes['href'];
        if (href == null) return null;
        final taskId = _taskLinkId(element, href);
        if (taskId != null) {
          return _nodeRule(
            NodeKind.taskLink,
            _Attrs(href: href, taskId: taskId),
          );
        }
        final allowed = allowedLinkHref(href);
        return allowed == null
            ? null
            : _markRule(ParsedMark(MarkKind.link, href: allowed));
      case 'ul' when attributes['data-type'] == 'taskList':
        return _nodeRule(NodeKind.taskList);
      case 'li' when attributes['data-type'] == 'taskItem':
        final checked = attributes['data-checked'];
        return _nodeRule(
          NodeKind.taskItem,
          _Attrs(
            checked: checked == '' || checked == 'true',
            sourceOffset: offsets.of(element),
            taskItemId: taskItemIds.of(element),
          ),
          (element) => element.querySelector('div') ?? element,
        );
      case 'strong':
        return _markRule(_bold);
      case 'b' when style['font-weight'] != 'normal':
        return _markRule(_bold);
      case 'code':
        return _markRule(const ParsedMark(MarkKind.code));
      case 'em':
        return _markRule(_italic);
      case 'i' when style['font-style'] != 'normal':
        return _markRule(_italic);
      case 's' || 'del' || 'strike':
        return _markRule(_strike);
      case 'sub':
        return _markRule(const ParsedMark(MarkKind.subscript));
      case 'sup':
        return _markRule(const ParsedMark(MarkKind.superscript));
      case 'u':
        return _markRule(_underline);
      case 'p':
        return _nodeRule(NodeKind.paragraph);
      case 'mention-user':
        return _nodeRule(
          NodeKind.mention,
          _Attrs(
            username: attributes['data-id'] ?? '',
            label: attributes['data-label'] ?? '',
          ),
        );
      case 'ul':
        return _nodeRule(NodeKind.bulletList);
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return _nodeRule(
          NodeKind.heading,
          _Attrs(level: int.parse(element.localName!.substring(1))),
        );
      case 'hr':
        return _nodeRule(NodeKind.horizontalRule);
      case 'li':
        return _nodeRule(NodeKind.listItem);
      case 'ol':
        final start = attributes['start'];
        return _nodeRule(
          NodeKind.orderedList,
          _Attrs(start: start == null ? 1 : _jsParseInt(start) ?? 1),
        );
      case 'blockquote':
        return _nodeRule(
          NodeKind.blockquote,
          _Attrs(commentId: _commentId(attributes['data-comment-id'])),
        );
      case 'pre':
        return _nodeRule(
          NodeKind.codeBlock,
          _Attrs(language: _language(element)),
        );
      case 'br':
        return _nodeRule(NodeKind.hardBreak);
      case 'table':
        return _nodeRule(NodeKind.table);
      case 'tr':
        return _nodeRule(NodeKind.tableRow);
      case 'th':
        return _nodeRule(NodeKind.tableHeader, _cellAttrs(element, style));
      case 'td':
        return _nodeRule(
          NodeKind.tableCell,
          _cellAttrs(element, style, withBackground: true),
        );
      case 'img':
        final src = attributes['src'];
        if (src == null || src.startsWith('data:')) return null;
        return _nodeRule(
          NodeKind.image,
          _Attrs(
            src: src,
            dataSrc: attributes['data-src'],
            alt: attributes['alt'] ?? '',
            title: attributes['title'] ?? '',
          ),
        );
    }
    return null;
  }

  int? _taskLinkId(dom.Element anchor, String href) {
    if (anchor.children.isNotEmpty ||
        !anchor.attributes.keys.every(_plainAnchorAttributes.contains) ||
        anchor.text.trim() != href) {
      return null;
    }
    return parseTaskIdFromUrl(href, bases: taskLinkBases);
  }
}

const _plainAnchorAttributes = {'href', 'target', 'rel'};

final _linkWhitespace = RegExp(
  r'[\x00-\x20\xA0\u1680\u180E\u2000-\u2029\u205F\u3000]',
);
final _allowedUri = RegExp(
  '^(?:(?:http|https|ftp|ftps|mailto|tel|callto|sms|cid|xmpp|git|obsidian'
  r'|notion|message):|[^a-z]|[a-z0-9+.\-]+(?:[^a-z+.\-:]|$))',
  caseSensitive: false,
);

/// The href a link keeps, or null when the web drops the link: TipTap's
/// `isAllowedUri` with Vikunja's extra protocols, tested on the href
/// without any whitespace or control character. The href comes back
/// cleaned the way a browser cleans a URL (see `cleanUrlText`), and the
/// cleaned text must pass the same test.
String? allowedLinkHref(String href) {
  if (href.isEmpty ||
      !_allowedUri.hasMatch(href.replaceAll(_linkWhitespace, ''))) {
    return null;
  }
  final cleaned = cleanUrlText(href);
  return cleaned.isNotEmpty && _allowedUri.hasMatch(cleaned) ? cleaned : null;
}

/// JavaScript's `parseInt(value, 10)`, null for NaN.
int? _jsParseInt(String value) {
  final match = _leadingInteger.firstMatch(value);
  return match == null ? null : int.tryParse(match[1]!);
}

final _leadingInteger = RegExp(r'^\s*([+-]?\d+)');

/// `Number(raw)` that is a positive integer, as the web's
/// `BlockquoteWithCommentId` accepts it.
int? _commentId(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final number = _hexNumber.hasMatch(trimmed)
      ? int.tryParse(trimmed.substring(2), radix: 16)?.toDouble()
      : (_decimalNumber.hasMatch(trimmed) ? double.tryParse(trimmed) : null);
  if (number == null ||
      !number.isFinite ||
      number != number.truncateToDouble() ||
      number <= 0 ||
      number > maxSafeInteger) {
    return null;
  }
  return number.toInt();
}

final _hexNumber = RegExp(r'^0[xX][0-9a-fA-F]+$');
// The digit runs must not overlap: an overlapping pattern backtracks
// quadratically on a long attribute.
final _decimalNumber = RegExp(r'^\+?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$');

final _classSeparators = RegExp(r'[\t\n\f\r ]+');

String? _language(dom.Element pre) {
  final first = pre.children.firstOrNull;
  final classes = first?.attributes['class'];
  if (classes == null) return null;
  for (final name in classes.split(_classSeparators)) {
    if (name.startsWith('language-')) {
      final language = name.substring('language-'.length);
      return language.isEmpty ? null : language;
    }
  }
  return null;
}

_Attrs _cellAttrs(
  dom.Element cell,
  Map<String, String> style, {
  bool withBackground = false,
}) {
  final align = switch ((style['text-align'] ?? '').trim()) {
    '' => (cell.attributes['align'] ?? '').trim().toLowerCase(),
    final styled => styled,
  };
  return _Attrs(
    colspan: _span(cell.attributes['colspan'], max: 1000),
    rowspan: _span(cell.attributes['rowspan'], max: 65534),
    align: switch (align) {
      'left' => RichAlign.left,
      'center' => RichAlign.center,
      'right' => RichAlign.right,
      _ => null,
    },
    backgroundColor: withBackground
        ? _cellColor(cell.attributes['data-background-color'])
        : null,
  );
}

int _span(String? value, {required int max}) {
  final span = int.tryParse(value?.trim() ?? '');
  return span != null && span >= 1 && span <= max ? span : 1;
}

final _hexColor = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
final _rgbColor = RegExp(
  r'^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$',
  caseSensitive: false,
);

int? _cellColor(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (_hexColor.firstMatch(trimmed) case final match?) {
    var hex = match[1]!;
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    return 0xFF000000 | int.parse(hex, radix: 16);
  }
  if (_rgbColor.firstMatch(trimmed) case final match?) {
    final channels = [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
    if (channels.any((channel) => channel > 255)) return null;
    return 0xFF000000 | channels[0] << 16 | channels[1] << 8 | channels[2];
  }
  return null;
}

/// Where each task item's `data-checked` stands in the raw HTML, in the
/// terms of `findCheckboxesInText`. package:html reports positions after
/// its CR LF normalisation, so they are mapped back to the raw text.
final class _SourceOffsets {
  new(this._html, String source)
    : _checkboxes = findCheckboxesInText(_html).toSet(),
      _deletions = _crLfDeletions(source);

  final String _html;
  final Set<int> _checkboxes;
  final List<int> _deletions;
  final Set<int> _claimed = {};

  static List<int> _crLfDeletions(String source) {
    final deletions = <int>[];
    var emitted = 0;
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0a &&
          i > 0 &&
          source.codeUnitAt(i - 1) == 0x0d) {
        deletions.add(emitted);
        continue;
      }
      emitted++;
    }
    return deletions;
  }

  int _raw(int normalized) {
    var low = 0;
    var high = _deletions.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_deletions[middle] <= normalized) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return normalized + low;
  }

  int? of(dom.Element item) {
    final span = item.sourceSpan;
    if (_checkboxes.isEmpty || span == null) return null;
    final start = _raw(span.start.offset) - _bodyPrefix.length;
    final end = _raw(span.end.offset) - _bodyPrefix.length;
    if (start < 0 || end > _html.length || start >= end) return null;
    final attribute = _attributeStart(
      _html.substring(start, end),
      'data-checked',
    );
    if (attribute == null) return null;
    final offset = start + attribute;
    return _checkboxes.contains(offset) && _claimed.add(offset) ? offset : null;
  }
}

/// `data-task-id` as the web keeps it: a missing, empty or repeated id is
/// one the web replaces with a new random id when it loads the HTML.
final class _TaskItemIds {
  final Map<dom.Element, String?> _ids = Map.identity();
  final Set<String> _seen = {};

  String? of(dom.Element item) => _ids.putIfAbsent(item, () {
    final id = item.attributes['data-task-id'];
    return id == null || id.isEmpty || !_seen.add(id) ? null : id;
  });
}

final _startTag = RegExp(r'^<li(?=[\t\n\f\r />])', caseSensitive: false);

/// The position of the first attribute called [name] in a raw `<li …>`
/// start tag, read like the HTML tokenizer does.
int? _attributeStart(String tag, String name) {
  final opening = _startTag.firstMatch(tag);
  if (opening == null) return null;
  var i = opening.end;
  bool isSpace(int at) => ' \t\n\f\r'.contains(tag[at]);
  while (i < tag.length) {
    while (i < tag.length && (isSpace(i) || tag[i] == '/')) {
      i++;
    }
    if (i >= tag.length || tag[i] == '>') return null;
    final nameStart = i;
    i++;
    while (i < tag.length &&
        !isSpace(i) &&
        tag[i] != '/' &&
        tag[i] != '>' &&
        tag[i] != '=') {
      i++;
    }
    final attributeName = tag.substring(nameStart, i).toLowerCase();
    while (i < tag.length && isSpace(i)) {
      i++;
    }
    if (i < tag.length && tag[i] == '=') {
      i++;
      while (i < tag.length && isSpace(i)) {
        i++;
      }
      if (i < tag.length && (tag[i] == '"' || tag[i] == "'")) {
        final close = tag.indexOf(tag[i], i + 1);
        i = close < 0 ? tag.length : close + 1;
      } else {
        while (i < tag.length && !isSpace(i) && tag[i] != '>') {
          i++;
        }
      }
    }
    if (attributeName == name) return nameStart;
  }
  return null;
}

final class _Converter {
  new(this._apiRoot);

  final Uri _apiRoot;

  /// At least one block, like ProseMirror's `block+`, also when every
  /// block was an image that is dropped here.
  RichDocument document(_Node doc) {
    final blocks = _blocks(doc.content);
    return RichDocument(blocks.isEmpty ? const [RichParagraph([])] : blocks);
  }

  List<RichBlock> _blocks(List<_Node> nodes) =>
      List.unmodifiable([for (final node in nodes) ?_block(node)]);

  RichBlock? _block(_Node node) {
    final attrs = node.attrs;
    return switch (node.kind) {
      NodeKind.paragraph => RichParagraph(_inlines(node.content)),
      NodeKind.heading => RichHeading(attrs.level, _inlines(node.content)),
      NodeKind.blockquote => RichBlockquote(
        _blocks(node.content),
        commentId: attrs.commentId,
      ),
      NodeKind.bulletList => RichBulletList(_listItems(node.content)),
      NodeKind.orderedList => RichOrderedList(
        _listItems(node.content),
        start: attrs.start,
      ),
      NodeKind.taskList => RichTaskList(
        List.unmodifiable([
          for (final item in node.content)
            if (item.kind == NodeKind.taskItem)
              RichTaskItem(
                checked: item.attrs.checked,
                blocks: _blocks(item.content),
                sourceOffset: item.attrs.sourceOffset,
                taskId: item.attrs.taskItemId,
              ),
        ]),
      ),
      NodeKind.codeBlock => RichCodeBlock(
        node.content.map((text) => text.text).join(),
        language: attrs.language,
      ),
      NodeKind.horizontalRule => const RichHorizontalRule(),
      NodeKind.table => RichTable(
        List.unmodifiable([
          for (final row in node.content)
            if (row.kind == NodeKind.tableRow)
              RichTableRow(
                List.unmodifiable([
                  for (final cell in row.content) _cell(cell),
                ]),
              ),
        ]),
      ),
      NodeKind.image => _image(attrs),
      _ => null,
    };
  }

  List<RichListItem> _listItems(List<_Node> items) => List.unmodifiable([
    for (final item in items)
      if (item.kind == NodeKind.listItem) RichListItem(_blocks(item.content)),
  ]);

  RichTableCell _cell(_Node cell) => RichTableCell(
    blocks: _blocks(cell.content),
    header: cell.kind == NodeKind.tableHeader,
    colspan: cell.attrs.colspan,
    rowspan: cell.attrs.rowspan,
    align: cell.attrs.align,
    backgroundColor: cell.attrs.backgroundColor,
  );

  RichImage? _image(_Attrs attrs) {
    final attachment = parseAttachmentUrl(
      attrs.dataSrc ?? attrs.src,
      apiRoot: _apiRoot,
    );
    final RichImageSource source;
    if (attachment != null) {
      source = RichAttachmentImage(attachment);
    } else {
      final url = Uri.tryParse(cleanUrlText(attrs.src));
      if (url == null ||
          (url.scheme != 'http' && url.scheme != 'https') ||
          url.host.isEmpty) {
        return null;
      }
      source = RichExternalImage(url);
    }
    return RichImage(source, alt: attrs.alt, title: attrs.title);
  }

  List<RichInline> _inlines(List<_Node> nodes) {
    final inlines = <RichInline>[];
    for (final node in nodes) {
      final inline = _inline(node);
      if (inline == null) continue;
      final previous = inlines.lastOrNull;
      if (inline is RichTextRun &&
          previous is RichTextRun &&
          previous.href == inline.href &&
          _sameRichMarks(previous.marks, inline.marks)) {
        inlines[inlines.length - 1] = RichTextRun(
          previous.text + inline.text,
          marks: previous.marks,
          href: previous.href,
        );
      } else {
        inlines.add(inline);
      }
    }
    return List.unmodifiable(inlines);
  }

  RichInline? _inline(_Node node) {
    final attrs = node.attrs;
    return switch (node.kind) {
      NodeKind.text => _textRun(node),
      NodeKind.hardBreak => const RichHardBreak(),
      NodeKind.mention
          when attrs.username.isNotEmpty || attrs.label.isNotEmpty =>
        RichMention(username: attrs.username, label: attrs.label),
      NodeKind.taskLink => RichTaskLink(taskId: attrs.taskId, href: attrs.href),
      _ => null,
    };
  }

  RichTextRun _textRun(_Node node) {
    String? href;
    final marks = <RichMark>{};
    for (final mark in node.marks) {
      switch (mark.kind) {
        case MarkKind.link:
          href = mark.href;
        case MarkKind.bold:
          marks.add(RichMark.bold);
        case MarkKind.code:
          marks.add(RichMark.code);
        case MarkKind.italic:
          marks.add(RichMark.italic);
        case MarkKind.strike:
          marks.add(RichMark.strike);
        case MarkKind.subscript:
          marks.add(RichMark.subscript);
        case MarkKind.superscript:
          marks.add(RichMark.superscript);
        case MarkKind.underline:
          marks.add(RichMark.underline);
      }
    }
    return RichTextRun(node.text, marks: Set.unmodifiable(marks), href: href);
  }
}

bool _sameRichMarks(Set<RichMark> a, Set<RichMark> b) =>
    a.length == b.length && a.containsAll(b);
