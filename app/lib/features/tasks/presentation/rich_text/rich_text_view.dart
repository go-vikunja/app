import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/inline_pills.dart';

// A span of up to 1000 columns would turn a small text into a million
// cells; a larger table shows row by row instead.
const _maxTableColumns = 50;
const _maxTableSlots = 5000;

const _checkboxTapTarget = 48.0;

/// A description or comment from the web editor's schema, drawn with the
/// app's theme: nothing in it loads or opens by itself. A tap on a link
/// goes to [onLink] with the href as the text has it, one on a task pill
/// to [onTaskLink]; attachment images load through the account's
/// authenticated client, other images only stand in as a link. With
/// [onToggleTaskItem] the checkboxes that can be toggled in place (those
/// with a source offset) take taps; the others stay read-only.
class RichTextView extends StatefulWidget {
  const new({
    required this.document,
    required this.onLink,
    required this.onTaskLink,
    this.onToggleTaskItem,
    this.style,
    this.projectId,
    this.replyAuthorOf,
    super.key,
  });

  final RichDocument document;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final ValueChanged<RichTaskItem>? onToggleTaskItem;

  /// The body text; the theme's `bodyMedium` when null.
  final TextStyle? style;

  /// The project of the task the text belongs to: a pill for a task there
  /// leaves the project out.
  final int? projectId;

  /// Who wrote the comment a reply quotes, when it is loaded.
  final User? Function(int commentId)? replyAuthorOf;

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  final _recognizers = <GestureRecognizer>[];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final renderer = _Renderer(
      view: widget,
      theme: theme,
      l10n: context.l10n,
      recognizers: _recognizers,
      textScaler: MediaQuery.textScalerOf(context),
    );
    return renderer.column(
      renderer.blocks(
        widget.document.blocks,
        _BlockStyle(text: widget.style ?? theme.textTheme.bodyMedium!),
      ),
      spacing: 8,
    );
  }
}

/// How the blocks inside a list item, quote or cell differ from the body.
final class _BlockStyle {
  const new({
    required this.text,
    this.struck = false,
    this.inTable = false,
    this.align,
  });

  final TextStyle text;

  /// A checked task item's own text.
  final bool struck;

  /// Inside a table cell, which sizes its column by the content's
  /// intrinsic width; scroll views cannot report one.
  final bool inTable;
  final TextAlign? align;

  _BlockStyle copyWith({
    TextStyle? text,
    bool? struck,
    bool? inTable,
    TextAlign? align,
  }) => _BlockStyle(
    text: text ?? this.text,
    struck: struck ?? this.struck,
    inTable: inTable ?? this.inTable,
    align: align ?? this.align,
  );
}

final class _Renderer {
  const new({
    required this.view,
    required this.theme,
    required this.l10n,
    required this.recognizers,
    required this.textScaler,
  });

  final RichTextView view;
  final ThemeData theme;
  final AppLocalizations l10n;
  final List<GestureRecognizer> recognizers;
  final TextScaler textScaler;

  ColorScheme get colors => theme.colorScheme;

  Widget column(List<Widget> children, {double spacing = 4}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: spacing,
    children: children,
  );

  List<Widget> blocks(
    List<RichBlock> blocks,
    _BlockStyle style, {
    int listDepth = 0,
  }) => [for (final block in blocks) this.block(block, style, listDepth)];

  Widget block(RichBlock block, _BlockStyle style, int listDepth) =>
      switch (block) {
        RichParagraph(:final inlines) => paragraph(inlines, style),
        RichHeading(:final level, :final inlines) => Semantics(
          header: true,
          headingLevel: level.clamp(1, 6),
          child: paragraph(
            inlines,
            style.copyWith(text: _headingStyle(level, style.text)),
          ),
        ),
        RichBulletList(:final items) => list(
          [for (final item in items) item.blocks],
          markers: List.filled(items.length, _bullet(listDepth)),
          style: style,
          listDepth: listDepth,
          announceMarkers: false,
        ),
        RichOrderedList(:final items, :final start) => list(
          [for (final item in items) item.blocks],
          markers: [for (var i = 0; i < items.length; i++) '${start + i}.'],
          style: style,
          listDepth: listDepth,
          announceMarkers: true,
        ),
        RichTaskList(:final items) => column([
          for (final item in items) taskItem(item, style, listDepth),
        ]),
        RichBlockquote(:final blocks, :final commentId) => quote(
          blocks,
          commentId,
          style,
          listDepth,
        ),
        RichCodeBlock(:final text) => codeBlock(text, style),
        RichHorizontalRule() => Divider(color: colors.outlineVariant),
        RichTable() when style.inTable => flatTable(block, style),
        RichTable() => table(block, style),
        RichImage() => image(block, style),
      };

