import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Project parseProject(Object? json) {
  final map = objectOf(json, 'project');
  return Project(
    id: requireInt(map, 'id', 'project'),
    title: requireString(map, 'title', 'project'),
    description: stringOr(map, 'description', ''),
    identifier: stringOr(map, 'identifier', ''),
    hexColor: hexColorOf(map['hex_color']),
    parentProjectId: intOr(map, 'parent_project_id', 0),
    isArchived: boolOr(map, 'is_archived', fallback: false),
    isFavorite: boolOr(map, 'is_favorite', fallback: false),
    position: doubleOr(map, 'position', 0),
    owner: parseUser(map['owner']),
    views: List.unmodifiable(
      objectListOf(map['views']).map(parseProjectView).nonNulls,
    ),
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
  );
}

/// Null for a view kind this client does not know, so a newer server does
/// not break the project it belongs to.
ProjectView? parseProjectView(Object? json) {
  final map = objectOf(json, 'project view');
  final kind = ProjectViewKind.fromWire(stringOr(map, 'view_kind', ''));
  if (kind == null) return null;
  return ProjectView(
    id: requireInt(map, 'id', 'project view'),
    projectId: requireInt(map, 'project_id', 'project view'),
    title: stringOr(map, 'title', ''),
    kind: kind,
    position: doubleOr(map, 'position', 0),
    filter: switch (map['filter']) {
      final Map<String, Object?> filter => _parseViewFilter(filter),
      _ => null,
    },
    bucketConfigurationMode: BucketConfigurationMode.fromWire(
      stringOr(map, 'bucket_configuration_mode', ''),
    ),
    defaultBucketId: intOr(map, 'default_bucket_id', 0),
    doneBucketId: intOr(map, 'done_bucket_id', 0),
  );
}

ViewFilter _parseViewFilter(Map<String, Object?> json) => ViewFilter(
  filter: stringOr(json, 'filter', ''),
  search: stringOr(json, 's', ''),
  sortBy: stringListOf(json['sort_by']),
  orderBy: stringListOf(json['order_by']),
  includeNulls: boolOr(json, 'filter_include_nulls', fallback: false),
);
