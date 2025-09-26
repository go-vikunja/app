import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';

class LabelTaskDto extends Dto<LabelTask> {
  final LabelDto label;
  final TaskDto? task;

  LabelTaskDto({required this.label, required this.task});

  LabelTaskDto.fromJson(Map<String, dynamic> json, UserDto createdBy)
    : label = LabelDto(id: json['label_id'], title: '', createdBy: createdBy),
      task = null;

  Map<String, int> toJSON() => {'label_id': label.id};

  @override
  LabelTask toDomain() =>
      LabelTask(label: label.toDomain(), task: task?.toDomain());

  static LabelTaskDto fromDomain(LabelTask b) => LabelTaskDto(
    label: LabelDto.fromDomain(b.label),
    task: b.task != null ? TaskDto.fromDomain(b.task!) : null,
  );
}
