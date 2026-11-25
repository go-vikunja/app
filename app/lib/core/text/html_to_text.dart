import 'dart:math';

const _tab = 0x09;
const _lineFeed = 0x0A;
const _space = 0x20;
const _hash = 0x23;
const _semicolon = 0x3B;
const _slash = 0x2F;
const _greaterThan = 0x3E;
const _lowerX = 0x78;

const _blockEnds = [
  '</p',
  '</div',
  '</h1',
  '</h2',
  '</h3',
  '</h4',
  '</h5',
  '</h6',
  '</li',
  '</tr',
  '</blockquote',
  '</pre',
  '</ul',
  '</ol',
  '</table',
];

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// A readable plain-text version of a TipTap description: block ends become
/// line breaks, list items get a bullet or checkbox, tags are dropped and
/// the common entities are decoded.
String htmlToPlainText(String html) {
  // Server HTML is hostile, so every pass is linear in its input: a search
  // that starts again from every position takes minutes on a long run of
  // '<' (decision log: Descriptions, comments, attachments). Each pass reads
  // the whole output of the one before; merging passes would change the
  // text of malformed HTML.
  var text = _rewrite(html, '<', _lineBreak);
  text = _rewrite(text, '<', _blockEndsBeforeListItemEnd);
  text = _rewrite(text, '<', _listItem);
  text = _rewrite(text, '<', _mention);
  text = _rewrite(text, '<', _blockEnd);
  text = _rewrite(text, '<', _tag);
  text = _rewrite(text, '&', _entity);
  return _tidyLineEnds(text).trim();
}

// A null replacement is no match at the step's start, and then no match can
// start before end either.
typedef _Step = ({int end, String? replacement});

String _rewrite(
  String text,
  String trigger,
  _Step Function(String text, int at) step,
) {
  StringBuffer? out;
  var copied = 0;
  var at = text.indexOf(trigger);
  while (at >= 0) {
    final (:end, :replacement) = step(text, at);
    if (replacement != null) {
      (out ??= StringBuffer())
        ..write(text.substring(copied, at))
        ..write(replacement);
      copied = end;
    }
    at = text.indexOf(trigger, end);
  }
  if (out == null) return text;
  out.write(text.substring(copied));
  return out.toString();
}

_Step _noMatch(int next) => (end: next, replacement: null);

// <br\s*/?>
_Step _lineBreak(String text, int at) {
  if (!_hasAt(text, at + 1, 'br')) return _noMatch(at + 1);
  var i = _skipSpaces(text, at + 3);
  if (_codeAt(text, i) == _slash) i++;
  if (_codeAt(text, i) != _greaterThan) return _noMatch(at + 1);
  return (end: i + 1, replacement: '\n');
}

// TipTap wraps list item text in <p> (and task items in <div>), which must
// not add a blank line after every item: (</(p|div)\s*>\s*)+(?=</li\s*>)
_Step _blockEndsBeforeListItemEnd(String text, int at) {
  var end = at;
  while (true) {
    var tagEnd = _closingTagEnd(text, end, '</p');
    if (tagEnd < 0) tagEnd = _closingTagEnd(text, end, '</div');
    if (tagEnd < 0) break;
    end = _skipSpaces(text, tagEnd);
  }
  if (end == at) return _noMatch(at + 1);
  // A later start inside the run ends where this one does.
  if (_closingTagEnd(text, end, '</li') < 0) return _noMatch(end);
  return (end: end, replacement: '');
}

// <li\b[^>]*data-checked="(true|false)"[^>]*> and then <li\b[^>]*>
_Step _listItem(String text, int at) {
  if (!_hasAt(text, at + 1, 'li') || _isWordChar(_codeAt(text, at + 3))) {
    return _noMatch(at + 1);
  }
  final close = text.indexOf('>', at + 3);
  if (close < 0) return _noMatch(text.length);
  return (end: close + 1, replacement: _listItemMarker(text, at + 3, close));
}

// The last data-checked wins, as the greedy [^>]* gave it.
String _listItemMarker(String text, int from, int to) {
  const attribute = 'data-checked="';
  for (var p = to - 1; p >= from; p--) {
    if (!_hasAt(text, p, attribute)) continue;
    final value = p + attribute.length;
    if (_hasAt(text, value, 'true"')) {
      return text.startsWith('true', value) ? '☑ ' : '☐ ';
    }
    if (_hasAt(text, value, 'false"')) return '☐ ';
  }
  return '• ';
}

// A mention carries its name only in attributes; the element is empty:
// <mention-user\b[^>]*>[^<]*</mention-user\s*>
_Step _mention(String text, int at) {
  if (!_hasAt(text, at + 1, 'mention-user') ||
      _isWordChar(_codeAt(text, at + 13))) {
    return _noMatch(at + 1);
  }
  final open = text.indexOf('>', at + 13);
  if (open < 0) return _noMatch(text.length);
  final close = text.indexOf('<', open + 1);
  if (close < 0) return _noMatch(text.length);
  final end = _closingTagEnd(text, close, '</mention-user');
  // A later start before [close] reaches the same [close] and fails the same.
  if (end < 0) return _noMatch(close);
  return (end: end, replacement: '@${_mentionName(text.substring(at, end))}');
}

String _mentionName(String element) =>
    _quotedValue(element, 'data-label="') ??
    _quotedValue(element, 'data-id="') ??
    '';

String? _quotedValue(String element, String prefix) {
  for (var p = 0; p + prefix.length <= element.length; p++) {
    if (!_hasAt(element, p, prefix)) continue;
    final start = p + prefix.length;
    final end = element.indexOf('"', start);
    // A later prefix would end in the '"' this search did not find.
    return end < 0 ? null : element.substring(start, end);
  }
  return null;
}

