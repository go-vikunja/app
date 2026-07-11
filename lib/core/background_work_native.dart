import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

@pragma("vm:entry-point")
Future<void> widgetCallback(Uri? uri) async {
  if (uri?.host == "completetask") {
    String? taskID = uri?.queryParameters['taskID'];
    if (taskID != null) {
      await completeTask(taskID);
    } else {
      developer.log("No TaskID provided for widget");
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log("Native called background task: $task");

    switch (task) {
      case "update-tasks":
        return updateTasks();
      default:
        return Future.value(true);
    }
  });
}

Future<bool> updateTasks() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var base = await datasource.getServer();
  var refreshToken = await datasource.getRefreshToken();

  if (refreshToken == null || base == null) {
    return Future.value(true);
  }

  Client client = Client(base: base);
  tz.initializeTimeZones();

  var ignoreCertificates = await datasource.getIgnoreCertificates();
  client.setIgnoreCerts(ignoreCertificates);

  TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));

  await updateWidget();

  NotificationHandler notificationHandler = NotificationHandler();
  await notificationHandler.initNotifications();
  await notificationHandler.scheduleDueNotifications(taskService);

  return Future.value(true);
}
