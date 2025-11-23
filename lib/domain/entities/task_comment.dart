import 'package:vikunja_app/domain/entities/user.dart';

class TaskComment {
  final int id;
  final String comment;
  final User author;
  final DateTime created;
  final DateTime updated;

  TaskComment({
    this.id = 0,
    required this.comment,
    required this.author,
    DateTime? created,
    DateTime? updated,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();
}
