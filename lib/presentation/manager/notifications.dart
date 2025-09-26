import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_app/domain/repositories/task_repository.dart';

class NotificationHandler {
  FlutterLocalNotificationsPlugin get notificationsPlugin =>
      FlutterLocalNotificationsPlugin();

  var androidSpecificsDueDate = AndroidNotificationDetails(
    "Vikunja1",
    "Due Date Notifications",
    channelDescription: "description",
    icon: 'vikunja_notification_logo',
    importance: Importance.high,
  );
  var androidSpecificsReminders = AndroidNotificationDetails(
    "Vikunja2",
    "Reminder Notifications",
    channelDescription: "description",
    icon: 'vikunja_notification_logo',
    importance: Importance.high,
  );
  late DarwinNotificationDetails iOSSpecifics;
  late NotificationDetails platformChannelSpecificsDueDate;
  late NotificationDetails platformChannelSpecificsReminders;

  NotificationHandler();

  Future<void> initNotifications() async {
    iOSSpecifics = DarwinNotificationDetails();
    platformChannelSpecificsDueDate = NotificationDetails(
      android: androidSpecificsDueDate,
      iOS: iOSSpecifics,
    );
    platformChannelSpecificsReminders = NotificationDetails(
      android: androidSpecificsReminders,
      iOS: iOSSpecifics,
    );
    await _initNotifications();
    requestIOSPermissions();
  }

  Future<void> _initNotifications() async {
    var initializationSettingsAndroid = AndroidInitializationSettings(
      'vikunja_logo',
    );
    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    developer.log("Notifications initialised successfully");
  }

  void onDidReceiveNotificationResponse(NotificationResponse resp) async {
    if (resp.payload != null) {
      print('notification payload: ${resp.payload!}');
    }
    //TODO navigate to task screen
  }

  Future<void> scheduleNotification(
    String title,
    String description,
    FlutterLocalNotificationsPlugin notifsPlugin,
    DateTime scheduledTime,
    String currentTimeZone,
    NotificationDetails platformChannelSpecifics, {
    int? id,
  }) async {
    id ??= Random().nextInt(1000000);

    // TODO: move to setup
    tz.TZDateTime time = tz.TZDateTime.from(
      scheduledTime,
      tz.getLocation(currentTimeZone),
    );

    if (time.difference(tz.TZDateTime.now(tz.getLocation(currentTimeZone))) <
        Duration.zero) {
      return;
    }

    developer.log("scheduled notification for time $time");

    await notifsPlugin.zonedSchedule(
      id,
      title,
      description,
      time,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    ); // This literally schedules the notification
  }

  void sendTestNotification() {
    notificationsPlugin.show(
      Random().nextInt(10000000),
      "Test Notification",
      "This is a test notification",
      platformChannelSpecificsReminders,
    );
  }

  void requestIOSPermissions() {
    notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDueNotifications(TaskRepository taskService) async {
    var taskResponse = await taskService.getByFilterString(
      "done=false && (due_date > now || reminders > now)",
      {
        "filter_include_nulls": ["false"],
      },
    );

    if (taskResponse.isSuccessful) {
      await notificationsPlugin.cancelAll();
      for (final task in taskResponse.toSuccess().body) {
        if (task.done) continue;
        for (final reminder in task.reminderDates) {
          scheduleNotification(
            "Reminder",
            "This is your reminder for '${task.title}'",
            notificationsPlugin,
            reminder.reminder,
            await FlutterTimezone.getLocalTimezone(),
            platformChannelSpecificsReminders,
            id: (reminder.reminder.millisecondsSinceEpoch / 1000).floor(),
          );
        }
        if (task.hasDueDate) {
          scheduleNotification(
            "Due Reminder",
            "The task '${task.title}' is due.",
            notificationsPlugin,
            task.dueDate!,
            await FlutterTimezone.getLocalTimezone(),
            platformChannelSpecificsDueDate,
            id: task.id,
          );
        }
      }
      developer.log("notifications scheduled successfully");
    }
  }
}
