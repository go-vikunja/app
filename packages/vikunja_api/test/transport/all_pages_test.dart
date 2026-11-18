import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/src/transport/all_pages.dart';

void main() {
  late List<int> requested;

  /// [pages] by number; a page past them is empty.
  Future<({List<int> items, int totalPages})> Function(int page) server(
    List<List<int>> pages, {
    int? totalPages,
  }) => (page) async {
    requested.add(page);
    return (
      items: page <= pages.length ? pages[page - 1] : const <int>[],
      totalPages: totalPages ?? pages.length,
    );
  };

  Future<List<int>> collect(
    Future<({List<int> items, int totalPages})> Function(int page) fetch, {
    int? pastTotalWhenFull,
  }) => collectAllPages(
    fetch,
    idOf: (id) => id,
    what: '/things',
    pastTotalWhenFull: pastTotalWhenFull,
  );

  setUp(() => requested = []);

  test('reads to the page count the server reports', () async {
    final pages = [
      for (var page = 0; page < 30; page++) [page * 2, page * 2 + 1],
    ];

    final all = await collect(server(pages));

    expect(all, hasLength(60));
    expect(requested, hasLength(30));
  });

  test('a page without a new id ends the read, ids seen are skipped', () async {
    final all = await collect(
      server([
        [1, 2],
        [2, 3],
        [3, 2],
      ], totalPages: 9),
    );

    expect(all, [1, 2, 3]);
    expect(requested, [1, 2, 3]);
  });

  test('past the reported end only after a full page, when asked', () async {
    final pages = [
      [1, 2],
      [3, 4],
      [5],
    ];

    expect(await collect(server(pages, totalPages: 1)), [1, 2]);
    expect(await collect(server(pages, totalPages: 1), pastTotalWhenFull: 2), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('a list longer than the cap is cut there with a warning in the '
      'log', () async {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    final pages = [
      for (var page = 1; page <= maxListPages + 5; page++) [page],
    ];

    final all = await collect(server(pages));

    expect(all, hasLength(maxListPages));
    expect(requested, hasLength(maxListPages));
    expect(
      records.where((record) => record.level == Level.WARNING).single.message,
      '/things: stopped after $maxListPages pages with $maxListPages items',
    );
  });
}
