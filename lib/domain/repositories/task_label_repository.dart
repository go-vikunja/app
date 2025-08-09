import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';

abstract class TaskLabelRepository {
  Future<Label?> create(LabelTask lt);

  Future<Label?> delete(LabelTask lt);

  Future<List<Label>?> getAll(LabelTask lt, {String? query});
}
