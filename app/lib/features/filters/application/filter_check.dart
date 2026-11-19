import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// The labels and projects a filter's titles stand for, which the builder
/// shows instead of the ids the server takes.
@immutable
final class FilterLookups {
  new({List<Label> labels = const [], List<Project> projects = const []})
    : _tables = LookupTables(
        // A label created here has only a temporary id until its create is
        // answered, and the filter goes to the server.
        labels: {
          for (final label in labels)
            if (label.id > 0) label.id: label.title,
        },
        projects: {
          for (final project in projects)
            if (!project.isPseudo) project.id: project.title,
        },
      );

  final LookupTables _tables;

  /// Label and project titles as ids, camelCase fields in snake_case, as
  /// the web sends a filter; titles nothing has stay as typed, and so do
  /// the numbers in [keepIds], which are ids already. A negative one is no
  /// id the server has (a temporary or a pseudo project's) and is not kept.
  String toApi(String typed, {FilterIds keepIds = const FilterIds()}) =>
      filterForApi(
        typed,
        lookups: _tables,
        keepIds: FilterIds(
          labels: {
            for (final id in keepIds.labels)
              if (id > 0) id,
          },
          projects: {
            for (final id in keepIds.projects)
              if (id > 0) id,
          },
        ),
      );

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
