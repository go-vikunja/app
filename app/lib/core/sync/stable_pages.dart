import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _log = Logger('SyncEngine');

/// Walks a page-numbered list to its end, by id. An item deleted while the
/// walk is going shifts the next page's first item into the page already
/// fetched, where a set diff would take it for removed, so a walk whose
/// server counts (`total` on v2, the page count on v1) change between two
/// pages starts over. One that keeps changing is an [UnexpectedResponse].
/// [enough] ends the walk after the page that satisfies it. Without a page
/// count (a proxy dropped v1's header) nothing is compared, and the walk
/// ends only at a page without a new id: the page size the server applied
/// is unknown then, pseudo projects repeat on every page, and a page past
/// the end may repeat the last one. Such a walk that misses one of the
/// [stored] ids is walked once more, and an id either walk returned counts
/// as listed (decision log: Sync).
Future<Map<int, T>> collectPages<T>({
  required Future<Page<T>> Function(int page) fetch,
  required int Function(T item) idOf,
  bool Function(T item)? skip,
  void Function(Map<int, T> collected, Page<T> page)? onPage,
  bool Function(Map<int, T> collected)? enough,
  Iterable<int> stored = const [],
}) async {
  Future<({Map<int, T> byId, bool counted})?> walkOnce() async {
    final byId = <int, T>{};
    (int?, int)? counts;
    var counted = true;
    for (var page = 1; ; page++) {
      final result = await fetch(page);
      if (result.totalPages case final pages?) {
        final seen = (result.total, pages);
        counts ??= seen;
        if (seen != counts) return null;
      } else {
        counted = false;
      }
      final before = byId.length;
      for (final item in result.items) {
        if (skip?.call(item) ?? false) continue;
        byId.putIfAbsent(idOf(item), () => item);
      }
      onPage?.call(byId, result);
      final more = result.totalPages == null
          ? byId.length > before
          : result.hasMore;
      if (!more || (enough?.call(byId) ?? false)) {
        return (byId: byId, counted: counted);
      }
    }
  }

  Future<({Map<int, T> byId, bool counted})> stableWalk() async {
    const walks = 3;
    for (var walk = 1; ; walk++) {
      if (await walkOnce() case final done?) return done;
      if (walk == walks) {
        throw const UnexpectedResponse(
          null,
          message: 'list changed while paging, $walks times',
        );
      }
      _log.fine('List changed while paging, walking it again');
    }
  }

  final first = await stableWalk();
  if (first.counted || stored.every(first.byId.containsKey)) return first.byId;
  _log.fine('List without a page count misses stored items, walking it again');
  final second = await stableWalk();
  return {...first.byId, ...second.byId};
}

/// After a non-empty page of a keyset walk: whether it was the last.
/// Without a page count the size the server applied is unknown too, so only
/// an empty page ends the walk (decision log: Sync).
bool endsKeysetWalk(Page<Object?> page) =>
    page.totalPages != null &&
    page.items.length < page.perPage &&
    !page.hasMore;
