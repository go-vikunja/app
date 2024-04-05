import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

class LabelTask {
  final Label label;
  final Task? task;

  LabelTask({required this.label, required this.task});

  LabelTask.fromJson(Map<String, dynamic> json, User createdBy)
      : label =
            new Label(id: json['label_id'], title: '', createdBy: createdBy),
        task = null;

  toJSON() => {
        'label_id': label.id,
      };
}
