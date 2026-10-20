import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// The labels and projects a filter's titles stand for, which the builder
/// shows instead of the ids the server takes.
@immutable
final class FilterLookups {
  new({List<Label> labels = const [], List<Project> projects = const []})
    : _tables = LookupTables(
        labels: {for (final label in labels) label.id: label.title},
        projects: {
          for (final project in projects)
            if (!project.isPseudo) project.id: project.title,
        },
      );

  final LookupTables _tables;

  /// Label and project titles as ids, camelCase fields in snake_case, as
  /// the web sends a filter; titles nothing has stay as typed, and so do
  /// the numbers in [keepIds], which are ids already.
  String toApi(String typed, {FilterIds keepIds = const FilterIds()}) =>
      filterForApi(typed, lookups: _tables, keepIds: keepIds);

  /// Label and project ids as titles, for showing a stored filter.
  String fromApi(String stored) => filterFromApi(stored, lookups: _tables);

  /// The ids [fromApi] shows as numbers, nothing here having a title for
  /// them.
  FilterIds untitledIds(String stored) =>
      untitledFilterIds(stored, lookups: _tables);
}

/// What the engine says about [apiText]: null for a filter it accepts,
/// an empty one included.
FilterError? filterErrorOf(String apiText) {
  if (apiText.isEmpty) return null;
  return switch (parseTaskFilter(apiText)) {
    final FilterError error => error,
    _ => null,
  };
}
