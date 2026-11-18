import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/write/write_transport.dart';

final _log = Logger('VikunjaApi');

/// The most pages one read of a whole list takes: 10,000 items at the
/// server's default page size of 50. A list that goes on past it is cut
/// there with a warning in the log.
const maxListPages = 200;

/// Every page of a page-numbered list, by one rule: ids seen on an earlier
/// page are skipped, and the read ends at the page count the server
/// reports or at a page without a new id (2.7.0 answers a page past the
/// end with the last one; pseudo projects repeat on every page). With
/// [pastTotalWhenFull] a page of that many items at the reported end is
/// followed by one more, for lists whose total undercounts (teams with
/// `include_public`). [what] names the list in the log.
Future<List<T>> collectAllPages<T>(
  Future<({List<T> items, int totalPages})> Function(int page) fetch, {
  required Object Function(T item) idOf,
  required String what,
  int? pastTotalWhenFull,
}) async {
  final byId = <Object, T>{};
  for (var page = 1; page <= maxListPages; page++) {
    final (:items, :totalPages) = await fetch(page);
    var added = 0;
    for (final item in items) {
      final id = idOf(item);
      if (byId.containsKey(id)) continue;
      byId[id] = item;
      added++;
    }
    final full = pastTotalWhenFull != null && items.length >= pastTotalWhenFull;
    if (added == 0 || (page >= totalPages && !full)) {
      return List.unmodifiable(byId.values);
    }
  }
  _log.warning(
    '$what: stopped after $maxListPages pages with ${byId.length} items',
  );
  return List.unmodifiable(byId.values);
}

/// [collectAllPages] of [path]: v2 in an envelope, v1 as an array with
/// paging headers, or without them as one page. With [pastTotal] a full
/// last page is followed by one more.
Future<List<T>> readAllPages<T>(
  WriteTransport transport,
  String path,
  T Function(Object?) parse, {
  required Object Function(T item) idOf,
  required int perPage,
  Map<String, String> query = const {},
  bool pastTotal = false,
}) => collectAllPages(
  (page) async {
    final response = await transport.send(
      'GET',
      path,
      query: {...query, 'page': '$page', 'per_page': '$perPage'},
    );
    return transport.decode<({List<T> items, int totalPages})>(
      response,
      (json) => _pageOf(json, response.headers, page, parse),
    );
  },
  idOf: idOf,
  what: path,
  pastTotalWhenFull: pastTotal ? perPage : null,
);

({List<T> items, int totalPages}) _pageOf<T>(
  Object? json,
  Headers headers,
  int page,
  T Function(Object?) parse,
) => switch (json) {
  {'items': final List<Object?>? items, 'total_pages': final int pages} => (
    items: [...?items?.map(parse)],
    totalPages: pages,
  ),
  final List<Object?> items => (
    items: [...items.map(parse)],
    totalPages:
        int.tryParse(headers.value('x-pagination-total-pages') ?? '') ?? page,
  ),
  // v1 answers an empty list as null on a few routes.
  null => (items: <T>[], totalPages: page),
  _ => throw const MalformedJson('not a page'),
};
