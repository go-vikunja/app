import 'package:flutter/foundation.dart';

/// The pages of one list loaded so far and whether the server has more.
@immutable
final class PagedList<T> {
  const new({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}
