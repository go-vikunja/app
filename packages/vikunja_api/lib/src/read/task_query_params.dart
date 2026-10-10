import 'package:vikunja_domain/vikunja_domain.dart';

/// The query of a task list request. Pass the result to dio as
/// `queryParameters` with `ListFormat.multi`, so repeated keys are sent as
/// `sort_by=a&sort_by=b` and the filter is percent-encoded once.
///
/// A position is stored per view, so the server rejects sorting by it
/// anywhere else (4026); [inView] false drops such sorts.
Map<String, Object?> taskQueryParameters(
  TaskQuery query, {
  required ApiVersion version,
  required bool inView,
}) {
  final sort = inView
      ? query.sort
      : query.sort
            .where((sort) => sort.field != TaskSortField.position)
            .toList();
  return {
    if (query.filter case final filter? when filter.isNotEmpty)
      'filter': filter,
    if (query.filterTimezone case final zone? when zone.isNotEmpty)
      'filter_timezone': zone,
    if (query.includeNulls) 'filter_include_nulls': 'true',
    if (sort.isNotEmpty) ...{
      'sort_by': [for (final sort in sort) sort.field.wireName],
      'order_by': [
        for (final sort in sort)
          if (sort.descending) 'desc' else 'asc',
      ],
    },
    if (query.expand.isNotEmpty)
      'expand': [for (final expand in query.expand) expand.wireName],
    if (query.search case final search? when search.isNotEmpty)
      searchParameterName(version): search,
    'page': query.page,
    'per_page': ?query.perPage,
  };
}

String searchParameterName(ApiVersion version) => switch (version) {
  ApiVersion.v1 => 's',
  ApiVersion.v2 => 'q',
};
