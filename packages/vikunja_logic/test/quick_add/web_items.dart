/// The parser's reading of items before step 40q, the web's
/// `getItemsFromPrefix` by splitting, which `quickAddTokens` must give the
/// same items as.
List<String> webItemsFromPrefix(String text, String prefix) {
  final parts = text.split(' $prefix');
  final items = <String>{};
  for (var part in text.startsWith(prefix) ? parts : parts.skip(1)) {
    if (part.startsWith(prefix)) part = part.substring(prefix.length);
    final item = part.startsWith("'")
        ? part.split("'")[1]
        : part.startsWith('"')
        ? part.split('"')[1]
        : part.split(' ').first;
    if (item.isNotEmpty) items.add(item);
  }
  return items.toList();
}
