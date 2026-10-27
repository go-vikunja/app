import 'package:meta/meta.dart';

// The web editor's schema (TipTap 3.31.3 with Vikunja's extensions, see
// test/fixtures/sanitizer_oracle.json → schema) as ProseMirror sees it:
// node types in schema order, their content expressions as small automata
// and the marks by rank. Order matters: it decides which wrapper or filler
// ProseMirror picks.
//
// The content matching and the mark sets are translated from
// prosemirror-model, Copyright (C) 2015-2017 by Marijn Haverbeke and others,
// MIT License; see THIRD_PARTY_NOTICES.md in this package.

enum NodeKind {
  doc,
  paragraph,
  heading,
  blockquote,
  bulletList,
  orderedList,
  listItem,
  taskList,
  taskItem,
  codeBlock,
  horizontalRule,
  hardBreak,
  table,
  tableRow,
  tableHeader,
  tableCell,
  image,
  mention,
  taskLink,
  text;

  bool get isInline =>
      this == text || this == hardBreak || this == mention || this == taskLink;

  bool get isLeaf => isInline || this == horizontalRule || this == image;

  bool get inlineContent =>
      this == paragraph || this == heading || this == codeBlock;

  /// Paragraphs and headings take every mark; a code block none; nodes
  /// with block content none either.
  bool get allowsMarks => this == paragraph || this == heading;

  ContentMatch get contentMatch => _contentMatches[this]!;
}

const List<NodeKind> _blocks = [
  NodeKind.paragraph,
  NodeKind.bulletList,
  NodeKind.heading,
  NodeKind.horizontalRule,
  NodeKind.orderedList,
  NodeKind.blockquote,
  NodeKind.codeBlock,
  NodeKind.table,
  NodeKind.image,
  NodeKind.taskList,
];

const List<NodeKind> _inlines = [
  NodeKind.taskLink,
  NodeKind.mention,
  NodeKind.text,
  NodeKind.hardBreak,
];

/// A state of a content expression: which node kinds may come next and
/// whether the content may end here.
final class ContentMatch {
  new({required this.validEnd});

  final bool validEnd;
  final List<(NodeKind, ContentMatch)> next = [];
  final Map<NodeKind, List<NodeKind>?> _wrappings = {};

  static final empty = ContentMatch(validEnd: true);

  ContentMatch? matchKind(NodeKind kind) {
    for (final (candidate, match) in next) {
      if (candidate == kind) return match;
    }
    return null;
  }

  ContentMatch? matchKinds(Iterable<NodeKind> kinds) {
    ContentMatch? current = this;
    for (final kind in kinds) {
      current = current?.matchKind(kind);
      if (current == null) return null;
    }
    return current;
  }

  /// The node kinds to create before [after] so that it fits (and, with
  /// [toEnd], so that the content is complete), depth first in schema
  /// order; null when nothing fits.
  List<NodeKind>? fillBefore(List<NodeKind> after, {bool toEnd = false}) {
    final seen = <ContentMatch>[this];
    List<NodeKind>? search(ContentMatch match, List<NodeKind> kinds) {
      final finished = match.matchKinds(after);
      if (finished != null && (!toEnd || finished.validEnd)) return kinds;
      for (final (kind, nextMatch) in match.next) {
        if (kind != NodeKind.text && !seen.contains(nextMatch)) {
          seen.add(nextMatch);
          final found = search(nextMatch, [...kinds, kind]);
          if (found != null) return found;
        }
      }
      return null;
    }

    return search(this, const []);
  }

  /// The shortest chain of wrappers (breadth first) that lets [target]
  /// appear here; empty when it fits as is, null when nothing helps.
  List<NodeKind>? findWrapping(NodeKind target) =>
      _wrappings.putIfAbsent(target, () => _computeWrapping(target));

