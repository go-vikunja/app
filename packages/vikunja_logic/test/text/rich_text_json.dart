import 'package:vikunja_logic/vikunja_logic.dart';

/// The tree as ProseMirror's `getJSON` would spell it, reduced to what the
/// tree models: node and mark names, the attributes the app uses, text.
/// Images carry where they load from instead of `src`/`data-src`.
Map<String, Object?> richDocumentJson(RichDocument document) =>
    _node('doc', content: document.blocks.map(_block).toList());

Map<String, Object?> _node(
  String type, {
  Map<String, Object?>? attrs,
  List<Object?> content = const [],
}) => {
  'type': type,
  'attrs': ?attrs,
  if (content.isNotEmpty) 'content': content,
};

Map<String, Object?> _block(RichBlock block) => switch (block) {
  RichParagraph(:final inlines) => _node(
    'paragraph',
    content: inlines.map(_inline).toList(),
  ),
  RichHeading(:final level, :final inlines) => _node(
    'heading',
    attrs: {'level': level},
    content: inlines.map(_inline).toList(),
  ),
  RichBlockquote(:final blocks, :final commentId) => _node(
    'blockquote',
    attrs: {'commentId': commentId},
    content: blocks.map(_block).toList(),
  ),
  RichBulletList(:final items) => _node(
    'bulletList',
    content: items.map(_listItem).toList(),
  ),
  RichOrderedList(:final items, :final start) => _node(
    'orderedList',
    attrs: {'start': start},
    content: items.map(_listItem).toList(),
  ),
  RichTaskList(:final items) => _node(
    'taskList',
    content: [
      for (final item in items)
        _node(
          'taskItem',
          attrs: {'checked': item.checked},
          content: item.blocks.map(_block).toList(),
        ),
    ],
  ),
  RichCodeBlock(:final text, :final language) => _node(
    'codeBlock',
    attrs: {'language': language},
    content: [
      if (text.isNotEmpty) {'type': 'text', 'text': text},
    ],
  ),
  RichHorizontalRule() => _node('horizontalRule'),
  RichTable(:final rows) => _node(
    'table',
    content: [
      for (final row in rows)
        _node('tableRow', content: row.cells.map(_cell).toList()),
    ],
  ),
  RichImage(:final source, :final alt, :final title) => _node(
    'image',
    attrs: {...imageSourceJson(source), 'alt': alt, 'title': title},
  ),
};

Map<String, Object?> _listItem(RichListItem item) =>
    _node('listItem', content: item.blocks.map(_block).toList());

Map<String, Object?> _cell(RichTableCell cell) => _node(
  cell.header ? 'tableHeader' : 'tableCell',
  attrs: {
    'colspan': cell.colspan,
    'rowspan': cell.rowspan,
    'align': cell.align?.name,
    if (!cell.header) 'backgroundColor': cell.backgroundColor,
  },
  content: cell.blocks.map(_block).toList(),
);

Map<String, Object?> imageSourceJson(RichImageSource source) =>
    switch (source) {
      RichAttachmentImage(:final attachment) => {
        'attachment': [attachment.taskId, attachment.attachmentId],
      },
      RichExternalImage(:final url) => {'external': url.toString()},
    };

Map<String, Object?> _inline(RichInline inline) => switch (inline) {
  RichTextRun(:final text, :final marks, :final href) => {
    'type': 'text',
    if (marks.isNotEmpty || href != null)
      'marks': [
        if (href != null) 'link $href',
        ...[for (final mark in marks) mark.name]..sort(),
      ],
    'text': text,
  },
  RichHardBreak() => {'type': 'hardBreak'},
  RichMention(:final username, :final label) => _node(
    'mention',
    attrs: {'id': username, 'label': label},
  ),
  RichTaskLink(:final href) => _node('taskLink', attrs: {'href': href}),
};

/// Every node of [document], depth first.
Iterable<Object> richNodes(RichDocument document) sync* {
  Iterable<Object> walk(List<RichBlock> blocks) sync* {
    for (final block in blocks) {
      yield block;
      switch (block) {
        case RichParagraph(:final inlines) || RichHeading(:final inlines):
          yield* inlines;
        case RichBlockquote(blocks: final inner):
          yield* walk(inner);
        case RichBulletList(:final items) || RichOrderedList(:final items):
          for (final item in items) {
            yield item;
            yield* walk(item.blocks);
          }
        case RichTaskList(:final items):
          for (final item in items) {
            yield item;
            yield* walk(item.blocks);
          }
        case RichTable(:final rows):
          for (final row in rows) {
            yield row;
            for (final cell in row.cells) {
              yield cell;
              yield* walk(cell.blocks);
            }
          }
        case RichImage(:final source):
          yield source;
        case RichCodeBlock() || RichHorizontalRule():
          break;
      }
    }
  }

  yield* walk(document.blocks);
}
