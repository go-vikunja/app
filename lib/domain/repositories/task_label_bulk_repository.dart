import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';

abstract class TaskLabelBulkRepository {
  Future<List<Label>?> update(Task task, List<Label>? labels);
}
