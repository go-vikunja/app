class TaskReminder {
  final int relativePeriod;
  final String relativeTo;
  DateTime reminder;

  TaskReminder(this.reminder, [this.relativePeriod = 0, this.relativeTo = ""]);

  TaskReminder.fromJson(Map<String, dynamic> json)
    : reminder = DateTime.parse(json['reminder']),
      relativePeriod = json['relative_period'],
      relativeTo = json['relative_to'];

  Map<String, Object> toJSON() => {
    'relative_period': relativePeriod,
    'relative_to': relativeTo,
    'reminder': reminder.toUtc().toIso8601String(),
  };
}
