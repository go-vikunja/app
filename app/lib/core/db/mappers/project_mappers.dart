import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

ProjectRow projectRow(Project project) => ProjectRow(
  id: project.id,
  title: project.title,
  description: project.description,
  identifier: project.identifier,
  hexColor: project.hexColor,
  parentProjectId: project.parentProjectId,
  isArchived: project.isArchived,
  isFavorite: project.isFavorite,
  position: project.position,
  ownerId: project.owner?.id,
  created: project.created,
  updated: project.updated,
  maxPermission: project.maxPermission?.value,
  subscribedVia: project.subscription?.entityId,
);

ProjectViewRow projectViewRow(ProjectView view) => ProjectViewRow(
  id: view.id,
  projectId: view.projectId,
  title: view.title,
  kind: view.kind.wireName,
  position: view.position,
  filterJson: encodeViewFilter(view.filter),
  bucketConfigurationMode: view.bucketConfigurationMode.wireName,
  defaultBucketId: view.defaultBucketId,
  doneBucketId: view.doneBucketId,
);

Project projectFromRow(
  ProjectRow row, {
  required List<ProjectViewRow> views,
  User? owner,
}) => Project(
  id: row.id,
  title: row.title,
  description: row.description,
  identifier: row.identifier,
  hexColor: row.hexColor,
  parentProjectId: row.parentProjectId,
  isArchived: row.isArchived,
  isFavorite: row.isFavorite,
  position: row.position,
  owner: owner,
  views: List.unmodifiable(views.map(projectViewFromRow).nonNulls),
  created: row.created,
  updated: row.updated,
  maxPermission: Permission.fromValue(row.maxPermission),
  subscription: switch (row.subscribedVia) {
    final projectId? => Subscription(
      entity: SubscriptionEntity.project,
      entityId: projectId,
    ),
    null => null,
  },
);

/// Null for a view kind this build does not know, like the codec does.
ProjectView? projectViewFromRow(ProjectViewRow row) {
  final kind = ProjectViewKind.fromWire(row.kind);
  if (kind == null) return null;
  return ProjectView(
    id: row.id,
    projectId: row.projectId,
    title: row.title,
    kind: kind,
    position: row.position,
    filter: decodeViewFilter(row.filterJson),
    bucketConfigurationMode: BucketConfigurationMode.fromWire(
      row.bucketConfigurationMode,
    ),
    defaultBucketId: row.defaultBucketId,
    doneBucketId: row.doneBucketId,
  );
}

/// The server's own JSON shape, so step 7 can diff it against responses.
String? encodeViewFilter(ViewFilter? filter) {
  if (filter == null) return null;
  return jsonEncode({
    'filter': filter.filter,
    's': filter.search,
    'sort_by': filter.sortBy,
    'order_by': filter.orderBy,
    'filter_include_nulls': filter.includeNulls,
  });
}

ViewFilter? decodeViewFilter(String? json) {
  if (json == null) return null;
  if (jsonDecode(json) case final Map<String, Object?> map) {
    return ViewFilter(
      filter: map['filter'] as String? ?? '',
      search: map['s'] as String? ?? '',
      sortBy: _strings(map['sort_by']),
      orderBy: _strings(map['order_by']),
      includeNulls: map['filter_include_nulls'] as bool? ?? false,
    );
  }
  return null;
}

List<String> _strings(Object? value) => switch (value) {
  final List<Object?> list => List.unmodifiable(list.whereType<String>()),
  _ => const [],
};
