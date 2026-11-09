import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

TrashedTask parseTrashedTask(Object? json) {
  final map = objectOf(json, 'trashed task');
  return TrashedTask(
    task: parseTask(map),
    deletedAt: _deletedAtOf(map, 'trashed task'),
    deletedBy: parseOtherUser(map['deleted_by']),
    canDeletePermanently: boolOr(
      map,
      'can_delete_permanently',
      fallback: false,
    ),
  );
}

/// The list sends the project without views and permission.
TrashedProject parseTrashedProject(Object? json) {
  final map = objectOf(json, 'trashed project');
  return TrashedProject(
    project: parseProject(map),
    deletedAt: _deletedAtOf(map, 'trashed project'),
    deletedBy: parseOtherUser(map['deleted_by']),
    subprojects: List.unmodifiable(
      objectListOf(map['trashed_sub_projects']).map(_subprojectOf).nonNulls,
    ),
  );
}

TrashCount parseTrashCount(Object? json) {
  final map = objectOf(json, 'trash count');
  return TrashCount(
    total: requireInt(map, 'total', 'trash count'),
    byOthers: intOr(map, 'by_others', 0),
  );
}

/// The `details` of a 404 with code 4040 or 3018. Null for anything but an
/// object with an int `id`; never throws, so a body this client does not
/// understand still gives its `NotFound`.
TrashDetails? parseTrashDetails(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final id = json['id'];
  if (id is! int) return null;
  return TrashDetails(
    id: id,
    deletedAt: dateOf(json['deleted_at']),
    deletedBy: switch (json['deleted_by']) {
      final Map<String, Object?> user => parseOtherUser(user),
      _ => null,
    },
    canRestore: boolOr(json, 'can_restore', fallback: false),
    projectId: _idOrNull(json['project_id']),
    trashedRootId: _idOrNull(json['trashed_root_id']),
    canRestoreRoot: boolOr(json, 'can_restore_root', fallback: false),
  );
}

int? _idOrNull(Object? value) => switch (value) {
  final int id when id > 0 => id,
  _ => null,
};

DateTime _deletedAtOf(Map<String, Object?> json, String what) =>
    switch (dateOf(json['deleted_at'])) {
      final date? => date,
      null => throw MalformedJson('$what without deleted_at'),
    };

TrashedSubproject? _subprojectOf(Map<String, Object?> json) =>
    switch (json['id']) {
      final int id => TrashedSubproject(
        id: id,
        title: stringOr(json, 'title', ''),
        parentProjectId: intOr(json, 'parent_project_id', 0),
        depth: intOr(json, 'depth', 1),
      ),
      _ => null,
    };
