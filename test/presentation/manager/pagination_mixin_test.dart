import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';

class TestPagination with PaginationMixin<int> {}

void main() {
  testWidgets('loadMoreItems does not apply stale results', (tester) async {
    final pagination = TestPagination();
    pagination.updateTotalPages({'x-pagination-total-pages': '3'});

    var updaterCalled = false;
    final future = pagination.loadMoreItems(
      fetcher: (page) async => SuccessResponse([page], 200, {
        'x-pagination-total-pages': '3',
      }),
      shouldApply: () => false,
      stateUpdater: (_) {
        updaterCalled = true;
      },
    );

    await tester.pump(const Duration(seconds: 4));
    await future;

    expect(updaterCalled, isFalse);
    expect(pagination.canLoadNextPage, isTrue);
  });
}
