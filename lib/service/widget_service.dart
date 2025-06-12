import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/label.dart';

class WidgetService {
  static const String widgetName = 'VikunjaWidgetProvider';
  
  /// Update the home screen widget with current tasks
  static Future<void> updateWidget(List<Task> tasks) async {
    try {
      // Convert tasks to JSON for the widget
      final tasksJson = jsonEncode(tasks.map((task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'done': task.done,
        'due_date': task.dueDate?.toUtc().toIso8601String() ?? '',
        'priority': task.priority ?? 0,
        'labels': task.labels.map((label) => {
          'id': label.id,
          'title': label.title,
          'hex_color': label.color?.value.toRadixString(16).padLeft(8, '0').substring(2) ?? '',
        }).toList(),
      }).toList());
      
      // Save data to widget
      await HomeWidget.saveWidgetData<String>('tasks_json', tasksJson);
      await HomeWidget.saveWidgetData<String>('widget_title', 'Vikunja Tasks (${tasks.length})');
      await HomeWidget.saveWidgetData<int>('task_count', tasks.length);
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: widgetName,
        androidName: 'VikunjaWidgetProvider',
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }
  
  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.vikunja.app');
    } catch (e) {
      print('Error initializing widget service: $e');
    }
  }
  
  /// Handle widget interactions
  static Future<void> handleWidgetInteraction() async {
    try {
      // Register for widget URL callbacks
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleWidgetClick(uri);
        }
      });
    } catch (e) {
      print('Error setting up widget interactions: $e');
    }
  }
  
  static void _handleWidgetClick(Uri uri) {
    // Handle different widget actions
    final action = uri.queryParameters['action'];
    final taskId = uri.queryParameters['task_id'];
    
    switch (action) {
      case 'toggle_task':
        if (taskId != null) {
          // Handle task toggle
          print('Toggle task: $taskId');
        }
        break;
      case 'add_task':
        // Handle add task
        print('Add new task');
        break;
      default:
        print('Unknown widget action: $action');
    }
  }
  
  /// Clear widget data
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('tasks_json', '[]');
      await HomeWidget.saveWidgetData<String>('widget_title', 'Vikunja Tasks');
      await HomeWidget.saveWidgetData<int>('task_count', 0);
      
      await HomeWidget.updateWidget(
        name: widgetName,
        androidName: 'VikunjaWidgetProvider',
      );
    } catch (e) {
      print('Error clearing widget: $e');
    }
  }
}