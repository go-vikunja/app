import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

const _actionDonePortName = 'action_done_port_name';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == "action_done") {
    var id = notificationResponse.id;

    if (id != null) {
      markAsDone(id);
    }
  }
}

void markAsDone(int id) async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var refreshCookie = await datasource.getRefreshCookie();
  var base = await datasource.getServer();

  if (refreshCookie == null || base == null) {
    return;
  }

  Client client = Client(base: base);

  var ignoreCertificates = await datasource.getIgnoreCertificates();
  client.setIgnoreCerts(ignoreCertificates);

  TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
  var response = await taskService.getTask(id);

  if (response.isSuccessful) {
    var task = response.toSuccess().body;
    task.done = true;
    await taskService.update(task);

    updateWidget();

    //Call app if opened to update view
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(
      _actionDonePortName,
    );

    if (sendPort != null) {
      sendPort.send(task.id);
    }
  }
}

class NotificationHandler {
  final ReceivePort _receivePort = ReceivePort();
  final List<Function()> _taskChangedListener = List.empty(growable: true);

  FlutterLocalNotificationsPlugin get notificationsPlugin =>
      FlutterLocalNotificationsPlugin();

  var androidSpecificsDueDate = AndroidNotificationDetails(
    "Vikunja1",
    "Due Date Notifications",
    channelDescription: "description",
    icon: 'vikunja_notification_logo',
    importance: Importance.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('action_dcd one', 'Done'),
    ],
  );
  var androidSpecificsReminders = AndroidNotificationDetails(
    "Vikunja2",
    "Reminder Notifications",
    channelDescription: "description",
    icon: 'vikunja_notification_logo',
    importance: Importance.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('action_done', 'Done'),
    ],
  );
  late DarwinNotificationDetails iOSSpecifics;
  late NotificationDetails platformChannelSpecificsDueDate;
  late NotificationDetails platformChannelSpecificsReminders;

  NotificationHandler();

  Future<void> initNotifications() async {
    iOSSpecifics = DarwinNotificationDetails(
      categoryIdentifier: 'doneCategory',
    );
    platformChannelSpecificsDueDate = NotificationDetails(
      android: androidSpecificsDueDate,
      iOS: iOSSpecifics,
    );
    platformChannelSpecificsReminders = NotificationDetails(
      android: androidSpecificsReminders,
      iOS: iOSSpecifics,
    );
    await _initNotifications();

    initBackgroundCommunication();

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
      notificationCategories: [
        DarwinNotificationCategory(
          'doneCategory',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('action_done', 'Done'),
          ],
        ),
      ],
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    developer.log("Notifications initialised successfully");
  }

  void initBackgroundCommunication() {
    IsolateNameServer.removePortNameMapping(_actionDonePortName);

    final ok = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _actionDonePortName,
    );
    if (!ok) {
      developer.log('Failed to register $_actionDonePortName');
    }

    _receivePort.listen((dynamic message) {
      for (var it in _taskChangedListener) {
        it.call();
      }
    });
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String description,
    FlutterLocalNotificationsPlugin notifsPlugin,
    DateTime scheduledTime,
    String currentTimeZone,
    NotificationDetails platformChannelSpecifics,
  ) async {
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
      id: id,
      title: title,
      body: description,
      scheduledDate: time,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: id.toString(),
    );
  }

  void sendTestNotification() {
    notificationsPlugin.show(
      id: Random().nextInt(10000000),
      title: "Test Notification",
      body: "This is a test notification",
      notificationDetails: platformChannelSpecificsReminders,
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
            (reminder.reminder.millisecondsSinceEpoch / 1000).floor(),
            "Reminder",
            "This is your reminder for '${task.title}'",
            notificationsPlugin,
            reminder.reminder,
            await FlutterTimezone.getLocalTimezone(),
            platformChannelSpecificsReminders,
          );
        }
        if (task.hasDueDate) {
          scheduleNotification(
            task.id,
            "Due Reminder",
            "The task '${task.title}' is due.",
            notificationsPlugin,
            task.dueDate!,
            await FlutterTimezone.getLocalTimezone(),
            platformChannelSpecificsDueDate,
          );
        }
      }
      developer.log("notifications scheduled successfully");
    }
  }

  void addListener(Function() listener) {
    _taskChangedListener.add(listener);
  }

  void removeListener(Function() listener) {
    _taskChangedListener.remove(listener);
  }
}
