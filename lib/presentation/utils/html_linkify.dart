/// Turns bare URLs (http://, https://, www.) in HTML strings into clickable
/// <a href> links, skipping URLs that are already inside a link attribute.
library;

final RegExp _bareUrlPattern = RegExp(
  r'(?<![="])((?:https?://|www\.)[^\s<>]+)',
  caseSensitive: false,
);

final RegExp _trailingJunk = RegExp(
  r'[.,;:!?…)"'
  r"']+$",
);

String linkifyHtml(String input) {
  return input.replaceAllMapped(_bareUrlPattern, (match) {
    var url = match.group(1)!;
    // Trim trailing punctuation / quotes that are not part of the URL.
    url = url.replaceAll(_trailingJunk, '');
    if (url.isEmpty) return match.group(0)!;

    final href = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    return '<a href="$href">$url</a>';
  });
}
