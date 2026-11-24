import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';

void main() {
  group('collectPages', () {
    test('without a page count the walk goes on until a page brings no new '
        'id', () async {
      const pages = [
        [1, 2],
        [3],
        <int>[],
      ];
      final requested = <int>[];

      final ids = await collectPages<int>(
        fetch: (page) async {
          requested.add(page);
          return Page(
            items: page <= pages.length ? pages[page - 1] : const [],
            page: page,
            perPage: 2,
            totalPages: null,
          );
        },
        idOf: (id) => id,
      );

      expect(ids.keys.toSet(), {1, 2, 3});
      expect(requested, [1, 2, 3]);
    });

    test('without a page count, items skipped on every page and a page that '
        'repeats the last one end the walk', () async {
      const pages = [
        [1, 2],
        [3],
      ];
      final requested = <int>[];

      final ids = await collectPages<int>(
        fetch: (page) async {
          requested.add(page);
          return Page(
            items: [...pages[page.clamp(1, pages.length) - 1], -1],
            page: page,
            perPage: 2,
            totalPages: null,
          );
        },
        idOf: (id) => id,
        skip: (id) => id < 0,
      );

      expect(ids.keys.toSet(), {1, 2, 3});
      expect(requested, [1, 2, 3]);
    });

    test('without a page count a walk that misses a stored id is walked once '
        'more, and only an id missing from both walks is left out', () async {
      final server = [1, 2, 3, 4, 5];
      final requested = <int>[];

      final ids = await collectPages<int>(
        fetch: (page) async {
          requested.add(page);
          // Deleted while the first walk asks for its second page: 3 moves
          // up into the page already read.
          if (requested.length == 2) server.remove(1);
          return Page(
            items: server.skip((page - 1) * 2).take(2).toList(),
            page: page,
            perPage: 2,
            totalPages: null,
          );
        },
        idOf: (id) => id,
        stored: const [1, 2, 3, 4, 5, 6],
      );

      expect(ids.keys.toSet(), {1, 2, 3, 4, 5});
      expect(requested, [1, 2, 3, 1, 2, 3]);
    });

    test('a walk without a page count that misses no stored id is not '
        'repeated', () async {
      final requested = <int>[];

      await collectPages<int>(
        fetch: (page) async {
          requested.add(page);
          return Page(
            items: switch (page) {
              1 => const [1, 2],
              2 => const [3],
              _ => const <int>[],
            },
            page: page,
            perPage: 2,
            totalPages: null,
          );
        },
        idOf: (id) => id,
        stored: const [1, 3],
      );

      expect(requested, [1, 2, 3]);
    });

    test('a walk with a page count is not repeated for a stored id it '
        'misses', () async {
      final requested = <int>[];

      final ids = await collectPages<int>(
        fetch: (page) async {
          requested.add(page);
          return Page(
            items: page == 1 ? const [1, 2] : const [3],
            page: page,
            perPage: 2,
            totalPages: 2,
          );
        },
        idOf: (id) => id,
        stored: const [1, 4],
      );

      expect(ids.keys.toSet(), {1, 2, 3});
      expect(requested, [1, 2]);
    });

    test(
      'a page without a count is not compared with one that has it',
      () async {
        final requested = <int>[];

        final ids = await collectPages<int>(
          fetch: (page) async {
            requested.add(page);
            return switch (page) {
              1 => const Page(
                items: [1, 2],
                page: 1,
                perPage: 2,
                totalPages: 2,
              ),
              2 => const Page(
                items: [3],
                page: 2,
                perPage: 2,
                totalPages: null,
              ),
              _ => Page(
                items: const [],
                page: page,
                perPage: 2,
                totalPages: null,
              ),
            };
          },
          idOf: (id) => id,
        );

        expect(ids.keys.toSet(), {1, 2, 3});
        expect(requested, [1, 2, 3]);
      },
    );
  });

  test('a short page ends a keyset walk only when the server reports a page '
      'count', () {
    expect(
      endsKeysetWalk(
        const Page<int>(items: [1], page: 1, perPage: 2, totalPages: 1),
      ),
      isTrue,
    );
    expect(
      endsKeysetWalk(
        const Page<int>(items: [1], page: 1, perPage: 2, totalPages: null),
      ),
      isFalse,
    );
    expect(
      endsKeysetWalk(
        const Page<int>(items: [1, 2], page: 1, perPage: 2, totalPages: 2),
      ),
      isFalse,
    );
  });
}
