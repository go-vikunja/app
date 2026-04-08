import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';

mixin PaginationMixin<T> {
  int _currentPage = 1;
  int _totalPages = 1;
  bool loadingNextPage = false;

  void resetPagination() {
    _currentPage = 1;
    _totalPages = 1;
  }

  void updateTotalPages(Map<String, String> headers) {
    var checkHeaders = headers.map((key, value) => MapEntry(key.toLowerCase(), value));
    _totalPages = int.tryParse(checkHeaders['x-pagination-total-pages'] ?? '1') ?? 1;
  }

  Future<void> loadMoreItems({
    required Future<Response<List<Object>>> Function(int page) fetcher,
    required FutureOr<void> Function(List<Object> newItems) stateUpdater,
  }) async {
    if (!hasMorePages || loadingNextPage) return;

    loadingNextPage = true;
    final nextPage = _currentPage + 1;
    
    try {
      final response = await fetcher(nextPage);
      if (response.isSuccessful) {
        _currentPage = nextPage;
        updateTotalPages(response.toSuccess().headers);
        final items = response.toSuccess().body;
        await stateUpdater(items);
      }
    } catch (_) {
      // ignore
    } finally {
      loadingNextPage = false;
    }
  }

  bool get hasMorePages => _currentPage < _totalPages;
}


