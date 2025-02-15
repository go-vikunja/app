// https://medium.com/@fuzzymemory/adding-scheduled-notifications-in-your-flutter-application-19be1f82ade8

import 'dart:math';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as notifs;
import 'package:rxdart/subjects.dart' as rxSub;
import 'package:vikunja_app/service/services.dart';

import '../models/task.dart';

class NotificationClass {
  final int? id;
  final String? title;
  final String? body;
  final String? payload;
  late String currentTimeZone;
  notifs.NotificationAppLaunchDetails? notifLaunch;

  notifs.FlutterLocalNotificationsPlugin get notificationsPlugin =>
      new notifs.FlutterLocalNotificationsPlugin();

  var androidSpecificsDueDate = notifs.AndroidNotificationDetails(
      "Vikunja1", "Due Date Notifications",
      channelDescription: "description",
      icon: 'vikunja_notification_logo',
      importance: notifs.Importance.high);
  var androidSpecificsReminders = notifs.AndroidNotificationDetails(
      "Vikunja2", "Reminder Notifications",
      channelDescription: "description",
      icon: 'vikunja_notification_logo',
      importance: notifs.Importance.high);
  late notifs.DarwinNotificationDetails iOSSpecifics;
  late notifs.NotificationDetails platformChannelSpecificsDueDate;
  late notifs.NotificationDetails platformChannelSpecificsReminders;

  NotificationClass({this.id, this.body, this.payload, this.title});

  final rxSub.BehaviorSubject<NotificationClass>
      didReceiveLocalNotificationSubject =
      rxSub.BehaviorSubject<NotificationClass>();
  final rxSub.BehaviorSubject<String> selectNotificationSubject =
      rxSub.BehaviorSubject<String>();

  Future<void> _initNotifications() async {
    var initializationSettingsAndroid =
        notifs.AndroidInitializationSettings('vikunja_logo');
    var initializationSettingsIOS = notifs.DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        );
    var initializationSettings = notifs.InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await notificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (notifs.NotificationResponse resp) async {
      if (payload != null) {
        print('notification payload: ' + resp.payload!);
        selectNotificationSubject.add(resp.payload!);
      }
    });
    print("Notifications initialised successfully");
  }

  Future<void> notificationInitializer() async {
    iOSSpecifics = notifs.DarwinNotificationDetails();
    platformChannelSpecificsDueDate = notifs.NotificationDetails(
        android: androidSpecificsDueDate, iOS: iOSSpecifics);
    platformChannelSpecificsReminders = notifs.NotificationDetails(
        android: androidSpecificsReminders, iOS: iOSSpecifics);
    currentTimeZone = await FlutterTimezone.getLocalTimezone();
    notifLaunch = await notificationsPlugin.getNotificationAppLaunchDetails();
    await _initNotifications();
    requestIOSPermissions();
    return Future.value();
  }

  Future<void> scheduleNotification(
      String title,
      String description,
      notifs.FlutterLocalNotificationsPlugin notifsPlugin,
      DateTime scheduledTime,
      String currentTimeZone,
      notifs.NotificationDetails platformChannelSpecifics,
      {int? id}) async {
    if (id == null) id = Random().nextInt(1000000);
    // TODO: move to setup
    tz.TZDateTime time =
        tz.TZDateTime.from(scheduledTime, tz.getLocation(currentTimeZone));
    if (time.difference(tz.TZDateTime.now(tz.getLocation(currentTimeZone))) <
        Duration.zero) return;
    print("scheduled notification for time " + time.toString());
    await notifsPlugin.zonedSchedule(
        id, title, description, time, platformChannelSpecifics,
        androidScheduleMode: notifs.AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: notifs
            .UILocalNotificationDateInterpretation
            .wallClockTime); // This literally schedules the notification
  }

  void sendTestNotification() {
    notificationsPlugin.show(Random().nextInt(10000000), "Test Notification",
        "This is a test notification", platformChannelSpecificsReminders);
  }

  void requestIOSPermissions() {
    notificationsPlugin
        .resolvePlatformSpecificImplementation<
            notifs.IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleDueNotifications(TaskService taskService,
      {List<Task>? tasks}) async {
    if (tasks == null)
      tasks = await taskService.getByFilterString(
          "done=false && (due_date > now || reminders > now)", {
        "filter_include_nulls": ["false"]
      });
    if (tasks == null) {
      print("did not receive tasks on notification update");
      return;
    }
    await notificationsPlugin.cancelAll();
    for (final task in tasks) {
      if (task.done) continue;
      for (final reminder in task.reminderDates) {
        scheduleNotification(
          "Reminder",
          "This is your reminder for '" + task.title + "'",
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
          "The task '" + task.title + "' is due.",
          notificationsPlugin,
          task.dueDate!,
          await FlutterTimezone.getLocalTimezone(),
          platformChannelSpecificsDueDate,
          id: task.id,
        );
        //print("scheduled notification for time " + task.dueDate!.toString());
      }
    }
    print("notifications scheduled successfully");
  }
}
