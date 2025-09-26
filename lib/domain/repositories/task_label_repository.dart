import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';

abstract class TaskLabelRepository {
  Future<Response<Label>> delete(LabelTask lt);
}
