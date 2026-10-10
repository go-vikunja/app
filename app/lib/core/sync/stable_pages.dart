import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _log = Logger('SyncEngine');

/// Walks a page-numbered list to its end, by id. An item deleted while the
/// walk is going shifts the next page's first item into the page already
/// fetched, where a set diff would take it for removed, so a walk whose
/// server counts (`total` on v2, the page count on v1) change between two
/// pages starts over. One that keeps changing is an [UnexpectedResponse].
Future<Map<int, T>> collectPages<T>({
  required Future<Page<T>> Function(int page) fetch,
  required int Function(T item) idOf,
  bool Function(T item)? skip,
  void Function(Map<int, T> collected, Page<T> page)? onPage,
}) async {
  const walks = 3;
  for (var walk = 1; ; walk++) {
    final byId = <int, T>{};
    (int?, int)? counts;
    for (var page = 1; ; page++) {
      final result = await fetch(page);
      final seen = (result.total, result.totalPages);
      counts ??= seen;
      if (seen != counts) break;
      for (final item in result.items) {
        if (skip?.call(item) ?? false) continue;
        byId.putIfAbsent(idOf(item), () => item);
      }
      onPage?.call(byId, result);
      if (!result.hasMore) return byId;
    }
    if (walk == walks) {
      throw const UnexpectedResponse(
        null,
        message: 'list changed while paging, $walks times',
      );
    }
    _log.fine('List changed while paging, walking it again');
  }
}
