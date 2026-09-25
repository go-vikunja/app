import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';

const _zeroDate = '0001-01-01T00:00:00.000Z';

Map<String, dynamic> taskToCache(Task task) {
  final json = Map<String, dynamic>.from(TaskDto.fromDomain(task).toJSON());
  json['due_date'] ??= _zeroDate;
  json['start_date'] ??= _zeroDate;
  json['end_date'] ??= _zeroDate;
  json['repeat_after'] ??= 0;
  json['hex_color'] ??= '';
  json['identifier'] ??= '';
  json['created_by'] ??= {
    'id': 0,
    'username': 'offline',
    'name': '',
    'created': json['created'] ?? _zeroDate,
    'updated': json['updated'] ?? _zeroDate,
  };
  return json;
}

Task taskFromCache(Map<String, dynamic> json) {
  return TaskDto.fromJson(json).toDomain();
}

Map<String, dynamic> projectToCache(Project project) {
  final json = Map<String, dynamic>.from(
    ProjectDto.fromDomain(project).toJSON(),
  );
  json['hex_color'] ??= '';
  json['position'] ??= 0;
  json['views'] ??= [];
  json['is_archived'] ??= false;
  json['is_favorite'] ??= false;
  json['parent_project_id'] ??= 0;
  json['description'] ??= '';
  return json;
}

Project projectFromCache(Map<String, dynamic> json) {
  return ProjectDto.fromJson(json).toDomain();
}

Map<String, dynamic> userToCache(User user) {
  return {
    'id': user.id,
    'name': user.name,
    'username': user.username,
    'created': user.created.toUtc().toIso8601String(),
    'updated': user.updated.toUtc().toIso8601String(),
    if (user.settings != null)
      'settings': UserSettingsDto.fromDomain(user.settings!).toJson(),
  };
}

User userFromCache(Map<String, dynamic> json) {
  return UserDto.fromJson(json).toDomain();
}

bool taskMatchesFilter(Task task, String filter) {
  final normalized = filter.toLowerCase().replaceAll(' ', '');
  if (normalized.contains('done=false') && task.done) {
    return false;
  }
  if (normalized.contains('due_date') && !task.hasDueDate) {
    return false;
  }
  return true;
}
