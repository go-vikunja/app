import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/links/attachment_urls.dart';
import 'package:vikunja_logic/src/text/rich_text_parser.dart';

/// A task description or comment as the web editor's schema reads it
/// (TipTap 3 / ProseMirror: 20 node types, 8 marks): whatever is not part of
/// that schema is gone, so nothing in the tree can run, load or leak by
/// itself. The renderer decides what an image may load and what a tap does.
@immutable
final class RichDocument {
  const new(this.blocks);

  final List<RichBlock> blocks;

  /// No visible content: no text other than whitespace, no image, mention,
  /// task link, rule, table or task item.
  bool get isEmpty => blocks.every(_isBlank);

  /// Blocks separated by a newline, hard breaks as newlines, mentions as
  /// their label, task links as their href, images as their alt text:
  /// for semantics and tests.
  String get plainText => _lines(blocks).join('\n');
}

@immutable
sealed class RichBlock {
  const new();
}

final class RichParagraph extends RichBlock {
  const new(this.inlines);

  final List<RichInline> inlines;
}

final class RichHeading extends RichBlock {
  /// [level] is 1 to 6.
  const new(this.level, this.inlines);

  final int level;
  final List<RichInline> inlines;
}

final class RichBulletList extends RichBlock {
  const new(this.items);

  final List<RichListItem> items;
}

final class RichOrderedList extends RichBlock {
  const new(this.items, {this.start = 1});

  final List<RichListItem> items;
  final int start;
}

@immutable
final class RichListItem {
  /// Starts with a paragraph, like the schema's `paragraph block*`.
  const new(this.blocks);

  final List<RichBlock> blocks;
}

final class RichTaskList extends RichBlock {
  const new(this.items);

  final List<RichTaskItem> items;
}

@immutable
final class RichTaskItem {
  const new({required this.checked, required this.blocks, this.sourceOffset});

  /// `data-checked` is exactly `true` (or empty), as in the web.
  final bool checked;
  final List<RichBlock> blocks;

  /// The offset of this item's `data-checked` attribute in the raw HTML,
  /// as `findCheckboxesInText` reports it, so step 25 can toggle it; null
  /// when it cannot be told.
  final int? sourceOffset;
}

final class RichBlockquote extends RichBlock {
  const new(this.blocks, {this.commentId});

  final List<RichBlock> blocks;

  /// The comment a reply quotes (`data-comment-id`, a positive integer).
  final int? commentId;
}

final class RichCodeBlock extends RichBlock {
  const new(this.text, {this.language});

  /// Whitespace kept exactly.
  final String text;

  /// From `class="language-…"` on the first `code` child.
  final String? language;
}

final class RichHorizontalRule extends RichBlock {
  const new();
}

final class RichTable extends RichBlock {
  const new(this.rows);

  final List<RichTableRow> rows;
}

@immutable
final class RichTableRow {
  const new(this.cells);

  final List<RichTableCell> cells;
}

enum RichAlign { left, center, right }

@immutable
final class RichTableCell {
  const new({
    required this.blocks,
    this.header = false,
    this.colspan = 1,
    this.rowspan = 1,
    this.align,
    this.backgroundColor,
  });

  final List<RichBlock> blocks;
  final bool header;
  final int colspan;
  final int rowspan;
  final RichAlign? align;

  /// `data-background-color` of a `td`, only when it is a valid `#rgb`,
  /// `#rrggbb` or `rgb(r, g, b)` colour, as 0xAARRGGBB; the web pastes the
  /// raw value into a style attribute, which this does not copy.
  final int? backgroundColor;
}

/// Images are blocks: an `img` inside a paragraph splits it, as in the web.
final class RichImage extends RichBlock {
  const new(this.source, {this.alt = '', this.title = ''});

  final RichImageSource source;
  final String alt;
  final String title;
}

@immutable
sealed class RichImageSource {
  const new();
}

/// `data-src`, else `src`, pointing at an attachment of this server
/// (`parseAttachmentUrl`): loaded only through the authenticated client.
final class RichAttachmentImage extends RichImageSource {
  const new(this.attachment);

  final AttachmentRef attachment;
}

/// An `http`/`https` image elsewhere: the app never loads it by itself.
final class RichExternalImage extends RichImageSource {
  const new(this.url);

  final Uri url;
}

@immutable
sealed class RichInline {
  const new();
}

enum RichMark { bold, italic, underline, strike, code, subscript, superscript }

final class RichTextRun extends RichInline {
  const new(this.text, {this.marks = const {}, this.href});

  /// Spaces and tabs as written (the web shows them with `pre-wrap`).
  final String text;
  final Set<RichMark> marks;

  /// The link, when its whitespace-stripped href passes the web's
  /// `isAllowedUri` (http, https, ftp, ftps, mailto, tel, callto, sms, cid,
  /// xmpp, git, obsidian, notion, message, or relative/schemeless); a
  /// rejected link keeps only its text. Cleaned as a browser cleans a URL
  /// (surrounding spaces and controls, tabs and newlines removed) but not
  /// resolved: the renderer resolves relative hrefs against the server and
  /// gates what it opens. A link inside `code` is dropped, as in the web.
  final String? href;
}

