import 'package:meta/meta.dart';

/// One page of a list endpoint. v2 reports [total]; v1 only reports the
/// page count, so [total] is null there, and [totalPages] is null too when a
/// proxy dropped v1's `x-pagination-total-pages` header.
@immutable
final class Page<T> {
  const new({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalPages,
    this.total,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int? totalPages;
  final int? total;

  /// Without a page count, a full page may have more.
  bool get hasMore => switch (totalPages) {
    final pages? => page < pages,
    null => items.isNotEmpty && items.length >= perPage,
  };

  Page<R> map<R>(R Function(T item) convert) => Page(
    items: items.map(convert).toList(growable: false),
    page: page,
    perPage: perPage,
    totalPages: totalPages,
    total: total,
  );
}
