import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';

class LabelTaskDto {
  final LabelDto label;
  final TaskDto? task;

  LabelTaskDto({required this.label, required this.task});

  LabelTaskDto.fromJson(Map<String, dynamic> json, UserDto createdBy)
      : label =
            new LabelDto(id: json['label_id'], title: '', createdBy: createdBy),
        task = null;

  toJSON() => {
        'label_id': label.id,
      };

  LabelTaskDto toDomain() => LabelTaskDto(label: label, task: task);

  static LabelTaskDto fromDomain(LabelTask b) => LabelTaskDto(
      label: LabelDto.fromDomain(b.label),
      task: b.task != null ? TaskDto.fromDomain(b.task!) : null);
}