final class RichHardBreak extends RichInline {
  const new();
}

/// `<mention-user data-id data-label>`: shown as the label, else the id,
/// without `@`; inner text is ignored. Either may be empty, not both.
final class RichMention extends RichInline {
  const new({required this.username, required this.label});

  final String username;
  final String label;
}

/// An anchor the web upgrades to a task pill: `parseTaskIdFromUrl` accepts
/// the href, its trimmed text equals the href, it has no child elements and
/// no attributes but `href`, `target` and `rel`.
final class RichTaskLink extends RichInline {
  const new({required this.taskId, required this.href});

  final int taskId;
  final String href;
}

/// Parses untrusted HTML (or legacy plain text) the way the web editor
/// does (TipTap 3.31.3 on ProseMirror with `preserveWhitespace: true`,
/// pinned by `test/fixtures/sanitizer_oracle.json`):
/// - the HTML5 parser of `package:html` on `<body>…</body>`; text nodes
///   that are exactly `\n` or `\n` plus two whitespace characters are
///   dropped first;
/// - an element outside the schema is replaced by its children; the
///   content of `head`, `noscript`, `object`, `script`, `style`, `title`,
///   `iframe`, `template`, `svg`, `math`, `embed`, `video`, `audio`,
///   `canvas` and form controls is dropped (the web keeps the text of
///   `math` and of buttons, text areas and options); comments vanish;
///   entities decode to text;
/// - `\n`, `\r\n` and `\r` inside text are hard breaks; other whitespace is
///   kept; whitespace-only text between blocks is dropped;
/// - block elements end the current paragraph, and content that does not
///   fit where it stands is wrapped or moved out the way ProseMirror does
///   it (text directly in a list item, cell or quote gets a paragraph, a
///   list item starts with one, a stray `li` gets a list);
/// - marks from tags and from `style` (`font-weight`, `font-style`,
///   `text-decoration`, `vertical-align`), as the schema's parse rules;
/// - `img` without a source, with a `data:` one, or with one that is
///   neither an attachment of this server nor an absolute http(s) URL is
///   dropped (the web shows the last kind as a broken image);
/// - markup nested deeper than 96 elements is reduced to its text.
///
/// Unlike the web: no link is created for a bare URL (the web's autolink
/// runs once on load), and no empty paragraph is appended after a last
/// block that is not a paragraph.
///
/// [apiRoot] is the account's server root for attachment images;
/// [taskLinkBases] are the server root and `/info`'s `frontend_url`.
RichDocument parseRichText(
  String html, {
  required Uri apiRoot,
  required List<Uri> taskLinkBases,
}) => buildRichDocument(html, apiRoot: apiRoot, taskLinkBases: taskLinkBases);

/// The web's exact test (`editorContentEmpty.ts`): `''` or `'<p></p>'`.
bool isRichTextEmpty(String html) => html.isEmpty || html == '<p></p>';

bool _isBlank(RichBlock block) => switch (block) {
  RichParagraph(:final inlines) || RichHeading(:final inlines) => inlines.every(
    (inline) => switch (inline) {
      RichTextRun(:final text) => text.trim().isEmpty,
      RichHardBreak() => true,
      RichMention() || RichTaskLink() => false,
    },
  ),
  RichBulletList(:final items) || RichOrderedList(:final items) => items.every(
    (item) => item.blocks.every(_isBlank),
  ),
  RichBlockquote(:final blocks) => blocks.every(_isBlank),
  RichCodeBlock(:final text) => text.trim().isEmpty,
  RichTaskList(:final items) => items.isEmpty,
  RichHorizontalRule() || RichTable() || RichImage() => false,
};

List<String> _lines(List<RichBlock> blocks) => [
  for (final block in blocks)
    ...switch (block) {
      RichParagraph(:final inlines) ||
      RichHeading(:final inlines) => [_inlineText(inlines)],
      RichBulletList(:final items) || RichOrderedList(:final items) => [
        for (final item in items) ..._lines(item.blocks),
      ],
      RichTaskList(:final items) => [
        for (final item in items) ..._lines(item.blocks),
      ],
      RichBlockquote(:final blocks) => _lines(blocks),
      RichCodeBlock(:final text) => [text],
      RichHorizontalRule() => const <String>[],
      RichTable(:final rows) => [
        for (final row in rows)
          for (final cell in row.cells) ..._lines(cell.blocks),
      ],
      RichImage(:final alt) => [if (alt.isNotEmpty) alt],
    },
];

String _inlineText(List<RichInline> inlines) => inlines
    .map(
      (inline) => switch (inline) {
        RichTextRun(:final text) => text,
        RichHardBreak() => '\n',
        RichMention(:final username, :final label) =>
          label.isEmpty ? username : label,
        RichTaskLink(:final href) => href,
      },
    )
    .join();
