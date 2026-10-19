/// The largest integer a JavaScript number holds exactly.
const maxSafeInteger = 9007199254740991;

/// What the WHATWG URL parser does to its input before parsing: leading
/// and trailing C0 controls and spaces go, tabs and newlines anywhere too.
String cleanUrlText(String text) {
  var start = 0;
  while (start < text.length && text.codeUnitAt(start) <= 0x20) {
    start++;
  }
  if (start == text.length) return '';
  var end = text.length;
  while (text.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  return text.substring(start, end).replaceAll(_tabsAndNewlines, '');
}

final _tabsAndNewlines = RegExp(r'[\t\n\r]');
