import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('hasMore', () {
    test('while the page is before the last one', () {
      expect(
        const Page<int>(items: [1], page: 1, perPage: 1, totalPages: 3).hasMore,
        isTrue,
      );
      expect(
        const Page<int>(items: [1], page: 2, perPage: 1, totalPages: 3).hasMore,
        isTrue,
      );
    });

    test('not on the last page, an empty result or a page past the end', () {
      expect(
        const Page<int>(items: [1], page: 3, perPage: 1, totalPages: 3).hasMore,
        isFalse,
      );
      expect(
        const Page<int>(items: [], page: 1, perPage: 50, totalPages: 0).hasMore,
        isFalse,
      );
      expect(
        const Page<int>(items: [], page: 5, perPage: 50, totalPages: 3).hasMore,
        isFalse,
      );
    });

    test('without a page count, while the page is full', () {
      expect(
        const Page<int>(
          items: [1, 2],
          page: 1,
          perPage: 2,
          totalPages: null,
        ).hasMore,
        isTrue,
      );
    });

    test('without a page count, not on a short or an empty page', () {
      expect(
        const Page<int>(
          items: [1],
          page: 1,
          perPage: 2,
          totalPages: null,
        ).hasMore,
        isFalse,
      );
      expect(
        const Page<int>(
          items: [],
          page: 1,
          perPage: 50,
          totalPages: null,
        ).hasMore,
        isFalse,
      );
      expect(
        const Page<int>(
          items: [],
          page: 1,
          perPage: 0,
          totalPages: null,
        ).hasMore,
        isFalse,
      );
    });
  });

  test('map converts the items and keeps the paging', () {
    const page = Page<int>(
      items: [1, 2],
      page: 2,
      perPage: 2,
      totalPages: 4,
      total: 7,
    );

    final mapped = page.map((item) => 'n$item');

    expect(mapped.items, ['n1', 'n2']);
    expect(mapped.page, 2);
    expect(mapped.perPage, 2);
    expect(mapped.totalPages, 4);
    expect(mapped.total, 7);
    expect(mapped.hasMore, isTrue);

    final unknown = const Page<int>(
      items: [1, 2],
      page: 1,
      perPage: 2,
      totalPages: null,
    ).map((item) => 'n$item');

    expect(unknown.totalPages, isNull);
    expect(unknown.hasMore, isTrue);
  });

  test('total is null when the server did not report one', () {
    expect(
      const Page<int>(items: [], page: 1, perPage: 50, totalPages: 1).total,
      isNull,
    );
  });
}
