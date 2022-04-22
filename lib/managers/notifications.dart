// https://medium.com/@fuzzymemory/adding-scheduled-notifications-in-your-flutter-application-19be1f82ade8

import 'dart:math';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_local_notifications/flutter_local_notifications.dart'as notifs;
import 'package:rxdart/subjects.dart' as rxSub;

class NotificationClass{
  final int id;
  final String title;
  final String body;
  final String payload;
  NotificationClass({this.id, this.body, this.payload, this.title});

  final rxSub.BehaviorSubject<NotificationClass> didReceiveLocalNotificationSubject =
  rxSub.BehaviorSubject<NotificationClass>();
  final rxSub.BehaviorSubject<String> selectNotificationSubject =
  rxSub.BehaviorSubject<String>();

  Future<void> initNotifications(notifs.FlutterLocalNotificationsPlugin notifsPlugin) async {
    var initializationSettingsAndroid =
    notifs.AndroidInitializationSettings('vikunja_logo');
    var initializationSettingsIOS = notifs.IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification:
            (int id, String title, String body, String payload) async {
          didReceiveLocalNotificationSubject
              .add(NotificationClass(id: id, title: title, body: body, payload: payload));
        });
    var initializationSettings = notifs.InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await notifsPlugin.initialize(initializationSettings,
        onSelectNotification: (String payload) async {
          if (payload != null) {
            print('notification payload: ' + payload);
          }
          selectNotificationSubject.add(payload);
        });
    print("Notifications initialised successfully");
  }
}

Future<void> scheduleNotification(String title, String description,
    notifs.FlutterLocalNotificationsPlugin notifsPlugin,
    DateTime scheduledTime, {int id, notifs.NotificationDetails platformChannelSpecifics}) async {
  if(scheduledTime.difference(DateTime.now()) < Duration.zero)
    return;
  if(id == null)
    id = Random().nextInt(1000000);
  final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  tz.TZDateTime time = tz.TZDateTime.from(scheduledTime,tz.getLocation(currentTimeZone));
  //time.add(Duration(hours: -2));
  await notifsPlugin.zonedSchedule(id, title, description,
      time, platformChannelSpecifics, androidAllowWhileIdle: true, uiLocalNotificationDateInterpretation: notifs.UILocalNotificationDateInterpretation.wallClockTime); // This literally schedules the notification
}

void requestIOSPermissions(
    notifs.FlutterLocalNotificationsPlugin notifsPlugin) {
  notifsPlugin.resolvePlatformSpecificImplementation<notifs.IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}
