/// Keeps every `IN (...)` list well below SQLite's variable limit.
const sqlChunkSize = 500;

Iterable<List<T>> chunksOf<T>(List<T> all, [int size = sqlChunkSize]) sync* {
  for (var start = 0; start < all.length; start += size) {
    yield all.sublist(start, (start + size).clamp(0, all.length));
  }
}
