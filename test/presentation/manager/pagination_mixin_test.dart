/// The paging mechanics live here, once. The three controllers that mix this
/// in only assert their own state wiring, never the page arithmetic.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';

import '../../helpers/fake_repositories.dart';

class _Paginated with PaginationMixin<String> {}

/// `loadMoreItems` sleeps for three seconds before fetching; [fakeAsync] skips
/// that wall-clock wait so the suite stays fast.
T runPaged<T>(T Function(FakeAsync async) body) => fakeAsync(body);

void main() {
  late _Paginated subject;

  setUp(() => subject = _Paginated());

  group('page bookkeeping', () {
    test('starts on a single page with nothing more to load', () {
      expect(subject.hasMorePages, isFalse);
      expect(subject.canLoadNextPage, isFalse);
      expect(subject.loadingNextPage, isFalse);
    });

    test('reads the total page count from the pagination header', () {
      subject.updateTotalPages(paginationHeaders(3));

      expect(subject.hasMorePages, isTrue);
      expect(subject.canLoadNextPage, isTrue);
    });

    test('matches the pagination header case-insensitively', () {
      subject.updateTotalPages({'X-Pagination-Total-Pages': '5'});

      expect(subject.hasMorePages, isTrue);
    });

    test('falls back to one page when the header is missing', () {
      subject.updateTotalPages(const {});

      expect(subject.hasMorePages, isFalse);
    });

    test('falls back to one page when the header is not a number', () {
      subject.updateTotalPages({'x-pagination-total-pages': 'many'});

      expect(subject.hasMorePages, isFalse);
    });

    test('resetPagination returns to page one of one', () {
      subject.updateTotalPages(paginationHeaders(4));

      subject.resetPagination();

      expect(subject.hasMorePages, isFalse);
    });
  });

  group('loadMoreItems', () {
    test('fetches the next page and hands the items to the updater', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(3));
        final requestedPages = <int>[];
        List<Object>? received;

        subject.loadMoreItems(
          fetcher: (page) async {
            requestedPages.add(page);
            return ok<List<Object>>(['a', 'b'], headers: paginationHeaders(3));
          },
          stateUpdater: (items) => received = items,
        );
        async.elapse(const Duration(seconds: 4));

        expect(requestedPages, [2]);
        expect(received, ['a', 'b']);
      });
    });

    test('advances through the pages one at a time', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(3));
        final requestedPages = <int>[];

        Future<void> loadOnce() => subject.loadMoreItems(
          fetcher: (page) async {
            requestedPages.add(page);
            return ok<List<Object>>(['x'], headers: paginationHeaders(3));
          },
          stateUpdater: (_) {},
        );

        loadOnce();
        async.elapse(const Duration(seconds: 4));
        loadOnce();
        async.elapse(const Duration(seconds: 4));

        expect(requestedPages, [2, 3]);
        expect(subject.hasMorePages, isFalse);
      });
    });

    test('does nothing when the last page has been reached', () {
      runPaged((async) {
        var fetched = false;

        subject.loadMoreItems(
          fetcher: (page) async {
            fetched = true;
            return ok<List<Object>>([]);
          },
          stateUpdater: (_) {},
        );
        async.elapse(const Duration(seconds: 4));

        expect(fetched, isFalse);
      });
    });

    test('ignores a second call while one is already in flight', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(5));
        var fetchCount = 0;

        Future<void> loadOnce() => subject.loadMoreItems(
          fetcher: (page) async {
            fetchCount++;
            return ok<List<Object>>(['x'], headers: paginationHeaders(5));
          },
          stateUpdater: (_) {},
        );

        loadOnce();
        loadOnce();
        async.elapse(const Duration(seconds: 4));

        expect(fetchCount, 1);
      });
    });

    test('does not advance the page when the fetch fails', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(3));
        final requestedPages = <int>[];
        var updaterRan = false;

        Future<void> loadOnce() => subject.loadMoreItems(
          fetcher: (page) async {
            requestedPages.add(page);
            return err<List<Object>>();
          },
          stateUpdater: (_) => updaterRan = true,
        );

        loadOnce();
        async.elapse(const Duration(seconds: 4));
        loadOnce();
        async.elapse(const Duration(seconds: 4));

        expect(requestedPages, [2, 2]);
        expect(updaterRan, isFalse);
      });
    });

    test('swallows a thrown fetch error and clears the in-flight flag', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(3));

        subject.loadMoreItems(
          fetcher: (page) async => throw StateError('network down'),
          stateUpdater: (_) {},
        );
        async.elapse(const Duration(seconds: 4));

        expect(subject.loadingNextPage, isFalse);
        expect(subject.canLoadNextPage, isTrue);
      });
    });

    test('clears the in-flight flag after a successful load', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(3));

        subject.loadMoreItems(
          fetcher: (page) async =>
              ok<List<Object>>(['x'], headers: paginationHeaders(3)),
          stateUpdater: (_) {},
        );
        async.elapse(const Duration(seconds: 4));

        expect(subject.loadingNextPage, isFalse);
      });
    });

    test('picks up a revised total page count from the response', () {
      runPaged((async) {
        subject.updateTotalPages(paginationHeaders(2));

        subject.loadMoreItems(
          fetcher: (page) async =>
              ok<List<Object>>(['x'], headers: paginationHeaders(9)),
          stateUpdater: (_) {},
        );
        async.elapse(const Duration(seconds: 4));

        expect(subject.hasMorePages, isTrue);
      });
    });
  });
}
