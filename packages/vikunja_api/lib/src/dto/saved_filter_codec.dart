import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

SavedFilter parseSavedFilter(Object? json) {
  final map = objectOf(json, 'saved filter');
  final filters = switch (map['filters']) {
    final Map<String, Object?> filters => filters,
    _ => const <String, Object?>{},
  };
  return SavedFilter(
    id: requireInt(map, 'id', 'saved filter'),
    title: requireString(map, 'title', 'saved filter'),
    description: stringOr(map, 'description', ''),
    filter: parseViewFilter(filters),
    isFavorite: boolOr(map, 'is_favorite', fallback: false),
    timezone: stringOr(filters, 'filter_timezone', ''),
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
  );
}

/// The create and update body on both versions. Never a timezone: v2
/// refuses the property, v1 drops it.
Map<String, Object?> encodeSavedFilterDraft(SavedFilterDraft draft) => {
  'title': draft.title,
  'description': draft.description,
  'filters': encodeViewFilter(draft.filter),
  'is_favorite': draft.isFavorite,
};
