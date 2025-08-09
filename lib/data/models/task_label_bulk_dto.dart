import 'package:vikunja_app/data/models/label_dto.dart';

class LabelTaskBulkDto {
  final List<LabelDto> labels;

  LabelTaskBulkDto({required this.labels});

  LabelTaskBulkDto.fromJson(Map<String, dynamic> json)
      : labels = json['labels']?.map((label) => LabelDto.fromJson(label));

  toJSON() => {
        'labels': labels.map((label) => label.toJSON()).toList(),
      };
}
