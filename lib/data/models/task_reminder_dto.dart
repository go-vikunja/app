import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';

class TaskReminderDto extends Dto<TaskReminder> {
  final int relativePeriod;
  final String relativeTo;
  DateTime reminder;

  TaskReminderDto(
    this.reminder, [
    this.relativePeriod = 0,
    this.relativeTo = "",
  ]);

  TaskReminderDto.fromJson(Map<String, dynamic> json)
    : reminder = DateTime.parse(json['reminder']),
      relativePeriod = json['relative_period'],
      relativeTo = json['relative_to'];

  Map<String, Object> toJSON() => {
    'relative_period': relativePeriod,
    'relative_to': relativeTo,
    'reminder': reminder.toUtc().toIso8601String(),
  };

  @override
  TaskReminder toDomain() => TaskReminder(reminder, relativePeriod, relativeTo);

  static TaskReminderDto fromDomain(TaskReminder b) =>
      TaskReminderDto(b.reminder, b.relativePeriod, b.relativeTo);
}
