import 'package:vikunja_app/models/label.dart';

class LabelTaskBulk {
  final List<Label> labels;

  LabelTaskBulk({required this.labels});

  LabelTaskBulk.fromJson(Map<String, dynamic> json)
      : labels = json['labels']?.map((label) => Label.fromJson(label));

  toJSON() => {
        'labels': labels.map((label) => label.toJSON()).toList(),
      };
}
