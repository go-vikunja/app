import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) {
    return;
  }
  Workmanager().executeTask((task, inputData) async {
    print(
      "Native called background task: $task",
    ); //simpleTask will be emitted here.
    if (task == "update-tasks") {
      var datasource = SettingsDatasource(FlutterSecureStorage());
      var token = await datasource.getUserToken();
      var base = await datasource.getServer();

      Client client = Client(token: token, base: base);
      tz.initializeTimeZones();
      var ignoreCertificates = await datasource.getIgnoreCertificates();

      print("ignoring: $ignoreCertificates");
      client.reloadIgnoreCerts(ignoreCertificates);

      TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
      NotificationHandler nc = NotificationHandler();
      await nc.initNotifications();
      return nc
          .scheduleDueNotifications(taskService)
          .then((value) => Future.value(true));
    } else if (task == "refresh-token") {
      final FlutterSecureStorage storage = new FlutterSecureStorage();

      var currentUser = await storage.read(key: 'currentUser');
      if (currentUser == null) {
        return Future.value(true);
      }
      var token = await storage.read(key: currentUser);

      var base = await storage.read(key: '${currentUser}_base');
      if (token == null || base == null) {
        return Future.value(true);
      }
      Client client = Client(base: base, token: token);
      // load new token from server to avoid expiration
      String? newToken = await UserDataSource(client).getToken();
      if (newToken != null) {
        storage.write(key: currentUser, value: newToken);
      }
      return Future.value(true);
    } else {
      return Future.value(true);
    }
  });
}
