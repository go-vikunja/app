import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';

abstract class TaskLabelBulkRepository {
  Future<Response<List<Label>>> update(Task task, List<Label> labels);
}
