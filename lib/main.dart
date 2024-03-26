import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
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
import 'package:flutter_downloader/flutter_downloader.dart';

import 'api/user_implementation.dart';
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
  Workmanager().executeTask((task, inputData) async {
    print(
        "Native called background task: $task"); //simpleTask will be emitted here.
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
        client.reloadIgnoreCerts(value == "1");

        TaskAPIService taskService = TaskAPIService(client);
        NotificationClass nc = NotificationClass();
        await nc.notificationInitializer();
        return nc
            .scheduleDueNotifications(taskService)
            .then((value) => Future.value(true));
      });
    } else if (task == "refresh-token") {
      print("running refresh from workmanager");
      final FlutterSecureStorage _storage = new FlutterSecureStorage();

      var currentUser = await _storage.read(key: 'currentUser');
      if (currentUser == null) {
        return Future.value(true);
      }
      var token = await _storage.read(key: currentUser);

      var base = await _storage.read(key: '${currentUser}_base');
      if (token == null || base == null) {
        return Future.value(true);
      }
      Client client = Client(null);
      client.configure(token: token, base: base, authenticated: true);
      // load new token from server to avoid expiration
      String? newToken = await UserAPIService(client).getToken();
      if (newToken != null) {
        _storage.write(key: currentUser, value: newToken);
      }
      return Future.value(true);
    } else {
      return Future.value(true);
    }
  });
}

final globalSnackbarKey = GlobalKey<ScaffoldMessengerState>();
final globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  await FlutterDownloader.initialize();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(VikunjaGlobal(
      child: new VikunjaApp(
        home: HomePage(),
        key: UniqueKey(),
        navkey: globalNavigatorKey,
      ),
      login: new VikunjaApp(
        home: LoginPage(),
        key: UniqueKey(),
      )));
}

final ValueNotifier<bool> updateTheme = ValueNotifier(false);

class VikunjaApp extends StatelessWidget {
  final Widget home;
  final GlobalKey<NavigatorState>? navkey;

  const VikunjaApp({Key? key, required this.home, this.navkey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    SettingsManager manager = SettingsManager(new FlutterSecureStorage());

    return new ValueListenableBuilder(
        valueListenable: updateTheme,
        builder: (_, mode, __) {
          updateTheme.value = false;
          FlutterThemeMode themeMode = FlutterThemeMode.system;
          Future<ThemeData> theme = manager.getThemeMode().then((value) {
            themeMode = value;
            switch (value) {
              case FlutterThemeMode.dark:
                return buildVikunjaDarkTheme();
              case FlutterThemeMode.materialYouLight:
                return buildVikunjaMaterialLightTheme();
              case FlutterThemeMode.materialYouDark:
                return buildVikunjaMaterialDarkTheme();
              default:
                return buildVikunjaTheme();
            }
          });
          return FutureBuilder<ThemeData>(
              future: theme,
              builder: (BuildContext context, AsyncSnapshot<ThemeData> data) {
                if (data.hasData) {
                  return new DynamicColorBuilder(
                      builder: (lightTheme, darkTheme) {
                    ThemeData? themeData = data.data;
                    if (themeMode == FlutterThemeMode.materialYouLight)
                      themeData = themeData?.copyWith(colorScheme: lightTheme);
                    else if (themeMode == FlutterThemeMode.materialYouDark)
                      themeData = themeData?.copyWith(colorScheme: darkTheme);
                    return MaterialApp(
                      title: 'Vikunja',
                      theme: themeData,
                      scaffoldMessengerKey: globalSnackbarKey,
                      navigatorKey: navkey,
                      // <= this
                      home: this.home,
                    );
                  });
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              });
        });
  }
}
