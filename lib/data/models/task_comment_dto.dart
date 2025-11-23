import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';

class TaskCommentDto extends Dto<TaskComment> {
  final int id;
  final String comment;
  final UserDto author;
  final DateTime created;
  final DateTime updated;

  TaskCommentDto({
    this.id = 0,
    required this.comment,
    required this.author,
    DateTime? created,
    DateTime? updated,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  TaskCommentDto.fromJson(Map<String, dynamic> json)
    : id = json['id'] ?? 0,
      comment = json['comment'] ?? '',
      author = UserDto.fromJson(json['author']),
      created = DateTime.parse(json['created']),
      updated = DateTime.parse(json['updated']);

  Map<String, dynamic> toJSON() => {
    'id': id,
    'comment': comment,
    'author': author.toJSON(),
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
  };

  @override
  TaskComment toDomain() => TaskComment(
    id: id,
    comment: comment,
    author: author.toDomain(),
    created: created,
    updated: updated,
  );

  static TaskCommentDto fromDomain(TaskComment c) => TaskCommentDto(
    id: c.id,
    comment: c.comment,
    author: UserDto.fromDomain(c.author),
    created: c.created,
    updated: c.updated,
  );
}
