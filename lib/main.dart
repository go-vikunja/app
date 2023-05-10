import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vikunja_app/api/task_implementation.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/home.dart';
import 'package:vikunja_app/pages/user/login.dart';
import 'package:vikunja_app/theme/theme.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'managers/notifications.dart';

class IgnoreCertHttpOverrides extends HttpOverrides {
  bool ignoreCerts = false;

  IgnoreCertHttpOverrides(bool _ignore) {
    ignoreCerts = _ignore;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => ignoreCerts;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    print("Native called background task: $task"); //simpleTask will be emitted here.
    if (task == "update-tasks" && inputData != null) {
      Client client = Client(null,
          token: inputData["client_token"],
          base: inputData["client_base"],
          authenticated: true);
      tz.initializeTimeZones();

      return SettingsManager(new FlutterSecureStorage())
          .getIgnoreCertificates()
          .then((value) async {
        print("ignoring: $value");
        client.reload_ignore_certs(value == "1");

        TaskAPIService taskService = TaskAPIService(client);
        NotificationClass nc = NotificationClass();
        await nc.notificationInitializer();
        return nc
            .scheduleDueNotifications(taskService)
            .then((value) => Future.value(true));
      });
    } else {
      return Future.value(true);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(VikunjaGlobal(
      child: new VikunjaApp(
        home: HomePage(),
        key: UniqueKey(),
      ),
      login: new VikunjaApp(
        home: LoginPage(),
        key: UniqueKey(),
      )));
}

class VikunjaApp extends StatelessWidget {
  final Widget home;

  const VikunjaApp({Key? key, required this.home}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      darkTheme: buildVikunjaDarkTheme(),
      scaffoldMessengerKey: VikunjaGlobal.of(context).snackbarKey,
      // <= this
      home: this.home,
    );
  }
}
