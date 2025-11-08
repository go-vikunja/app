class WidgetTask{
  String id;
  String title;
  DateTime? dueDate;
  bool today;
  bool overdue;

  WidgetTask({
    this.id = '0',
    this.title = 'None',
    this.dueDate,
    this.today = false,
    this.overdue = false
  });

    toJSON() => {
    'id': id,
    'title': title,
    'dueDate': dueDate?.toUtc().toIso8601String(),
    'today': today,
    'overdue': overdue,
  };

}