  List<NodeKind>? _computeWrapping(NodeKind target) {
    final seen = <NodeKind>{};
    final active = <({ContentMatch match, List<NodeKind> path})>[
      (match: this, path: const []),
    ];
    while (active.isNotEmpty) {
      final current = active.removeAt(0);
      if (current.match.matchKind(target) != null) return current.path;
      for (final (kind, nextMatch) in current.match.next) {
        if (!kind.isLeaf &&
            !seen.contains(kind) &&
            (current.path.isEmpty || nextMatch.validEnd)) {
          active.add((match: kind.contentMatch, path: [...current.path, kind]));
          seen.add(kind);
        }
      }
    }
    return null;
  }
}

ContentMatch _star(List<NodeKind> kinds) {
  final state = ContentMatch(validEnd: true);
  state.next.addAll([for (final kind in kinds) (kind, state)]);
  return state;
}

ContentMatch _plus(List<NodeKind> kinds) {
  final start = ContentMatch(validEnd: false);
  final more = _star(kinds);
  start.next.addAll([for (final kind in kinds) (kind, more)]);
  return start;
}

ContentMatch _paragraphThenBlocks() {
  final start = ContentMatch(validEnd: false);
  start.next.add((NodeKind.paragraph, _star(_blocks)));
  return start;
}

final Map<NodeKind, ContentMatch> _contentMatches = {
  NodeKind.doc: _plus(_blocks),
  NodeKind.paragraph: _star(_inlines),
  NodeKind.heading: _star(_inlines),
  NodeKind.blockquote: _plus(_blocks),
  NodeKind.bulletList: _plus(const [NodeKind.listItem]),
  NodeKind.orderedList: _plus(const [NodeKind.listItem]),
  NodeKind.listItem: _paragraphThenBlocks(),
  NodeKind.taskList: _plus(const [NodeKind.taskItem]),
  NodeKind.taskItem: _paragraphThenBlocks(),
  NodeKind.codeBlock: _star(const [NodeKind.text]),
  NodeKind.table: _plus(const [NodeKind.tableRow]),
  NodeKind.tableRow: _star(const [NodeKind.tableCell, NodeKind.tableHeader]),
  NodeKind.tableHeader: _plus(_blocks),
  NodeKind.tableCell: _plus(_blocks),
  for (final leaf in NodeKind.values.where((kind) => kind.isLeaf))
    leaf: ContentMatch.empty,
};

/// Marks by rank, the order ProseMirror keeps them in.
enum MarkKind {
  link,
  bold,
  code,
  italic,
  strike,
  subscript,
  superscript,
  underline,
}

/// `code` excludes every other mark (the schema's `excludes: '_'`); any
/// other mark excludes only itself.
bool _excludes(MarkKind a, MarkKind b) => a == b || a == MarkKind.code;

@immutable
final class ParsedMark {
  const new(this.kind, {this.href});

  final MarkKind kind;

  /// The link's target, for [MarkKind.link] only.
  final String? href;

  @override
  bool operator ==(Object other) =>
      other is ParsedMark && other.kind == kind && other.href == href;

  @override
  int get hashCode => Object.hash(kind, href);
}

/// ProseMirror's `Mark.addToSet`: [marks] stays sorted by rank, an equal
/// mark is not added twice, and an excluding mark replaces what it
/// excludes or is dropped when something already there excludes it.
List<ParsedMark> addMarkToSet(ParsedMark mark, List<ParsedMark> marks) {
  List<ParsedMark>? copy;
  var placed = false;
  for (var i = 0; i < marks.length; i++) {
    final other = marks[i];
    if (other == mark) return marks;
    if (_excludes(mark.kind, other.kind)) {
      copy ??= marks.sublist(0, i);
    } else if (_excludes(other.kind, mark.kind)) {
      return marks;
    } else {
      if (!placed && other.kind.index > mark.kind.index) {
        copy ??= marks.sublist(0, i);
        copy.add(mark);
        placed = true;
      }
      copy?.add(other);
    }
  }
  copy ??= [...marks];
  if (!placed) copy.add(mark);
  return copy;
}