  /// Bold and larger than the body, in step with it, each level at least
  /// as prominent as the next.
  static TextStyle _headingStyle(int level, TextStyle body) {
    final scale = switch (level) {
      1 => 1.4,
      2 => 1.25,
      3 => 1.125,
      _ => 1.0,
    };
    return body.copyWith(
      fontSize: (body.fontSize ?? 14) * scale,
      fontWeight: FontWeight.bold,
    );
  }

  static String _bullet(int depth) => switch (depth % 3) {
    0 => '•',
    1 => '◦',
    _ => '▪',
  };

  Widget paragraph(List<RichInline> inlines, _BlockStyle style) {
    final base = style.struck
        ? style.text.copyWith(
            color: colors.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
            decorationColor: colors.onSurfaceVariant,
          )
        : style.text;
    return Text.rich(
      TextSpan(children: this.inlines(inlines, base)),
      style: base,
      textAlign: style.align,
    );
  }

  List<InlineSpan> inlines(List<RichInline> inlines, TextStyle base) => [
    for (final inline in inlines)
      switch (inline) {
        RichTextRun(:final text, :final marks, :final href) => TextSpan(
          text: text,
          style: _runStyle(marks, base, link: href != null),
          recognizer: href == null ? null : _tap(() => view.onLink(href)),
        ),
        RichHardBreak() => const TextSpan(text: '\n'),
        // The span scales its widget by the paragraph's text scale, so the
        // pill must not scale its own text again.
        RichMention(:final username, :final label) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MediaQuery.withNoTextScaling(
            child: MentionPill(username: username, label: label, style: base),
          ),
        ),
        RichTaskLink(:final taskId, :final href) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MediaQuery.withNoTextScaling(
            child: TaskLinkPill(
              taskId: taskId,
              href: href,
              projectId: view.projectId,
              style: base,
              onOpen: () => view.onTaskLink(taskId),
            ),
          ),
        ),
      },
  ];

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    recognizers.add(recognizer);
    return recognizer;
  }

  TextStyle _runStyle(
    Set<RichMark> marks,
    TextStyle base, {
    required bool link,
  }) {
    var style = base;
    if (marks.contains(RichMark.bold)) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (marks.contains(RichMark.italic)) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    final decorations = [
      ?base.decoration,
      if (link || marks.contains(RichMark.underline)) TextDecoration.underline,
      if (marks.contains(RichMark.strike)) TextDecoration.lineThrough,
    ];
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    if (marks.contains(RichMark.code)) {
      style = style
          .merge(AppTheme.monospace)
          .copyWith(backgroundColor: colors.surfaceContainerHighest);
    }
    final script = marks.contains(RichMark.superscript)
        ? const FontFeature.superscripts()
        : marks.contains(RichMark.subscript)
        ? const FontFeature.subscripts()
        : null;
    if (script != null) {
      style = style.copyWith(
        fontSize: (style.fontSize ?? 14) * 0.75,
        fontFeatures: [script],
      );
    }
    if (link) {
      style = style.copyWith(
        color: colors.primary,
        decorationColor: colors.primary,
      );
    }
    return style;
  }

  Widget list(
    List<List<RichBlock>> items, {
    required List<String> markers,
    required _BlockStyle style,
    required int listDepth,
    required bool announceMarkers,
  }) => column([
    for (var i = 0; i < items.length; i++)
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 20),
            child: announceMarkers
                ? Text(markers[i], style: style.text, textAlign: TextAlign.end)
                : ExcludeSemantics(
                    child: Text(
                      markers[i],
                      style: style.text,
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: column(blocks(items[i], style, listDepth: listDepth + 1)),
          ),
        ],
      ),
  ]);

  /// The item's own text and its checkbox are one node with the checked
  /// state, and its tap when it can be toggled; a nested list inside
  /// follows on its own. When the text holds something else to tap, the
  /// checkbox is a node of its own, named by the text, so the two taps stay
  /// apart.
  Widget taskItem(RichTaskItem item, _BlockStyle style, int listDepth) {
    final own = item.blocks.where((block) => !_isList(block)).toList();
    final nested = item.blocks.where(_isList).toList();
    final itemStyle = style.copyWith(struck: item.checked || style.struck);
    final lineHeight = textScaler.scale(
      (style.text.fontSize ?? 14) * (style.text.height ?? 1.4),
    );
    final icon = Icon(
      item.checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: 18,
      color: item.checked ? colors.primary : colors.onSurfaceVariant,
    );
    final text = column(blocks(own, itemStyle, listDepth: listDepth + 1));
    final onToggle = view.onToggleTaskItem;
    final Widget row;
    if (onToggle == null || item.sourceOffset == null) {
      row = MergeSemantics(
        child: Semantics(
          checked: item.checked,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: lineHeight,
                child: ExcludeSemantics(child: icon),
              ),
              const SizedBox(width: 6),
              Expanded(child: text),
            ],
          ),
        ),
      );
    } else {
      void toggle() => onToggle(item);
      final checkbox = SizedBox.square(
        dimension: _checkboxTapTarget,
        child: ExcludeSemantics(
          child: InkResponse(
            onTap: toggle,
            radius: _checkboxTapTarget / 2,
            child: Center(child: icon),
          ),
        ),
      );
      final textBeside = Padding(
        padding: EdgeInsets.only(
          top: math.max(0, (_checkboxTapTarget - lineHeight) / 2),
        ),
        child: text,
      );
      row = _hasTapTargets(own)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  checked: item.checked,
                  label: checklistItemText(item),
                  onTap: toggle,
                  child: checkbox,
                ),
                Expanded(child: textBeside),
              ],
            )
          : MergeSemantics(
              child: Semantics(
                checked: item.checked,
                onTap: toggle,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    checkbox,
                    Expanded(child: textBeside),
                  ],
                ),
              ),
            );
    }
    return column([
      row,
      if (nested.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 26),
          child: column(blocks(nested, style, listDepth: listDepth + 1)),
        ),
    ]);
  }

  /// Links, task pills and images take taps of their own.
  static bool _hasTapTargets(List<RichBlock> blocks) => blocks.any(
    (block) => switch (block) {
      RichParagraph(:final inlines) ||
      RichHeading(:final inlines) => inlines.any(
        (inline) => switch (inline) {
          RichTextRun(:final href) => href != null,
          RichTaskLink() => true,
          RichHardBreak() || RichMention() => false,
        },
      ),
      RichBlockquote(:final blocks) => _hasTapTargets(blocks),
      RichTable(:final rows) => rows.any(
        (row) => row.cells.any((cell) => _hasTapTargets(cell.blocks)),
      ),
      RichBulletList(:final items) || RichOrderedList(:final items) =>
        items.any((item) => _hasTapTargets(item.blocks)),
      RichTaskList(:final items) => items.any(
        (item) => _hasTapTargets(item.blocks),
      ),
      RichImage() => true,
      RichCodeBlock() || RichHorizontalRule() => false,
    },
  );

  static bool _isList(RichBlock block) =>
      block is RichBulletList ||
      block is RichOrderedList ||
      block is RichTaskList;

  Widget quote(
    List<RichBlock> blocks,
    int? commentId,
    _BlockStyle style,
    int listDepth,
  ) {
    final author = commentId == null
        ? null
        : view.replyAuthorOf?.call(commentId);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: colors.outlineVariant, width: 3),
        ),
      ),
      child: column([
        if (author != null)
          Row(
            children: [
              UserAvatar(user: author, radius: 10),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.richTextReplyTo(author.displayName),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ...this.blocks(
          blocks,
          style.copyWith(
            text: style.text.copyWith(color: colors.onSurfaceVariant),
          ),
          listDepth: listDepth,
        ),
      ]),
    );
  }

  Widget codeBlock(String text, _BlockStyle style) {
    final code = Text(
      text,
      style: style.text.merge(AppTheme.monospace),
      softWrap: style.inTable,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: style.inTable
          ? Padding(padding: const EdgeInsets.all(12), child: code)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: code,
            ),
    );
  }

  Widget table(RichTable table, _BlockStyle style) {
    final grid = _tableGrid(table.rows);
    if (grid == null) return flatTable(table, style);
    final columns = grid.fold(0, (widest, row) => math.max(widest, row.length));
    if (columns == 0) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: colors.outlineVariant),
        defaultColumnWidth: const MinColumnWidth(
          IntrinsicColumnWidth(),
          FixedColumnWidth(280),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
        children: [
          for (final row in grid)
            TableRow(
              children: [
                for (var column = 0; column < columns; column++)
                  switch (column < row.length ? row[column] : null) {
                    (:final cell, origin: true) => _tableCell(
                      cell,
                      _cellBackground(cell),
                      style,
                    ),
                    (:final cell, origin: false) => ColoredBox(
                      color: _cellBackground(cell) ?? Colors.transparent,
                    ),
                    null => const SizedBox.shrink(),
                  },
              ],
            ),
        ],
      ),
    );
  }

  /// Where each cell sits on the grid HTML lays out: Flutter's table has
  /// no spans, so the columns a cell spans and the slots its row span
  /// covers in the rows below repeat it (its colour, not its content),
  /// and the cells of those rows move past them. Null for a grid too large
  /// to draw as a table.
  static List<List<_GridSlot?>>? _tableGrid(List<RichTableRow> rows) {
    final grid = <List<_GridSlot?>>[];
    var spanning = <int, ({RichTableCell cell, int rowsLeft})>{};
    var columns = 0;
    for (final row in rows) {
      final slots = <_GridSlot?>[];
      final below = <int, ({RichTableCell cell, int rowsLeft})>{};
      void cover(int column) {
        final span = spanning[column]!;
        while (slots.length < column) {
          slots.add(null);
        }
        slots.add((cell: span.cell, origin: false));
        if (span.rowsLeft > 1) {
          below[column] = (cell: span.cell, rowsLeft: span.rowsLeft - 1);
        }
      }

      for (final cell in row.cells) {
        while (spanning.containsKey(slots.length)) {
          cover(slots.length);
        }
        final start = slots.length;
        final span = math.max(1, cell.colspan);
        if (start + span > _maxTableColumns) return null;
        for (var i = 0; i < span; i++) {
          slots.add((cell: cell, origin: i == 0));
          if (cell.rowspan > 1) {
            below[start + i] = (cell: cell, rowsLeft: cell.rowspan - 1);
          }
        }
      }
      for (final column in spanning.keys.toList()..sort()) {
        if (column >= slots.length) cover(column);
      }
      spanning = below;
      columns = math.max(columns, slots.length);
      if (columns * rows.length > _maxTableSlots) return null;
      grid.add(slots);
    }
    return grid;
  }

  Color? _cellBackground(RichTableCell cell) {
    if (cell.backgroundColor case final argb?) return Color(argb);
    return cell.header ? colors.surfaceContainerHigh : null;
  }

  Widget _tableCell(RichTableCell cell, Color? background, _BlockStyle style) {
    var text = style.text;
    if (cell.header) text = text.copyWith(fontWeight: FontWeight.bold);
    if (cell.backgroundColor != null && background != null) {
      text = text.copyWith(color: contrastingTextColor(background));
    }
    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: column(
        blocks(
          cell.blocks,
          style.copyWith(
            text: text,
            inTable: true,
            align: switch (cell.align) {
              RichAlign.left => TextAlign.start,
              RichAlign.center => TextAlign.center,
              RichAlign.right => TextAlign.end,
              null => null,
            },
          ),
        ),
      ),
    );
    return background == null
        ? content
        : ColoredBox(color: background, child: content);
  }

  /// A table inside a table cell (the outer one already scrolls), or one
  /// too large for a grid, row by row.
  Widget flatTable(RichTable table, _BlockStyle style) => column([
    for (final row in table.rows)
      column([
        for (final cell in row.cells)
          column(
            blocks(
              cell.blocks,
              cell.header
                  ? style.copyWith(
                      text: style.text.copyWith(fontWeight: FontWeight.bold),
                    )
                  : style,
            ),
          ),
      ]),
  ]);

  Widget image(RichImage image, _BlockStyle style) {
    final description = image.alt.isNotEmpty ? image.alt : image.title;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: switch (image.source) {
        RichAttachmentImage(:final attachment) => InlineAttachmentImage(
          attachment: attachment,
          description: description,
        ),
        RichExternalImage(:final url) => ExternalImagePlaceholder(
          url: url,
          onOpen: () => view.onLink(url.toString()),
        ),
      },
    );
  }
}

/// A cell where it starts (`origin`), or a slot its span covers.
typedef _GridSlot = ({RichTableCell cell, bool origin});
