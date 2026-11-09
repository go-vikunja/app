/// Orders titles by their letters, ignoring case and accents, as the web's
/// `localeCompare` lists them: "Übersicht" among the U's, not after "z".
/// Titles differing only in accents keep a fixed order; titles differing
/// only in case compare equal, for the caller's own tie-break.
int compareTitles(String a, String b) {
  final lowerA = a.toLowerCase();
  final lowerB = b.toLowerCase();
  final byLetters = foldAccents(lowerA).compareTo(foldAccents(lowerB));
  return byLetters != 0 ? byLetters : lowerA.compareTo(lowerB);
}

/// [lower], already lower-cased, without the accents of its Latin letters
/// and with æ, œ, ß and þ written out: "ärger" becomes "arger". A
/// decomposed accent, a combining mark, is dropped.
String foldAccents(String lower) {
  // The search folds whole descriptions, mostly plain ASCII.
  if (_isAscii(lower)) return lower;
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    if (_isCombiningMark(rune)) continue;
    final base = _baseOf[rune];
    if (base != null) {
      buffer.write(base);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

// No collation in the SDK, and no dependency for one: the Latin letters
// with diacritics that titles in the app's languages and their neighbours
// use.
const _foldedLetters = {
  'a': 'àáâãäåāăą',
  'ae': 'æ',
  'c': 'çćĉċč',
  'd': 'ðďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'oe': 'œ',
  'r': 'ŕŗř',
  's': 'śŝşšș',
  'ss': 'ß',
  't': 'ţťŧț',
  'th': 'þ',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final Map<int, String> _baseOf = {
  for (final MapEntry(key: base, value: letters) in _foldedLetters.entries)
    for (final rune in letters.runes) rune: base,
};

bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

bool _isAscii(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) >= 0x80) return false;
  }
  return true;
}
