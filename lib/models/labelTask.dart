import 'package:meta/meta.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';

class LabelTask {
  final Label label;
  final Task task;

  LabelTask({@required this.label, @required this.task});

  LabelTask.fromJson(Map<String, dynamic> json)
      : label = new Label(id: json['label_id']),
        task = null;

  toJSON() => {
        'label_id': label.id,
      };
}
