import 'package:vikunja_app/data/models/user.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class Bucket {
  int id, limit;
  int? projectViewId;
  String title;
  double? position;
  final DateTime created, updated;
  User createdBy;
  final List<Task> tasks;

  Bucket({
    this.id = 0,
    required this.projectViewId,
    required this.title,
    this.position,
    required this.limit,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    List<Task>? tasks,
  })  : this.created = created ?? DateTime.now(),
        this.updated = created ?? DateTime.now(),
        this.tasks = tasks ?? [];
}
