import 'package:vikunja_app/models/task.dart';
// import 'package:vikunja_app/service/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

// I expect a list of tasks here, when I get it I get:
// Filter tasks and get only the ones due today
// Extract the time from the datetime
// Take the title of the task
// Update shared preferences using the home_widget package
// First item needs to be the number of tasks that need to be saved

List<Task> filterForTodayTasks(List<Task> tasks) {
  var todayTasks = <Task>[];

  for (var task in tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (task.dueDate!.day == today.day) {
      todayTasks.add(task);
    }
  }
  return todayTasks;
}

void updateWidgetTasks(List<Task>? tasklist) async {
  var todayTasks = filterForTodayTasks(tasklist!);

  // Set the number of tasks
  HomeWidget.saveWidgetData('numTasks', todayTasks.length);
  DateFormat timeFormat = DateFormat("HH:mm");
  var num = 0;
  for (var task in todayTasks) {
    num++;
    var widgetTask = [timeFormat.format(task.dueDate!), task.title];
    final jsonString = jsonEncode(widgetTask);
    HomeWidget.saveWidgetData(num.toString(), jsonString);
  }

  // Update the widget
  HomeWidget.updateWidget(
    name: 'AppWidget',
    // androidName: '.widget.MyAppWidgetReceiver',
    qualifiedAndroidName: 'io.vikunja.flutteringvikunja.AppWidgetReciever',
  );
}
