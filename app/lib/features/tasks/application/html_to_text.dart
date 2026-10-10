final _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
// TipTap wraps list item text in <p> (and task items in <div>), which must
// not add a blank line after every item.
final _blockEndBeforeListItemEnd = RegExp(
  r'(</(p|div)\s*>\s*)+(?=</li\s*>)',
  caseSensitive: false,
);
final _checklistItem = RegExp(
  r'<li\b[^>]*data-checked="(true|false)"[^>]*>',
  caseSensitive: false,
);
final _listItem = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final _blockEnd = RegExp(
  r'</(p|div|h[1-6]|li|tr|blockquote|pre|ul|ol|table)\s*>',
  caseSensitive: false,
);
final _tag = RegExp('<[^>]+>');
final _entity = RegExp('&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');
final _blankLines = RegExp(r'\n{3,}');
final _trailingSpaces = RegExp(r'[ \t]+\n');

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
};

/// A readable plain-text version of a TipTap description: block ends become
/// line breaks, list items get a bullet or checkbox, tags are dropped and
/// the common entities are decoded. Rich rendering comes in step 10.
String htmlToPlainText(String html) {
  final text = html
      .replaceAll(_lineBreak, '\n')
      .replaceAll(_blockEndBeforeListItemEnd, '')
      .replaceAllMapped(
        _checklistItem,
        (match) => match.group(1) == 'true' ? '☑ ' : '☐ ',
      )
      .replaceAll(_listItem, '• ')
      .replaceAll(_blockEnd, '\n')
      .replaceAll(_tag, '')
      .replaceAllMapped(_entity, (match) => _decodeEntity(match.group(1)!));
  return text
      .replaceAll(_trailingSpaces, '\n')
      .replaceAll(_blankLines, '\n\n')
      .trim();
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

String _fromCodePoint(int? codePoint, String original) =>
    codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF
    ? original
    : String.fromCharCode(codePoint);
