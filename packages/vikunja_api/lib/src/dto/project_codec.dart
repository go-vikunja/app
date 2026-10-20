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

/// v1 and v2 create body; empty optional fields are left out, so the server
/// picks the position.
Map<String, Object?> encodeNewProject(NewProject project) => {
  'title': project.title,
  if (project.parentProjectId != 0)
    'parent_project_id': project.parentProjectId,
  if (hexColorWire(project.hexColor) case final hexColor
      when hexColor.isNotEmpty)
    'hex_color': hexColor,
};

/// Only the set fields; an empty colour or identifier clears it.
Map<String, Object?> encodeProjectChanges(ProjectChanges changes) => {
  'title': ?changes.title,
  'identifier': ?changes.identifier,
  if (changes.hexColor case final hexColor?)
    'hex_color': hexColorWire(hexColor),
  'parent_project_id': ?changes.parentProjectId,
  'is_favorite': ?changes.isFavorite,
  'is_archived': ?changes.isArchived,
  'position': ?changes.position,
};

/// The create body: no filter and no position when the draft has none, and
/// never a `project_id`.
Map<String, Object?> encodeNewView(ViewDraft view) => {
  for (final MapEntry(:key, :value) in encodeViewChanges(view).entries)
    key: ?value,
};

/// The update body: a draft without a filter clears the view's.
Map<String, Object?> encodeViewChanges(ViewDraft view) => {
  'title': view.title,
  'view_kind': view.kind.wireName,
  'filter': switch (view.filter) {
    final filter? => _encodeViewFilter(filter),
    null => null,
  },
  'bucket_configuration_mode': ?view.bucketConfigurationMode?.wireName,
  'position': ?view.position,
};

// Every key is sent, so that a v2 merge-patch replaces the stored filter
// instead of merging into it.
Map<String, Object?> _encodeViewFilter(ViewFilter filter) => {
  'filter': filter.filter,
  's': filter.search,
  'sort_by': filter.sortBy,
  'order_by': filter.orderBy,
  'filter_include_nulls': filter.includeNulls,
};
