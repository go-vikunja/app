import 'package:meta/meta.dart';

@immutable
final class ChecklistStatistics {
  const new({this.total = 0, this.checked = 0});

  final int total;
  final int checked;

  bool get isEmpty => total == 0;
  bool get allDone => total > 0 && checked == total;

  @override
  bool operator ==(Object other) =>
      other is ChecklistStatistics &&
      other.total == total &&
      other.checked == checked;

  @override
  int get hashCode => Object.hash(total, checked);

  @override
  String toString() => 'ChecklistStatistics($checked of $total)';
}

/// The web's `checklistFromText`: every `data-checked="true|false"` in the
/// description HTML counts, nested lists included, but only as an attribute
/// inside a tag: the web also counts text that reads like one, such as a
/// code block quoting HTML.
ChecklistStatistics checklistStatistics(String html) {
  final checkboxes = _checkboxes(html);
  return ChecklistStatistics(
    total: checkboxes.length,
    checked: checkboxes.where((checkbox) => checkbox.checked).length,
  );
}

/// The start offsets of those matches, ascending.
List<int> findCheckboxesInText(String html) => List.unmodifiable([
  for (final checkbox in _checkboxes(html)) checkbox.offset,
]);

const _attribute = 'data-checked="';

/// One pass that knows whether it is inside a start tag and inside a quoted
/// value, so a long tag or many of them cost no backtracking.
List<({int offset, bool checked})> _checkboxes(String html) {
  final found = <({int offset, bool checked})>[];
  var inTag = false;
  int? quote;
  for (var i = 0; i < html.length; i++) {
    final unit = html.codeUnitAt(i);
    if (quote != null) {
      if (unit == quote) quote = null;
      continue;
    }
    if (!inTag) {
      inTag =
          unit == _lt &&
          i + 1 < html.length &&
          _isLetter(html.codeUnitAt(i + 1));
      continue;
    }
    if (unit == _gt) {
      inTag = false;
    } else if (unit == _doubleQuote || unit == _singleQuote) {
      quote = unit;
    } else if (unit == _d &&
        _isSpace(html.codeUnitAt(i - 1)) &&
        html.startsWith(_attribute, i)) {
      final value = i + _attribute.length;
      for (final (text, checked) in const [
        ('true"', true),
        ('false"', false),
      ]) {
        if (html.startsWith(text, value)) {
          found.add((offset: i, checked: checked));
          i = value + text.length - 1;
          break;
        }
      }
    }
  }
  return found;
}

const _lt = 0x3c;
const _gt = 0x3e;
const _doubleQuote = 0x22;
const _singleQuote = 0x27;
const _d = 0x64;

bool _isLetter(int unit) =>
    (unit >= 0x41 && unit <= 0x5a) || (unit >= 0x61 && unit <= 0x7a);

bool _isSpace(int unit) =>
    unit == 0x20 ||
    unit == 0x09 ||
    unit == 0x0a ||
    unit == 0x0c ||
    unit == 0x0d;
