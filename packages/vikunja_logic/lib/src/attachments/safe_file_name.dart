import 'dart:convert';

/// The longest name [safeFileName] returns, in UTF-8 bytes: file systems
/// allow 255, and a download adds `.part` while it runs.
const int maxSafeFileNameBytes = 200;

// Kept apart from the stem only while this short, so a name whose only dot
// is far back is cut like one without an extension.
const _maxExtensionBytes = 32;

final _controlAndBidi = RegExp(
  '[\u0000-\u001f\u007f-\u009f\u200e\u200f\u202a-\u202e\u2066-\u2069]',
);
final _separators = RegExp(r'[/\\]');
// A multipart part sends `"` in its file name as `%22`, which the server
// keeps as it is: the name would not match what was queued.
const _doubleQuote = '"';
final _onlyDots = RegExp(r'^\.+$');

/// [name] made usable as a single path segment, e.g. for a file named
/// after an attachment or a shared file: control and bidirectional
/// formatting characters removed, `/` and `\` replaced by `_` and `"` by
/// `'`, surrounding whitespace trimmed, and cut to [maxSafeFileNameBytes]
/// keeping the extension. A name that is empty or only dots afterwards
/// (`.`, `..`) becomes [fallback].
String safeFileName(String name, {String fallback = 'file'}) {
  final cleaned = name
      .replaceAll(_controlAndBidi, '')
      .replaceAll(_separators, '_')
      .replaceAll(_doubleQuote, "'")
      .trim();
  final cut = _cut(cleaned).trim();
  return cut.isEmpty || _onlyDots.hasMatch(cut) ? fallback : cut;
}

String _cut(String name) {
  if (utf8.encode(name).length <= maxSafeFileNameBytes) return name;
  final dot = name.lastIndexOf('.');
  final extension = dot > 0 ? name.substring(dot) : '';
  final extensionBytes = utf8.encode(extension).length;
  final keptExtension = extensionBytes <= _maxExtensionBytes ? extension : '';
  final stem = keptExtension.isEmpty ? name : name.substring(0, dot);
  var budget = maxSafeFileNameBytes - utf8.encode(keptExtension).length;
  final kept = StringBuffer();
  for (final rune in stem.runes) {
    final char = String.fromCharCode(rune);
    budget -= utf8.encode(char).length;
    if (budget < 0) break;
    kept.write(char);
  }
  return '${kept.toString().trimRight()}$keptExtension';
}
