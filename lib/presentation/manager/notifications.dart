import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

const _actionDonePortName = 'action_done_port_name';
const _notificationActionDone = 'action_done';

/// Upper bound of alarms scheduled at once. Android refuses to keep more than
/// 500 pending alarms per app, and WorkManager needs some of them too.
const maxScheduledNotifications = 400;

/// Fetches every page of a task filter, following the
/// `x-pagination-total-pages` header. The server returns at most
/// `service.maxitemsperpage` (50 by default) tasks per request, so a single
/// request misses everything past the first page.
Future<Response<List<Task>>> fetchAllTaskPages(
  TaskRepository taskService,
  String filter, [
  Map<String, List<String>>? queryParameters,
]) async {
  final tasks = <Task>[];
  for (var page = 1; ; page++) {
    final response = await taskService.getByFilterString(filter, {
      ...?queryParameters,
      'page': [page.toString()],
    });
    if (!response.isSuccessful) return response;

    final result = response.toSuccess();
    tasks.addAll(result.body);

    final headers = result.headers.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    final totalPages =
        int.tryParse(headers['x-pagination-total-pages'] ?? '') ?? 1;
    if (page >= totalPages || result.body.isEmpty) {
      return SuccessResponse(tasks, result.statusCode, result.headers);
    }
  }
}

class _PendingNotification {
  final int id;
  final String title;
  final String body;
  final DateTime time;
  final NotificationDetails details;

  _PendingNotification(this.id, this.title, this.body, this.time, this.details);
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  if (notificationResponse.actionId == _notificationActionDone) {
    var id = notificationResponse.id;

    if (id != null) {
      await markAsDone(id);
    }
  }
}

Future<void> markAsDone(int id) async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var refreshToken = await datasource.getRefreshToken();
  var base = await datasource.getServer();

  if (refreshToken == null || base == null) {
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

    await updateWidget();

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
      AndroidNotificationAction(_notificationActionDone, 'Done'),
    ],
  );
  var androidSpecificsReminders = AndroidNotificationDetails(
    "Vikunja2",
    "Reminder Notifications",
    channelDescription: "description",
    icon: 'vikunja_notification_logo',
    importance: Importance.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(_notificationActionDone, 'Done'),
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
    await _requestAndroidExactAlarmPermission();
  }

  Future<void> _requestAndroidExactAlarmPermission() async {
    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    final canSchedule = await androidPlugin.canScheduleExactNotifications();
    if (canSchedule != true) {
      await androidPlugin.requestExactAlarmsPermission();
    }
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
            DarwinNotificationAction.plain(_notificationActionDone, 'Done'),
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
    var taskResponse = await fetchAllTaskPages(
      taskService,
      "done=false && (due_date > now || reminders > now)",
      {
        "filter_include_nulls": ["false"],
      },
    );

    // Only replace the scheduled alarms once every page loaded, so a failed
    // sync keeps the previous alarms instead of leaving a partial set.
    if (!taskResponse.isSuccessful) return;

    final timeZone = await FlutterTimezone.getLocalTimezone();
    final now = DateTime.now();
    final pending = <_PendingNotification>[];

    for (final task in taskResponse.toSuccess().body) {
      if (task.done) continue;
      for (final reminder in task.reminderDates) {
        pending.add(
          _PendingNotification(
            (reminder.reminder.millisecondsSinceEpoch / 1000).floor(),
            "Reminder",
            "This is your reminder for '${task.title}'",
            reminder.reminder,
            platformChannelSpecificsReminders,
          ),
        );
      }
      if (task.hasDueDate) {
        pending.add(
          _PendingNotification(
            task.id,
            "Due Reminder",
            "The task '${task.title}' is due.",
            task.dueDate!,
            platformChannelSpecificsDueDate,
          ),
        );
      }
    }

    // Android caps the number of pending alarms per app (500), so keep the
    // soonest ones if a user has more than that.
    pending.removeWhere((n) => n.time.isBefore(now));
    pending.sort((a, b) => a.time.compareTo(b.time));

    await notificationsPlugin.cancelAll();
    for (final n in pending.take(maxScheduledNotifications)) {
      await scheduleNotification(
        n.id,
        n.title,
        n.body,
        notificationsPlugin,
        n.time,
        timeZone,
        n.details,
      );
    }
    developer.log(
      "notifications scheduled successfully "
      "(${min(pending.length, maxScheduledNotifications)} of ${pending.length})",
    );
  }

  void addListener(Function() listener) {
    _taskChangedListener.add(listener);
  }

  void removeListener(Function() listener) {
    _taskChangedListener.remove(listener);
  }
}
