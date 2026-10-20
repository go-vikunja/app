import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/text/rich_text.dart';

const _attributePrefix = 'data-checked="';
const _tipTapCheckbox = '<label><input type="checkbox"';
const _checkedInput = ' checked="checked"';
const _checkboxRest = '><span></span></label>';

/// [html] with [item]'s checkbox set to [checked], every other byte kept;
/// null when [item] cannot be toggled in [html]: it has no source offset,
/// or [html] is not the text it was parsed from (no task item with the
/// item's state has its `data-checked` at that offset).
///
/// Only the attribute's value changes, so later offsets move by one. In
/// the exact shape TipTap writes (`<label><input type="checkbox">` right
/// after the item's start tag) the input's `checked="checked"` follows, so
/// the result equals what the web would store; readers ignore that input.
String? toggleTaskItem(
  String html,
  RichTaskItem item, {
  required bool checked,
}) {
  final offset = item.sourceOffset;
  if (offset == null ||
      offset < 0 ||
      offset > html.length ||
      !html.startsWith('$_attributePrefix${item.checked}"', offset)) {
    return null;
  }
  // The same text can stand in another attribute's value or in the text
  // of a different version of the HTML.
  final isItem = _itemsOf(html).any(
    (candidate) =>
        candidate.sourceOffset == offset && candidate.checked == item.checked,
  );
  return isItem
      ? _toggleAt(html, offset, item.checked, checked: checked)
      : null;
}

String _toggleAt(
  String html,
  int offset,
  bool current, {
  required bool checked,
}) {
  if (checked == current) return html;
  final valueStart = offset + _attributePrefix.length;
  final toggled = html.replaceRange(
    valueStart,
    valueStart + '$current'.length,
    '$checked',
  );
  final tagEnd = _startTagEnd(toggled, valueStart + '$checked'.length + 1);
  return tagEnd == null
      ? toggled
      : _withCheckedInput(toggled, tagEnd + 1, checked: checked);
}

/// The record of a tap on [item], one of [document]'s own items, that
/// `rebaseChecklistToggles` can apply to another version of the HTML: by
/// `data-task-id` when the item has one, else by position and text.
ChecklistToggle checklistToggleFor(
  RichDocument document,
  RichTaskItem item, {
  required bool checked,
}) {
  final ordinal = document.taskItems.indexWhere(
    (candidate) => identical(candidate, item),
  );
  if (ordinal < 0) {
    throw ArgumentError.value(item, 'item', 'is not part of the document');
  }
  if (item.taskId case final id?) {
    return ChecklistToggle.byId(id, checked: checked);
  }
  return ChecklistToggle.byPosition(
    ordinal: ordinal,
    text: checklistItemText(item),
    checked: checked,
  );
}

/// [serverHtml] with [toggles] applied in order, each to the first item
/// with its `data-task-id`, else to the item at its position when the text
/// still matches; a toggle whose item is gone, changed or cannot be
/// toggled is dropped. Every byte but the toggled values stays.
String rebaseChecklistToggles(
  String serverHtml,
  List<ChecklistToggle> toggles,
) {
  var html = serverHtml;
  for (final toggle in toggles) {
    final item = _itemFor(toggle, _itemsOf(html));
    final offset = item?.sourceOffset;
    if (item == null || offset == null) continue;
    html = _toggleAt(html, offset, item.checked, checked: toggle.checked);
  }
  return html;
}

/// [item]'s own text, as `ChecklistToggle.text` keeps it: whitespace
/// collapsed, without nested task lists and images, independent of the
/// server's link bases.
String checklistItemText(RichTaskItem item) {
  final text = StringBuffer();
  _writeBlocks(text, item.blocks);
  return text.toString().replaceAll(_whitespace, ' ').trim();
}

// Images, task links and their bases only decide how an item is shown,
// not which items there are or what their text is.
final Uri _anyRoot = Uri.parse('https://checklist.invalid');

List<RichTaskItem> _itemsOf(String html) =>
    parseRichText(html, apiRoot: _anyRoot, taskLinkBases: const []).taskItems;

final _whitespace = RegExp(r'\s+');

RichTaskItem? _itemFor(ChecklistToggle toggle, List<RichTaskItem> items) {
  if (toggle.itemId case final id?) {
    for (final item in items) {
      if (item.taskId == id) return item;
    }
    return null;
  }
  final ordinal = toggle.ordinal;
  if (ordinal == null || ordinal < 0 || ordinal >= items.length) return null;
  final item = items[ordinal];
  return checklistItemText(item) == toggle.text ? item : null;
}

bool _isTagSpace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0a ||
    codeUnit == 0x0c ||
    codeUnit == 0x0d ||
    codeUnit == 0x2f;

/// The `>` that ends the start tag whose attributes continue at [from],
/// read like the HTML tokenizer reads attributes.
int? _startTagEnd(String html, int from) {
  var i = from;
  bool isSpace(int at) => _isTagSpace(html.codeUnitAt(at));
  while (i < html.length) {
    while (i < html.length && isSpace(i)) {
      i++;
    }
    if (i >= html.length) return null;
    if (html[i] == '>') return i;
    i++;
    while (i < html.length && !isSpace(i) && html[i] != '>' && html[i] != '=') {
      i++;
    }
    while (i < html.length && isSpace(i)) {
      i++;
    }
    if (i < html.length && html[i] == '=') {
      i++;
      while (i < html.length && isSpace(i)) {
        i++;
      }
      if (i < html.length && (html[i] == '"' || html[i] == "'")) {
        final close = html.indexOf(html[i], i + 1);
        if (close < 0) return null;
        i = close + 1;
      } else {
        while (i < html.length && !isSpace(i) && html[i] != '>') {
          i++;
        }
      }
    }
  }
  return null;
}

String _withCheckedInput(String html, int at, {required bool checked}) {
  if (!html.startsWith(_tipTapCheckbox, at)) return html;
  final rest = at + _tipTapCheckbox.length;
  final hasChecked = html.startsWith('$_checkedInput$_checkboxRest', rest);
  if (!hasChecked && !html.startsWith(_checkboxRest, rest)) return html;
  if (checked == hasChecked) return html;
  return checked
      ? html.replaceRange(rest, rest, _checkedInput)
      : html.replaceRange(rest, rest + _checkedInput.length, '');
}

void _writeBlocks(StringBuffer text, List<RichBlock> blocks) {
  for (final block in blocks) {
    switch (block) {
      case RichParagraph(:final inlines) || RichHeading(:final inlines):
        _writeInlines(text, inlines);
      case RichBulletList(:final items) || RichOrderedList(:final items):
        for (final item in items) {
          _writeBlocks(text, item.blocks);
        }
      case RichBlockquote(:final blocks):
        _writeBlocks(text, blocks);
      case RichCodeBlock(text: final code):
        text.write(code);
      case RichTable(:final rows):
        for (final row in rows) {
          for (final cell in row.cells) {
            _writeBlocks(text, cell.blocks);
          }
        }
      case RichTaskList() || RichHorizontalRule() || RichImage():
        break;
    }
    text.write(' ');
  }
}

void _writeInlines(StringBuffer text, List<RichInline> inlines) {
  for (final inline in inlines) {
    text.write(switch (inline) {
      RichTextRun(text: final run) => run,
      RichHardBreak() => ' ',
      RichMention(:final username, :final label) =>
        label.isEmpty ? username : label,
      RichTaskLink(:final href) => href,
    });
  }
}
