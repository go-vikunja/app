import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class LabelTask {
  final Label label;
  final Task? task;

  LabelTask({required this.label, required this.task});
}
