import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/write/write_transport.dart';

const _maxPages = 20;

/// Every page of a list: v2 in an envelope, v1 as an array with paging
/// headers. Ids seen on an earlier page are skipped, and a page without a
/// new one ends the read (2.7.0 answers a page past the end with the last
/// one). With [pastTotal] a full last page is followed by one more, for
/// lists whose total undercounts (teams with `include_public`).
Future<List<T>> readAllPages<T>(
  WriteTransport transport,
  String path,
  T Function(Object?) parse, {
  required Object Function(T item) idOf,
  required int perPage,
  Map<String, String> query = const {},
  bool pastTotal = false,
}) async {
  final byId = <Object, T>{};
  for (var page = 1; page <= _maxPages; page++) {
    final response = await transport.send(
      'GET',
      path,
      query: {...query, 'page': '$page', 'per_page': '$perPage'},
    );
    final (:items, :totalPages) = transport.decode(
      response,
      (json) => _pageOf(json, response.headers, page, parse),
    );
    var added = 0;
    for (final item in items) {
      if (byId.containsKey(idOf(item))) continue;
      byId[idOf(item)] = item;
      added++;
    }
    if (added == 0) break;
    if (page < totalPages) continue;
    if (!pastTotal || items.length < perPage) break;
  }
  return List.unmodifiable(byId.values);
}

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
