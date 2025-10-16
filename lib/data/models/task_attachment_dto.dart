import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';

class TaskAttachmentFileDto extends Dto<TaskAttachmentFile> {
  final int id;
  final DateTime created;
  final String mime;
  final String name;
  final int size;

  TaskAttachmentFileDto({
    required this.id,
    required this.created,
    required this.mime,
    required this.name,
    required this.size,
  });

  TaskAttachmentFileDto.fromJSON(Map<String, dynamic> json)
    : id = json['id'],
      created = DateTime.parse(json['created']),
      mime = json['mime'],
      name = json['name'],
      size = json['size'];

  Map<String, Object> toJSON() => {
    'id': id,
    'created': created.toUtc().toIso8601String(),
    'mime': mime,
    'name': name,
    'size': size,
  };

  @override
  TaskAttachmentFile toDomain() => TaskAttachmentFile(
    id: id,
    created: created,
    mime: mime,
    name: name,
    size: size,
  );

  static TaskAttachmentFileDto fromDomain(TaskAttachmentFile b) =>
      TaskAttachmentFileDto(
        id: b.id,
        created: b.created,
        mime: b.mime,
        name: b.name,
        size: b.size,
      );
}

class TaskAttachmentDto extends Dto<TaskAttachment> {
  final int id, taskId;
  final DateTime created;
  final UserDto createdBy;
  final TaskAttachmentFileDto file;

  TaskAttachmentDto({
    this.id = 0,
    required this.taskId,
    DateTime? created,
    required this.createdBy,
    required this.file,
  }) : created = created ?? DateTime.now();

  TaskAttachmentDto.fromJSON(Map<String, dynamic> json)
    : id = json['id'],
      taskId = json['task_id'],
      created = DateTime.parse(json['created']),
      file = TaskAttachmentFileDto.fromJSON(json['file']),
      createdBy = UserDto.fromJson(json['created_by']);

  Map<String, Object> toJSON() => {
    'id': id,
    'task_id': taskId,
    'created': created.toUtc().toIso8601String(),
    'created_by': createdBy.toJSON(),
    'file': file.toJSON(),
  };

  @override
  TaskAttachment toDomain() => TaskAttachment(
    id: id,
    taskId: taskId,
    created: created,
    createdBy: createdBy.toDomain(),
    file: file.toDomain(),
  );

  static TaskAttachmentDto fromDomain(TaskAttachment b) => TaskAttachmentDto(
    id: b.id,
    taskId: b.taskId,
    created: b.created,
    createdBy: UserDto.fromDomain(b.createdBy),
    file: TaskAttachmentFileDto.fromDomain(b.file),
  );
}