// </(p|div|h[1-6]|li|tr|blockquote|pre|ul|ol|table)\s*>
_Step _blockEnd(String text, int at) {
  for (final name in _blockEnds) {
    final end = _closingTagEnd(text, at, name);
    if (end >= 0) return (end: end, replacement: '\n');
  }
  return _noMatch(at + 1);
}

// <[^>]+>
_Step _tag(String text, int at) {
  if (_codeAt(text, at + 1) == _greaterThan) return _noMatch(at + 1);
  final close = text.indexOf('>', at + 1);
  if (close < 0) return _noMatch(text.length);
  return (end: close + 1, replacement: '');
}

// &(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);
_Step _entity(String text, int at) {
  final nameStart = at + 1;
  final int valueStart;
  final bool Function(int) isNameChar;
  if (_codeAt(text, nameStart) != _hash) {
    valueStart = nameStart;
    isNameChar = _isAsciiLetter;
  } else if (_codeAt(text, nameStart + 1) == _lowerX) {
    valueStart = nameStart + 2;
    isNameChar = _isHexDigit;
  } else {
    valueStart = nameStart + 1;
    isNameChar = _isDigit;
  }
  var nameEnd = valueStart;
  while (nameEnd < text.length && isNameChar(text.codeUnitAt(nameEnd))) {
    nameEnd++;
  }
  if (nameEnd == valueStart || _codeAt(text, nameEnd) != _semicolon) {
    return _noMatch(at + 1);
  }
  return (
    end: nameEnd + 1,
    replacement: _decodeEntity(text.substring(nameStart, nameEnd)),
  );
}

String _decodeEntity(String name) {
  if (name.startsWith('#x') || name.startsWith('#X')) {
    return _fromCodePoint(
      int.tryParse(name.substring(2), radix: 16),
      '&$name;',
    );
  }
  if (name.startsWith('#')) {
    return _fromCodePoint(int.tryParse(name.substring(1)), '&$name;');
  }
  return _namedEntities[name.toLowerCase()] ?? '&$name;';
}

String _fromCodePoint(int? codePoint, String original) {
  if (codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF) {
    return original;
  }
  // Half a surrogate pair is no character: package:html reads it as U+FFFD,
  // and Flutter, given it, draws the whole text as that one mark.
  if (codePoint >= 0xD800 && codePoint <= 0xDFFF) return '\uFFFD';
  return String.fromCharCode(codePoint);
}

// [ \t]+\n becomes \n, then \n{3,} becomes \n\n.
String _tidyLineEnds(String text) {
  StringBuffer? out;
  var copied = 0;
  var i = 0;
  while (i < text.length) {
    if (!_isLineSpace(text.codeUnitAt(i))) {
      i++;
      continue;
    }
    final start = i;
    var lineFeeds = 0;
    var lastLineFeed = -1;
    while (i < text.length && _isLineSpace(text.codeUnitAt(i))) {
      if (text.codeUnitAt(i) == _lineFeed) {
        lineFeeds++;
        lastLineFeed = i;
      }
      i++;
    }
    final kept = min(lineFeeds, 2);
    if (lineFeeds == 0 || lastLineFeed + 1 - start == kept) continue;
    (out ??= StringBuffer())
      ..write(text.substring(copied, start))
      ..write('\n' * kept);
    copied = lastLineFeed + 1;
  }
  if (out == null) return text;
  out.write(text.substring(copied));
  return out.toString();
}

/// The end of `[name]\s*>` at [at], or -1; [name] in lower case.
int _closingTagEnd(String text, int at, String name) {
  if (!_hasAt(text, at, name)) return -1;
  final i = _skipSpaces(text, at + name.length);
  return _codeAt(text, i) == _greaterThan ? i + 1 : -1;
}

/// Whether [text] holds [lower] at [at], ignoring the case of ASCII letters
/// only; [lower] is in lower case.
bool _hasAt(String text, int at, String lower) {
  if (at + lower.length > text.length) return false;
  for (var k = 0; k < lower.length; k++) {
    var c = text.codeUnitAt(at + k);
    if (c >= 0x41 && c <= 0x5A) c |= 0x20;
    if (c != lower.codeUnitAt(k)) return false;
  }
  return true;
}

int _codeAt(String text, int at) => at < text.length ? text.codeUnitAt(at) : -1;

int _skipSpaces(String text, int from) {
  var i = from;
  while (i < text.length && _isSpace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

// RegExp's \s; String.trim also takes U+0085.
bool _isSpace(int c) =>
    (c >= 0x09 && c <= 0x0D) ||
    c == 0x20 ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;

bool _isLineSpace(int c) => c == _space || c == _tab || c == _lineFeed;

bool _isWordChar(int c) => _isAsciiLetter(c) || _isDigit(c) || c == 0x5F;

bool _isAsciiLetter(int c) => (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isHexDigit(int c) =>
    _isDigit(c) || ((c | 0x20) >= 0x61 && (c | 0x20) <= 0x66);

/// [text] as the web's editor stores it: one paragraph per line, the
/// characters HTML gives a meaning escaped; empty for blank text.
String plainTextToHtml(String text) {
  if (text.trim().isEmpty) return '';
  return [
    for (final line in text.split('\n'))
      '<p>${line.replaceAllMapped(_htmlSpecial, (m) => _escapes[m[0]]!)}</p>',
  ].join();
}

final _htmlSpecial = RegExp('[&<>"]');

const _escapes = {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'};
